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
  
  describe Glymour::StructureLearning::LearningNet do
    before(:all) do
      @table_data = []

      500.times do
        rain = rand < 0.5
        temp = rain ? 65 + 10 * (rand - 0.5) : 75 + 10 * (rand - 0.5)
        sprinklers = rain ? rand < 0.1 : rand < 0.5
        cat_out = rain || sprinklers ? 0.05 : 0.4
        grass_wet = (rain && (rand < 0.9)) || (sprinklers && (rand < 0.7)) || (cat_out && (rand < 0.01))
        @table_data << { :rain => rain, :sprinklers => sprinklers, :cat_out => cat_out, :grass_wet => grass_wet, :temp => temp }
      end

      @rain_var = Glymour::Statistics::Variable.new(@table_data) { |r| r[:rain] }
      @temp_var = Glymour::Statistics::Variable.new(@table_data, 10) { |r| r[:temp] }
      @grass_var = Glymour::Statistics::Variable.new(@table_data) { |r| r[:grass_wet] }
      @sprinklers_var = Glymour::Statistics::Variable.new(@table_data) { |r| r[:sprinklers] }
      @cat_var = Glymour::Statistics::Variable.new(@table_data) { |r| r[:cat_out] }
      
      @vars = [@rain_var, @temp_var, @grass_var, @sprinklers_var, @cat_var]
      @lnet = Glymour::StructureLearning::LearningNet.new(@vars)
    end
    
    it 'should initialize a LearningNet on a set of variables' do
      @lnet.should_not be_nil
    end
    
    it 'should perform a step of the structure learning algorithm' do
      prev_net = @lnet.net
      @lnet.step
      prev_net.should_not eq @lnet.net
    end
  end
end