require 'spec_helper'

describe Glymour::Statistics do
  before(:all) do
    Stats = StatsDummy.new
    
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
  end
  
  it 'should give coindependence data for two variable' do
    Stats.coindependent?(@temp_var, @sprinklers_var, [@rain_var]).should be_true
    Stats.coindependent?(@rain_var, @sprinklers_var).should be_false
  end
end