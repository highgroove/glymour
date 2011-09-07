require "glymour"
require "pry"
require "rinruby"
require "rgl/adjacency"
require "rgl/topsort"

# Generates the complete graph on n vertices if n is an integer, otherwise
# the complete graph on the vertices in the enumerable given
def complete_graph(n)
  set = (Integer === n) ? 1..n : n
  RGL::ImplicitGraph.new do |g|
    g.vertex_iterator { |b| set.each(&b) }
    g.adjacent_iterator do |x, b|
      set.each { |y| b.call(y) unless x == y }
    end
  end
end

def remove_edge(orig, e)
  new_graph = RGL::ImplicitGraph.new do |g|
    g.vertex_iterator { |b| orig.vertices.each(&b) }
    g.adjacent_iterator do |x, b|
      new_adj = orig.adjacent_vertices(x).reject { |v| e.source == v or e.target == v }
      new_adj.each { |y| b.call(y) }
    end
  end
  new_graph
end

# Takes a list of vertices and a hash of source => [targets] pairs and generates a directed graph
def make_directed(vertices, directed_edges)
  g = RGL::DirectedAdjacencyGraph.new
  
  vertices.each { |v| g.add_vertex(v) }
  
  directed_edges.each do |source, targets|
    targets.each { |target| g.add_edge(source, target) }
  end
  
  g
end

# Takes a list of vertices and a hash of source => [targets] pairs and generates an implicit (undirected) graph
def make_implicit(vertices, edges)
  RGL::ImplicitGraph.new do |g|
    edges.default = []
    g.vertex_iterator { |b| vertices.each(&b) }
    g.adjacent_iterator do |x, b|
      vertices.each {|y| b.call(y) if edges[x].include? y}
    end
  end
end

def cartprod(*args)
  result = [[]]
  while [] != args
    t, result = result, []
    b, *args = args
    t.each do |a|
      b.each do |n|
        result << a + [n]
      end
    end
  end
  result
end

