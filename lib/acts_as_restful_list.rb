module ActsAsRestfulList
  class << self
    def included base #:nodoc:
      base.extend ClassMethods
    end
  end
  
  module ClassMethods
    def acts_as_restful_list
      include InstanceMethods
      
      before_create :set_position
      after_update :reset_order
    end
  end
  
  module InstanceMethods
    def set_position
      last_record = self.class.last(:order => 'position ASC')
      self.position = last_record.nil? ? 1 : last_record.position + 1
    end
    
    def reset_order
      if position_changed?
        if position_was > position
          self.class.update_all("position = (position + 1)", "position >= #{position} AND id != #{id}")
        else
          self.class.update_all("position = (position - 1)", "position <= #{position} AND position >= #{position_was} AND id != #{id}")
        end
      end
    end
  end
end

if Object.const_defined?("ActiveRecord")
  ActiveRecord::Base.send(:include, ActsAsRestfulList)
end