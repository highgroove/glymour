require 'glymour'
require 'rgl/implicit'
require 'rgl/dot'
require 'spec_helper'

describe Glymour::Statistics do
  before(:all) do
    R.echo(true)
    Stats = StatsDummy.new
    
    @alarm_data = []
    100000.times do
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
    @alarm_net = Glymour::StructureLearning::LearningNet.new(alarm_vars)
    
    @coin_data = []
    10000.times do
      h = prob(0.5)
      red = h ? prob(0.2) : prob(0.7)
      blue = h ? prob(0.5) : prob(0.9)
      @coin_data << { :h => h, :red => red, :blue => blue }
    end
    
    @h = Glymour::Statistics::Variable.new(@coin_data) { |r| r[:h] }
    @red = Glymour::Statistics::Variable.new(@coin_data) { |r| r[:red] }
    @blue = Glymour::Statistics::Variable.new(@coin_data) { |r| r[:blue] }
    @coin_net = Glymour::StructureLearning::LearningNet.new([@h, @red, @blue])
  end
  
  it 'should give chi square independence data for two variables' do
    Stats.coindependent?(0.05, @h, @red).should be_false
    Stats.coindependent?(0.05, @e, @b).should be_true
  end
  
  it 'should give conditional independence data for several variables' do
    Stats.coindependent?(0.05, @red, @blue, @h).should be_true
    Stats.coindependent?(0.05, @j, @m, @a).should be_true
  end
end