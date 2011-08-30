require 'glymour'
require 'rgl/implicit'
require 'rgl/dot'

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
      @alarm_data = []
      100000.times do
        e = rand < 0.002
        b = rand < 0.001
        a = b ? (e ? rand < 0.95 : rand < 0.94) : (e ? rand < 0.29 : rand < 0.001)
        j = a ? rand < 0.90 : rand < 0.05
        m = a ? rand < 0.70 : rand < 0.01
        @alarm_data << { :e => e, :b => b, :a => a, :j => j, :m => m}
      end
      @e = Glymour::Statistics::Variable.new(@alarm_data) { |r| r[:e] }
      @b = Glymour::Statistics::Variable.new(@alarm_data) { |r| r[:b] }
      @a = Glymour::Statistics::Variable.new(@alarm_data) { |r| r[:a] }
      @j = Glymour::Statistics::Variable.new(@alarm_data) { |r| r[:j] }
      @m = Glymour::Statistics::Variable.new(@alarm_data) { |r| r[:m] }
      alarm_vars = [@e, @b, @a, @j, @m]
      @v_hash = { @e => 'e', @b => 'b', @a => 'a', @j => 'j', @m => 'm' }
      @alarm_net = Glymour::StructureLearning::LearningNet.new(alarm_vars)
    end
    
    # it 'should perform a step of the structure learning algorithm' do
    #       prev_net = @lnet.net
    #       @lnet.step
    #       prev_net.should_not eq @lnet.net
    #     end
    # 
    it 'should perform the structure learning algorithm' do
      @alarm_net.learn_structure

      @alarm_net.net.edges.each do |e|
        puts "#{@v_hash[e.source]} => #{@v_hash[e.target]}"
      end
    end
  end
end