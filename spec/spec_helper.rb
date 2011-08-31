require "glymour"

class StatsDummy
  include Glymour::Statistics
end

# Returns true with probability p
def prob(p)
  rand < p
end