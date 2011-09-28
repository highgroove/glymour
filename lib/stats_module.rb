module Glymour
  module Statistics
    class VariableContainer
      attr_reader :table, :number_unnamed
      attr_accessor :variables
      
      def initialize(table, variables=[])
        number_unnamed = 0
        @table = table
        @variables = variables
        @variables.each do |var|
          var.variable_container = self
          var.set_intervals if var.num_classes
          var.name ||= "unnamed_variable#{number_unnamed += 1}"
        end
      end
    end
    
    class Variable
      attr_accessor :intervals, :variable_container, :name, :num_classes
      
      def initialize(name = nil, num_classes = nil, &block)
        @block = Proc.new &block
        @num_classes = num_classes
        @intervals = num_classes && variable_container ? set_intervals : nil
        
        # names are used as variable names in R, so make sure there's no whitespace
        @name = name.gsub(/\s+/, '_') if name
      end
      
      # Apply @block to each column value, and 
      # return a list of evenly divided intervals [x1, x2, ..., x(n_classes)]
      # So that x1 is the minimum, xn is the max
      def set_intervals
        vals = self.values
        step = (vals.max - vals.min)/(num_classes-1).to_f
        @intervals = (0..(num_classes-1)).map { |k| vals.min + k*step }
      end
      
      def value_at(row)
        intervals ? location_in_interval(row) : @block.call(row)
      end
      
      # Gives an array of all variable values in table
      def values
        if variable_container.table < ActiveRecord
          intervals ? variable_container.table.all.map { |row| location_in_interval(row) } : variable_container.table.map { |r| @block.call(r) }
        else
          intervals ? variable_container.table.map { |row| location_in_interval(row) } : variable_container.table.map(&@block)
        end
      end
      
      # Gives the location of a column value within a finite set of interval values (i.e. gives discrete state after classing a continuous variable)
      def location_in_interval(row)
        intervals.each_with_index do |x, i|
          return i if @block.call(row) <= x
        end

        # Return -1 if value is not within intervals
        -1
      end
    end
    
    # Takes two or more Variables
    # Returns true if first two variables are coindependent given the rest
    def coindependent?(p_val, *variables)
      #TODO: Raise an exception if variables have different tables?
      R.echo(false)
      # Push variable data into R
      variables.each do |var|
        # Rinruby can't handle true and false values, so use 1 and 0 resp. instead
        sanitized_values = var.values.map do |value|
          case value
            when true  then 1
            when false then 0
            else value
          end
        end
        
        R.assign var.name, sanitized_values
      end
      
      R.eval <<-EOF
        cond_data <- data.frame(#{variables.map(&:name).join(', ')})
        t <-table(cond_data)
      EOF
      
      cond_vars = variables[2..(variables.length-1)]
      
      # If no conditioning variables are given, just return the chi square test for the first two
      if cond_vars.empty?
        R.eval "chisq <- chisq.test(t)"
        observed_p = R.pull "chisq$p.value"
        return observed_p > p_val
      end
      
      cond_values = cond_vars.map { |var| (1..var.values.uniq.length).collect }
      
      # Find the chi-squared statistic for every state of the conditioning variables and sum them
      chisq_sum = 0
      df = 0
      cond_values.inject!(&:product).map(&:flatten)
      cond_values.each do |value|
        R.eval <<-EOF
          partial_table <- t[,,#{value.join(',')}]
          table_without_zero_columns <- partial_table[,-(which(colSums(partial_table) == 0))]
          chisq <- chisq.test(table_without_zero_columns)
          s <- chisq$statistic
        EOF
        
        observed_s = R.pull("s").to_f
        chisq_sum += observed_s
        df += R.pull("chisq$parameter").to_i
      end
      # Compute the p-value of the sum of statistics
      observed_p = 1 - R.pull("pchisq(#{chisq_sum}, #{df})").to_f
      observed_p > p_val
    end
  end
end