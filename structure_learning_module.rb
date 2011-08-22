# Provides graph structures and algorithms for determining edge structure of a Bayesian net

require 'rubygems'

require 'rgl/implicit'
require 'rgl/traversal'

module StructureLearning
  module PowerSet
    # Sets an array to its "power array" (array of subarrays)
    def power_set!
      return [[]] if empty?
      f = self.shift
      rec = self.power_set!
      rec + rec.map {|i| [f] + i }
    end

    def power_set
      return self.clone.power_set!
    end
  end
  
  module GraphAlgorithms
    # Returns a (unique) list of vertices adjacent to vertex a or b.
    # This is denoted "Aab" in Spirtes-Glymour's paper.
    def adjacent_either(a, b)
      (self.adjacent_vertices(a) + self.adjacent_vertices(b)).uniq
    end
    
    # Returns an array of all vertices on undirected simple paths between s and t.
    # Modified breadth-first search: keep track of current path, and when t is found, add it to paths.
    # This is denoted "Uab" in Spirtes-Glymour's paper.
    def verts_on_paths(current_vertex, t, current_path=[], paths=[])
      if current_vertex == t
        paths << current_path + [current_vertex]
      else
        self.adjacent_vertices(current_vertex).each do |v|
          # Don't recur if we're repeating vertices (i.e. reject non-simple paths)
          verts_on_paths(v, t, current_path + [current_vertex]) if current_path.count(current_vertex) == 0
        end
      end
      paths.flatten.uniq
    end
    
    # Returns a list of _ordered_ 3-tuples (a, b, c) of vertices such that
    # (a, b) are adjacent and (b,c) are adjacent, but (a,c) are not.
    # Triples are ordered, so if [x, y, z] is returned then so is [z, y, x]
    def non_transitive
      non_transitive_verts = []
      
      self.vertices.each do |u|
        self.adjacent_vertices(u).each do |v|
          self.adjacent_vertices(v).each do |w|
            non_transitive_verts << [u, v, w]
          end
        end
      end
      non_transitive_verts.reject! do |triple|
        triple.first.adjacent_vertices.include? triple.last
      end
      non_transitive_verts
    end
  end
  
  # Generates the complete graph on n vertices if n is an integer, otherwise
  # the complete graph on the vertices in the enumerable given
  def complete_graph(n)
    set = n.integer? ? (1..n) : n
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
      g.vertex_iterator { |b| vertices.each(&b) }
      g.adjacent_iterator do |x, b|
        vertices.each {|y| b.call(y) if directed_edges[x].include? y}
      end
    end
  end
  
  class LearningNet
    def initialize(table, variables)
      @net = complete_graph(variables).extend(GraphAlgorithms)
      @directed_edges = {}
      @directed_edges.default = []
      @table = table
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
      # Perform self.step until every pair of adjacent variables is dependent, and
      # set final_net to the _second-to-last_ state of @net
      begin
        final_net = @net
      end while self.step
      
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