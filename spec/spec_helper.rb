require "glymour"

class StatsDummy
  include Glymour::Statistics
end

# Returns true with probability p
def prob(p)
  rand < p
end

def alarm_init
  @alarm_data = []
  100000.times do
    earthquake = prob(0.01)
    burglary = prob(0.007)
  
    if burglary
      alarm = earthquake ? prob(0.95) : prob(0.94)
    else
      alarm = earthquake ? prob(0.29) : prob(0.001)
    end
  
    john_calls = alarm ? prob(0.90) : prob(0.05)
    mary_calls = alarm ? prob(0.70) : prob(0.01)
    
    alarm_continuous = rand(50)
  
    @alarm_data << { :e => earthquake, :b => burglary, :a => alarm, :j => john_calls, :m => mary_calls, :ac => alarm_continuous }
  end
  @e = Glymour::Statistics::Variable.new("Earthquake") { |r| r[:e] }
  @b = Glymour::Statistics::Variable.new("Burglary") { |r| r[:b] }
  @a = Glymour::Statistics::Variable.new("Alarm") { |r| r[:a] }
  @j = Glymour::Statistics::Variable.new("John Calls") { |r| r[:j] }
  @m = Glymour::Statistics::Variable.new("Mary Calls") { |r| r[:m] }
  
  @ac = Glymour::Statistics::Variable.new("Alarm Continuous", 10) { |r| r[:ac] }
  
  alarm_vars = [@e, @b, @a, @j, @m, @ac]

  alarm_container = Glymour::Statistics::VariableContainer.new(@alarm_data, alarm_vars)
  @alarm_net = Glymour::StructureLearning::LearningNet.new(alarm_container)
end

def coin_init
  # Highly simplified test net
  # Only edges should be @h pointing to @red and @blue
  @coin_data = []
  10000.times do
    h = prob(0.5)
    red = h ? prob(0.2) : prob(0.7)
    blue = h ? prob(0.4) : prob(0.9)
    @coin_data << { :h => h, :red => red, :blue => blue }
  end
  
  @h = Glymour::Statistics::Variable.new("Heads") { |r| r[:h] }
  @red = Glymour::Statistics::Variable.new("Red") { |r| r[:red] }
  @blue = Glymour::Statistics::Variable.new("Blue") { |r| r[:blue] }
  
  coin_container = Glymour::Statistics::VariableContainer.new(@coin_data, [@h, @red, @blue])
  @coin_net = Glymour::StructureLearning::LearningNet.new(coin_container)
end