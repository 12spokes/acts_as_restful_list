module ActsAsRestfulList
  class << self
    def included base #:nodoc:
      base.extend ClassMethods
    end
  end
  
  module ClassMethods
    # +acts_as_restful_list+ makes the class it is called on automatically behave like an
    # ordered list. There are a number of options you can set:
    # * +column+: The column to use as the position column.  It's set to position by default.
    def acts_as_restful_list(options = {})
      include InstanceMethods
      
      configuration = {:column => :position}.merge(options)
      
      before_create :set_position
      after_update :reset_order_after_update
      after_destroy :reset_order_after_destroy
      
      define_method 'position_column' do
        configuration[:column].to_s
      end
    end
  end
  
  module InstanceMethods
    def set_position
      last_record = self.class.last( :order => "#{position_column} ASC" )
      self.send( "#{position_column}=", ( last_record.nil? ? 1 : last_record.send(position_column) + 1 ) )
    end
    
    def reset_order_after_update
      if self.send( "#{position_column}_changed?" )
        if self.send( "#{position_column}_was" ) > self.send( position_column )
          self.class.update_all("#{position_column} = (#{position_column} + 1)", "#{position_column} >= #{self.send( position_column )} AND id != #{id}")
        else
          self.class.update_all("#{position_column} = (#{position_column} - 1)", "#{position_column} <= #{self.send( position_column )} AND #{position_column} >= #{self.send( "#{position_column}_was" )} AND id != #{id}")
        end
      end
    end
    
    def reset_order_after_destroy
      self.class.update_all("#{position_column} = (#{position_column} - 1)", "#{position_column} > #{self.send( position_column )}")
    end
  end
end

if Object.const_defined?("ActiveRecord")
  ActiveRecord::Base.send(:include, ActsAsRestfulList)
end