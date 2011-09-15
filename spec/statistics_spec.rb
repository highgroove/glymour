require 'glymour'
require 'rgl/implicit'
require 'rgl/dot'
require 'spec_helper'

describe Glymour::Statistics do
  before(:all) do
    R.echo(true)
    Stats = StatsDummy.new
    
    alarm_init
    coin_init
  end
  
  it 'should give chi square independence data for two variables' do
    Stats.coindependent?(0.05, @h, @red).should be_false
    Stats.coindependent?(0.05, @e, @b).should be_true
  end
  
  it 'should give conditional independence data for several variables' do
    Stats.coindependent?(0.05, @red, @blue, @h).should be_true
    Stats.coindependent?(0.05, @j, @m, @a).should be_true
    Stats.coindependent?(0.05, @b, @ac, @a).should be_true
  end
  
  describe Glymour::Statistics::VariableContainer
    it 'should set variable name when nil' do
      var = Glymour::Statistics::Variable.new {|r| r}
      container = Glymour::Statistics::VariableContainer.new([], [var])
      var.name.should_not be_nil
    end
      
    it 'should create unique names for variables' do
      var1 = Glymour::Statistics::Variable.new {|r| r}
      var2 = Glymour::Statistics::Variable.new {|r| r}
      container = Glymour::Statistics::VariableContainer.new([], [var1, var2])
      var1.name.should_not eq var2.name
    end
end