require 'glymour'
require 'rgl/implicit'
require 'rgl/dot'
require 'spec_helper'

describe Glymour::Statistics do
  before(:all) do
    R.echo(true)
    Stats = StatsDummy.new
    
    @alarm_data = []
    10000.times do
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
    @alarm_net = Glymour::StructureLearning::LearningNet.new(alarm_vars)
    binding.pry
  end
  
  it 'should give coindependence data for two variable' do
    Stats.coindependent?(0.05, @e, @a).should be_false
    Stats.coindependent?(0.05, @j, @m, @a).should be_true
  end
end