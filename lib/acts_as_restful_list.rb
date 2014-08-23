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
    # * +scope+: The column to scope the list to.  It takes a symbol with our without the _id.
    def acts_as_restful_list(options = {})
      include InstanceMethods

      configuration = {:column => :position}.merge(options)

      before_create :set_position
      after_update :reset_order_after_update
      after_destroy :reset_order_after_destroy

      define_method 'position_column' do
        configuration[:column].to_s
      end

      define_method 'scope_condition' do
        if configuration[:scope].nil?
          nil
        else
          scopes = Array(configuration[:scope]).collect do |scope|
            column = self.class.column_names.include?(scope.to_s) ? scope.to_s : "#{scope}_id"
            value = self.send(column)
            value.nil? ? "#{column} IS NULL" : "#{column} = #{value.is_a?(String) ? "'#{value}'" : value}"
          end
          scopes.join(' AND ')
        end
      end

      define_method 'scope_condition_was' do
        if configuration[:scope].nil?
          nil
        else
          scopes = Array(configuration[:scope]).collect do |scope|
            column = self.class.column_names.include?(scope.to_s) ? scope.to_s : "#{scope}_id"
            value = self.send("#{column}_was")
            value.nil? ? "#{column} IS NULL" : "#{column} = #{value.is_a?(String) ? "'#{value}'" : value}"
          end
          scopes.join(' AND ')
        end
      end

      define_method 'optimistic_locking_update' do
        self.class.column_names.include?("lock_version") ? ", lock_version = (lock_version + 1)" : ""
      end
    end
  end

  module InstanceMethods
    def set_position
      initialize_order if !last_record.nil? and last_record_position.nil?

      self.send( "#{position_column}=", last_record.nil? ? 1 : last_record_position + 1)
    end

    def reset_order_after_update
      if previous_position.nil?
        initialize_order
      else
        if scope_condition != scope_condition_was
          conditions = [scope_condition_was, "#{position_column} > #{previous_position}", "id != #{id}"].compact.join(' AND ')
          self.class.where(conditions).update_all(decrement_position_sql)

          conditions = [scope_condition, "#{position_column} >= #{current_position}", "id != #{id}"].compact.join(' AND ')
          self.class.where(conditions).update_all(increment_position_sql)
        elsif self.send( "#{position_column}_changed?" )
          if previous_position > current_position
            conditions = [scope_condition, "#{position_column} >= #{current_position}", "id != #{id}", "#{position_column} < #{previous_position}"].compact.join(' AND ')
            self.class.where(conditions).update_all(increment_position_sql)
          else
            conditions = [scope_condition, "#{position_column} <= #{current_position}", "#{position_column} >= #{previous_position}", "id != #{id}"].compact.join(' AND ')
            self.class.where(conditions).update_all(decrement_position_sql)
          end
        end
      end
    end

    def reset_order_after_destroy
      conditions = [scope_condition, "#{position_column} > #{self.send(position_column)}"].compact.join(' AND ')
      self.class.where(conditions).update_all("#{position_column} = (#{position_column} - 1) #{optimistic_locking_update}")
    end

    def initialize_order
      initial_set = self.class.find(:all,:conditions=>scope_condition,:select=>"id",:order=>"created_at ASC")

      initial_set.each_with_index do |item,idx|
        ActiveRecord::Base.connection.execute("update #{self.class.table_name} set position = #{idx + 1} where id = #{item.id};")
      end
    end

    def last_record
      self.class.order("#{position_column} ASC").where(scope_condition).last
    end

    def last_record_position
      last_record.send(position_column)
    end

    def current_position
      self.send( position_column )
    end

    def current_position=(value)
      self.send( "#{position_column}=", value )
    end

    def previous_position
      self.send( "#{position_column}_was" )
    end

    def increment_position_sql
      "#{position_column} = (#{position_column} + 1) #{optimistic_locking_update}"
    end

    def decrement_position_sql
      "#{position_column} = (#{position_column} - 1) #{optimistic_locking_update}"
    end
  end
end

if Object.const_defined?("ActiveRecord")
  ActiveRecord::Base.send(:include, ActsAsRestfulList)
end