module Glymour
  module Statistics
    class VariableContainer
      attr_reader :table, :number_unnamed
      attr_accessor :variables
      
      def initialize(table, variables=[])
        number_unnamed = 0
        @table = table
        @variables = variables
        @variables.each do |var|
          var.variable_container = self
          var.name ||= "unnamed_variable#{number_unnamed+=1}"
        end
      end
    end
    
    class Variable
      attr_accessor :intervals, :variable_container, :name
      
      def initialize(variable_container = nil, name = nil, num_classes = nil, &block)
        @variable_container = variable_container
        @block = Proc.new &block
        @intervals = num_classes ? to_intervals(num_classes) : nil
        
        # names are used as variable names in R, so make sure there's no whitespace
        @name = name.gsub(/\s+/, '_') if name
      end
      
      # Apply @block to each column value, and 
      # return a list of evenly divided intervals [x1, x2, ..., x(n_classes)]
      # So that x1 is the minimum, xn is the max
      def to_intervals(num_classes)
        step = (values.max - values.min)/(num_classes-1).to_f
        (0..(num_classes-1)).map { |k| values.min + k*step }
      end
      
      def value_at(row)
        @intervals ? location_in_interval(row) : @block.call(row)
      end
      
      # Gives an array of all variable values in table
      def values
        @intervals ? @variable_container.table.map { |row| location_in_interval(row) } : @variable_container.table.map(&@block)
      end
      
      # Gives the location of a column value within a finite set of interval values (i.e. gives discrete state after classing a continuous variable)
      def location_in_interval(row)
        intervals.each_with_index do |x, i|
          return i if value_at(row) <= x
        end

        # Return -1 if value is not within intervals
        -1
      end
    end
    
    # Takes two or more Variables
    # Returns true if first two variables are coindependent given the rest
    def coindependent?(p_val, *variables)
      #TODO: Raise an exception if variables have different tables?
      R.echo(false)
      # Push variable data into R
      variables.each_with_index do |var, k|
        # Rinruby can't handle true and false values, so use 1 and 0 resp. instead
        sanitized_values = var.values.map do |value|
          case value
            when true  then 1
            when false then 0
            else value
          end
        end
        
        R.assign var.name, sanitized_values
      end
      
      R.eval "cond_data <- data.frame(#{variables.map(&:name).join(', ')})\n"
      R.eval "t <-table(cond_data)"
      
      cond_vars = variables[2..(variables.length-1)]
      
      # If no conditioning variables are given, just return the chi square test for the first two
      if cond_vars.empty?
        R.eval "chisq <- chisq.test(t)"
        observed_p = R.pull "chisq$p.value"
        return observed_p > p_val
      end
      
      cond_values = cond_vars.map { |var| (1..var.values.uniq.length).collect }
      
      # Find the chi-squared statistic for every state of the conditioning variables and sum them
      chisq_sum = 0
      df = 0
      cartprod(*cond_values).each do |value|
        R.eval "partial_table <- t[,,#{value.join(',')}]"
        
        R.eval "chisq <- chisq.test(partial_table)"
        R.eval "s <- chisq$statistic"
        observed_s = R.pull("s").to_f
        chisq_sum += observed_s
        df += R.pull("chisq$parameter").to_i
      end
      # Compute the p-value of the sum of statistics
      observed_p = 1 - R.pull("pchisq(#{chisq_sum}, #{df})").to_f
      observed_p > p_val
    end
  end
  
  # Provides graph structures and algorithms for determining edge structure of a Bayesian net
  module StructureLearning
    module PowerSet
      # Sets an array to its "power array" (array of subarrays)
      def power_set!
        return [[]] if empty?
        first = shift
        rest = power_set!
        
        rest + rest.map {|subset| [first] + subset }
      end

      def power_set
        return clone.power_set!
      end
    end

    module GraphAlgorithms
      def has_edge?(e)
        self.edges.include? e
      end
      
      # Returns a (unique) list of vertices adjacent to vertex a or b.
      # This is denoted "Aab" in Spirtes-Glymour's paper.
      def adjacent_either(a, b)
        (adjacent_undirected(a) + adjacent_undirected(b)).uniq
      end
      
      def adjacent_undirected(vertex)
        adjacent_sources = vertices.select { |w| adjacent_vertices(w).include?(vertex) }
        adjacent_vertices(vertex) + adjacent_sources
      end

      # Returns an array of all vertices on undirected simple paths between s and t.
      # Modified breadth-first search: keep track of current path, and when t is found, add it to paths.
      # This is denoted "Uab" in Spirtes-Glymour's paper.
      def verts_on_paths(current_vertex, t, current_path=[], paths=[])
        if current_vertex == t
          paths << current_path + [current_vertex]
        else
          adjacent_undirected(current_vertex).each do |v|
            # Don't recur if we're repeating vertices (i.e. reject non-simple paths)
            verts_on_paths(v, t, current_path + [current_vertex], paths) if current_path.count(current_vertex) == 0
          end
        end
        
        paths.flatten.uniq
      end

      # Returns a list of _ordered_ 3-tuples (a, b, c) of vertices such that
      # (a, b) are adjacent and (b,c) are adjacent, but (a,c) are not.
      def non_transitive
        triples = vertices.product(vertices, vertices)
        
        adjacent_triples = triples.select do |triple|
          adjacent_undirected(triple.first).include?(triple[1]) && adjacent_undirected(triple[1]).include?(triple.last)
        end
        
        adjacent_triples.reject do |triple|
          (adjacent_undirected(triple.first).include? triple.last) || (triple.first == triple.last)
        end
      end
    end
    
    class LearningNet
      include Glymour::Statistics
      attr_accessor :net, :directed_edges, :n
      attr_reader :p_value
      
      def initialize(variable_container, p_value = 0.05)
        @net = complete_graph(variable_container.variables).extend(GraphAlgorithms)
        @directed_edges = {}
        @directed_edges.default = []
        @n = -1
        @p_value = p_value
      end
      
      # Perform one step of the PC algorithm
      def step
        any_independent = false
        net.edges.each do |e|
          a, b = e.source, e.target
          intersect = (@net.adjacent_either(a, b) & @net.verts_on_paths(a, b)).extend(PowerSet)
          
          # Is |Aab ^ Uab| > n? 
          if intersect.length <= n
            next
          else
            # Are a and b independent conditioned on any subsets of Aab ^ Uab of cardinality n+1?
            valid_intersects = intersect.power_set.select {|s| s.length == n+1}.reject { |subset| subset.include?(a) || subset.include?(b) }
            if valid_intersects.any? { |subset|
              print "Testing independence between #{a.name} and #{b.name}, conditioning on #{(subset.any? ? subset.map(&:name).join(', ') : 'nothing') + '...'}"
              print (coindependent?(p_value, a, b, *subset) ? "[+]\n" : "[-]\n")
              coindependent?(p_value, a, b, *subset)
            }
              @net = remove_edge(net, e)
              any_independent = true
            end
          end
        end
        @n += 1
        any_independent
      end
      
      # Perform the PC algorithm in full
      def learn_structure
        puts "Learning undirected net structure..."
        # Perform step until every pair of adjacent variables is dependent, and
        # set final_net to the _second-to-last_ state of @net
        begin
          puts "n = #{n}"
          final_net = net
          step
        end while n < net.vertices.length - 1
        
        net = final_net
        
        direct_edges
      end
      
      # Direct remaining edges in @net as much as possible
      def direct_edges
        puts "Directing edges where possible..."
        
        net.non_transitive.each do |triple|
          a, b, c = *triple
          
          intersect = (net.adjacent_either(a, c) & net.verts_on_paths(a, c)).extend(PowerSet)
          if intersect.power_set.select {|s| s.include? b}.none? { |subset| 
            coindependent?(p_value, a, c, *subset)
          }
            puts "Adding directed edge #{a.name} => #{b.name}..."
            @directed_edges[a] = (@directed_edges[a] << b).uniq
            
            puts "Adding directed edge #{c.name} => #{b.name}..."
            @directed_edges[c] = (@directed_edges[c] << b).uniq
          end
        end
      end
      
      
      # Gives a list of all orientations of @net compatible with @directed_edges
      # (i.e., all directed acyclic graphs with edge structure given partially by @directed_edges)
      def compatible_orientations
        compat_list = []
        edges = net.edges.extend(PowerSet)
        
        # Every orientation of net corresponds to a subset of its edges
        edges.power_set.each do |subset|
          # Orient edges in subset as source => target, outside of it as target => source
          # Any edges conflicting with directed_edges will be cyclic and therefore not counted
          current_orientation = make_directed(net.vertices, @directed_edges)
          
          edges.each do |e|
            if subset.include? e
              current_orientation.add_edge(e.source, e.target)
            else
              current_orientation.add_edge(e.target, e.source)
            end
          end
          
          compat_list << current_orientation if current_orientation.acyclic?
          print "\n"
        end
        
        compat_list
      end
    end
  end
end
