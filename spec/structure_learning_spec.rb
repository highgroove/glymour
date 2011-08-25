require 'glymour'
require 'rgl/implicit'

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
      
      @g = make_directed(vertices, edges)
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
end