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
      100.times do
        e = prob(0.002)
        b = prob(0.001)
        a = b ? (e ? prob(0.95) : prob(0.94)) : (e ? prob(0.29) : prob(0.001))
        j = a ? prob(0.90) : prob(0.05)
        m = a ? prob(0.70) : prob(0.01)
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
      
      # Highly simplified test net
      # Only edges should be @h pointing to @red and @blue
      @coin_data = []
      10000.times do
        h = prob(0.5)
        red = h ? prob(0.2) : prob(0.7)
        blue = h ? prob(0.4) : prob(0.9)
        @coin_data << { :h => h, :red => red, :blue => blue }
      end

      @h = Glymour::Statistics::Variable.new(@coin_data) { |r| r[:h] }
      @red = Glymour::Statistics::Variable.new(@coin_data) { |r| r[:red] }
      @blue = Glymour::Statistics::Variable.new(@coin_data) { |r| r[:blue] }
      
      @coin_hash = { @h => 'h', @red => 'red', @blue => 'blue'}
      @coin_net = Glymour::StructureLearning::LearningNet.new([@h, @red, @blue])
    end
    
    it 'should perform the structure learning algorithm' do
      @coin_net.learn_structure
      
      @coin_net.net.edges.each do |e|
        puts "#{@coin_hash[e.source]} => #{@coin_hash[e.target]}"
      end
    end
  end
end