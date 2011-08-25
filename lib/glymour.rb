require "glymour/version"

module Glymour
  # Provides graph structures and algorithms for determining edge structure of a Bayesian net
  module StructureLearning
    module PowerSet
      # Sets an array to its "power array" (array of subarrays)
      def power_set!
        return [[]] if empty?
        f = shift
        rec = power_set!
        rec + rec.map {|i| [f] + i }
      end

      def power_set
        return clone.power_set!
      end
    end

    module GraphAlgorithms
      # Returns a (unique) list of vertices adjacent to vertex a or b.
      # This is denoted "Aab" in Spirtes-Glymour's paper.
      def adjacent_either(a, b)
        (adjacent_vertices(a) + adjacent_vertices(b)).uniq
      end

      # Returns an array of all vertices on undirected simple paths between s and t.
      # Modified breadth-first search: keep track of current path, and when t is found, add it to paths.
      # This is denoted "Uab" in Spirtes-Glymour's paper.
      def verts_on_paths(current_vertex, t, current_path=[], paths=[])
        if current_vertex == t
          paths << current_path + [current_vertex]
        else
          adjacent_vertices(current_vertex).each do |v|
            # Don't recur if we're repeating vertices (i.e. reject non-simple paths)
            verts_on_paths(v, t, current_path + [current_vertex], paths) if current_path.count(current_vertex) == 0
          end
        end
        
        paths.flatten.uniq
      end

      # Returns a list of _ordered_ 3-tuples (a, b, c) of vertices such that
      # (a, b) are adjacent and (b,c) are adjacent, but (a,c) are not.
      def non_transitive
        non_transitive_verts = []

        vertices.each do |u|
          adjacent_vertices(u).each do |v|
            adjacent_vertices(v).each do |w|
              non_transitive_verts << [u, v, w]
            end
          end
        end
        non_transitive_verts.reject do |triple|
          adjacent_vertices(triple.first).include? triple.last
        end
      end
    end

    # Generates the complete graph on n vertices if n is an integer, otherwise
    # the complete graph on the vertices in the enumerable given
    def complete_graph(n)
      set = (n.class == 'Integer' || n.class == 'Fixnum') ? (1..n) : n
      RGL::ImplicitGraph.new do |g|
        g.vertex_iterator { |b| set.each(&b) }
        g.adjacent_iterator do |x, b|
          set.each { |y| b.call(y) unless x == y }
        end
      end
    end

    # Takes a list of vertices and a hash of source => [targets] pairs and generates a directed graph
    def make_directed(vertices, directed_edges)
      RGL::ImplicitGraph.new do |g|
        directed_edges.default = []
        g.vertex_iterator { |b| vertices.each(&b) }
        g.adjacent_iterator do |x, b|
          vertices.each {|y| b.call(y) if directed_edges[x].include? y}
        end
      end
    end

    class LearningNet
      def initialize(variables)
        @net = complete_graph(variables).extend(GraphAlgorithms)
        @directed_edges = {}
        @directed_edges.default = []
        @n = -1
      end

      # Perform one step of the PC algorithm
      def step
        any_independent = false
        @net.edges.each do |e|
          a, b = e.source, e.target
          intersect = (@net.adjacent_either(a, b) & @net.verts_on_paths(a, b)).extend(PowerSet)

          # Is |Aab ^ Uab| > @n? 
          if intersect.length <= @n
            next
          else
            # Are a and b independent conditioned on any subsets of Aab ^ Uab of cardinality n+1?
            if intersect.power_set.select {|s| s.length == n+1}.any? { |subset|
                #TODO: are a and b independent conditioned on subset?
              }
              g.remove_vertex e
              any_independent = true
            end
          end
          @n += 1
        end
        any_independent
      end

      # Perform the PC algorithm in full
      def learn_structure
        # Perform step until every pair of adjacent variables is dependent, and
        # set final_net to the _second-to-last_ state of @net
        begin
          final_net = @net
        end while step

        # Direct remaining edges in @net as much as possible
        final_net.non_transitive.each do |triple|
          a, b, c = triple[0], triple[1], triple[2]
          intersect = (final_net.adjacent_either(a, c) & final_net.verts_on_path(a, c)).extend(PowerSet)

          if intersect.power_set.select {|s| s.include? b}.all? { |subset| 
            # TODO: Are a and c dependent conditioned on subset?
          }
            @directed_edges[a] << b
            @directed_edges[c] << b
          end
        end

        @net = final_net
      end

      # Gives a list of all orientations of @net compatible with @directed_edges
      # (i.e., all directed acyclic graphs with edge structure given partially by @directed_edges)
      def compatible_orientations
        compat_list = []
        edges = @net.edges.extend(PowerSet)

        # Every orientation of @net corresponds to a subset of its edges
        edges.power_set.each do |subset|
          # Orient edges in subset as source => target, outside of it as target => source (unless they're in @directed_edges)
          current_orientation = @directed_edges
          current_orientation.default = []

          edges.each do |e|
            unless @directed_edges.include? e
              if subset.include? e
                current_orientation[e.source] << e.target
              else
                current_orientation[e.target] << e.source
              end
            end
          end

          orientation_graph = make_directed(@net.vertices, current_orientation)
          compat_list << orientation_graph if orientation_graph.acyclic?
        end

        compat_list
      end
    end
  end
  
  # Converts a DAG from StructureLearning into a Bayesian net
  module GraphToBayesNet
    def to_bn(title)
      vars = {}
      return_net = Sbn::Net.new(title)
      
      vertices.each do |v|
        vars[v] = Sbn::Variable.new(return_net, v.to_sym)
      end
      
      edges.each do |e|
        vars[e.source].add_child(vars[e.target])
      end
      
      return_net
    end
  end
  
  module Statistics
    require 'Rinruby'
    # Grabs variable data from a table (mostly for quantizing continous vars)
    # block determines the variable value for a given row of table, e.g. { |row| row[:first_seen_at] } or &:first_seen_at
    class Variable
      attr_accessor :intervals, :table
      
      def initialize(table, num_classes=nil, &block)
        @table = table
        @block = Proc.new &block
        @intervals = num_classes ? to_intervals(num_classes) : nil
      end
      
      # Apply @block to each column value, and 
      # return a list of evenly divided intervals [x1, x2, ..., x(n_classes)]
      # So that x1 is the minimum, xn is the max
      def to_intervals(num_classes)
        step = (values.max - values.min)/(num_classes-1).to_f
        (0..(num_classes-1)).map { |k| values.min + k*step }
      end
      
      def value_at(row)
        @block.call(row)
      end
      
      def values
        @table.map(&@block)
      end
    end
    
    # Gives the location of a column value within a finite set of interval values (i.e. gives discrete state after classing a continuous variable)
    def location_in_interval(value, intervals)
      intervals.each_with_index do |x, i|
        return i if value <= x
      end
      
      # Return -1 if value is not within intervals
      return -1
    end
    
    # Accepts a list of variables and a row of data and generates a learning row for a net
    def learning_row(variables, row)
      var_values = {}
      
      variables.each do |var|
        if var.intervals
          var_values[var] = location_in_interval(var.value_at row)
        else
          var_values[var] = var.value_at row
        end
      end
      
      var_values
    end
    
    # Generates a contingency table for two variables from a learning row generated above
    def contingency_table(var1, var2, rows)
      values_table = rows.map { |row| learning_row([var1, var2], row) }      
      
      row_states = values_table.map { |entry| entry[var1] }.uniq
      col_states = values_table.map { |entry| entry[var2] }.uniq
      
      matrix = []
      row_states.each do |row_state|
        col_states.each do |col_state|
          matrix << values_table.select { |val_pair| val_pair[var1] == row_state and val_pair[var2] == col_state }.length
        end
      end
      
      "matrix(c(#{matrix.join ', '}), #{row_states.length}, #{col_states.length})"
    end
    
    # Takes two variables and an array of conditioning variables
    # Returns true if x and y are coindependent given conditioned_on
    def coindependent?(var1, var2, conditioned_on=[])
      #TODO: Raise an exception if var1 and var2 have different tables?
      rows = var1.values
      R.eval <<-EOF
        t <- coindep_test(#{contingency_table(var1, var2, rows)})
      EOF
    end
  end
  
  module Correlator
    
  end
end
