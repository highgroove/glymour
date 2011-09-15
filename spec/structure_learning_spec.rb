require 'glymour'
require 'rgl/implicit'
require 'rgl/dot'
require 'spec_helper'

describe Glymour::StructureLearning do
  before(:each) do 
    extend Glymour::StructureLearning
  end
  
  it 'should compute the power set of an array' do
    ary = [1, :two, "three"].extend(Glymour::StructureLearning::PowerSet)
    result = ary.power_set
    
    [[], [1, :two], [:two, "three"], ary].each do |set|
      result.should include set
    end
  end
  
  describe 'Within GraphAlgorithms' do
    before(:each) do
      class RGL::ImplicitGraph
        include Glymour::StructureLearning::GraphAlgorithms
      end
      
      # Create a graph for graph algorithm tests
      # (Unfortunately we need something a little complicated for some tests)
      vertices = (1..8).collect
      edges = {1 => [2], 2 => [3], 3 => [1, 7], 4 => [3], 7 => [5, 8], 5 => [6], 6 => [7]}
      
      @g = make_implicit(vertices, edges)
    end
    
    it 'should remove an edge from a graph' do
      g = complete_graph(4)
      orig_edge_count = g.edges.length
      remove_edge(g, g.edges.first).edges.length.should_not eq orig_edge_count
    end
    
    it 'should compute the vertices on all paths between two vertices' do
      path_verts = @g.verts_on_paths(4, 6)
      [4, 3, 7, 5, 6].each { |v| path_verts.should include v }
    end
    
    it 'should compute non-transitive vertices of a graph' do
      [[4, 3, 1], [4, 3, 7], [3, 7, 8]].each do |triple|
        @g.non_transitive.should include triple
      end
    end
    
    it 'should compute a complete graph on any vertex set' do
      vert_set = [1, :two, "three", [5]]
      complete = complete_graph vert_set
      
      vert_set.each do |v|
        complete.adjacent_vertices(v).should eq vert_set - [v]
      end
    end
  end
  
  describe Glymour::StructureLearning::LearningNet do
    before(:all) do
      alarm_init
    end
    
    it 'should perform the structure learning algorithm' do
      prev_n_edges = @alarm_net.net.edges.length
      
      @alarm_net.learn_structure
      
      @alarm_net.net.edges.length.should be < prev_n_edges
      
      @alarm_net.net.edges.each do |e|
        puts "#{e.source.name} => #{e.target.name}"
      end
    end
    
    it 'should produce orientations compatible with learn_structure output' do
      orientations = @alarm_net.compatible_orientations
    end
  end
end