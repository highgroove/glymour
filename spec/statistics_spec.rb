describe Glymour::Statistics do
  before(:all) do
    table_data = []
    
    10000.times do
      rain = rand < 0.5
      temp = rain ? 65 + 10 * (rand - 0.5) : 75 + 10 * (rand - 0.5)
      sprinklers = rain ? rand < 0.1 : rand < 0.5
      cat_out = rain || sprinklers ? 0.05 : 0.4
      grass_wet = (rain && (rand < 0.9)) || (sprinklers && (rand < 0.7)) || (cat_out && (rand < 0.01))
      table_data << { :rain => rain, :sprinklers => sprinklers, :cat_out => cat_out, :grass_wet => grass_wet, :temp => temp }
    end
    
    rain_var = Variable.new(table_data) { |r| r[:rain] }
    temp_var = Variable.new(table_data, 10) { |r| r[:temp] }
  end
end