require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ActsAsRestfulList" do
  after(:each) do
    ActiveRecord::Base.connection.execute("DELETE FROM mixins")
    ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence where name='mixins'")
  end
  
  describe 'standard declaration with no options' do
    before(:all) do
      ActiveRecord::Schema.define(:version => 1) do
        create_table :mixins do |t|
          t.column :position, :integer
          t.column :parent_id, :integer
          t.column :created_at, :datetime
          t.column :updated_at, :datetime
        end
      end
      
      class Mixin < ActiveRecord::Base
        acts_as_restful_list
      end
    end
    
    after(:all) do
      Object.send(:remove_const, :Mixin)

      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
      end
    end
    
    it "should return position as it's position column" do
      Mixin.new.position_column.should == 'position'
    end
    
    it 'should set the position before creating the record' do
      mixin = Mixin.new
      mixin.should_receive(:set_position).and_return(true)
      mixin.save!
    end
    
    it 'should save the first record with position 1' do
      Mixin.create!.position.should == 1
    end
    
    it 'should put each new record at the end of the list' do
      (1..4).each do |n|
        Mixin.create!.position.should == n
      end
    end
    
    it "updates the full order of a list if no positions already exist" do
      4.times{ Mixin.create! }
      ActiveRecord::Base.connection.execute("update mixins set position = NULL;")
      Mixin.create!.position.should == 5
    end
    
    describe 'reordering on update' do
      before(:each) do
        (1..4).each{ Mixin.create! }
      end
      
      it 'should reset order after updating a record' do
        mixin = Mixin.create
        mixin.should_receive(:reset_order_after_update).and_return(true)
        mixin.save!
      end
      
      it 'should automatically reorder the list if a record is updated with a lower position' do
        fourth_mixin = Mixin.first( :conditions => { :position => 4 } )
        fourth_mixin.position = 2
        fourth_mixin.save!
        fourth_mixin.reload.position.should == 2
        Mixin.all(:order => 'position ASC').collect(&:position).should == [1,2,3,4]
      end
      
      it 'should reorder the list correctly if a record in the middle is updated with a lower position' do
        third_mixin = Mixin.first( :conditions => { :position => 3 } )
        third_mixin.position = 2
        third_mixin.save!
        third_mixin.reload.position.should == 2
        Mixin.all(:order => 'position ASC').collect(&:position).should == [1,2,3,4]
      end
      
      it 'should automatically reorder the list if a record is updated with a higher position' do
        second_mixin = Mixin.first( :conditions => { :position => 2 } )
        second_mixin.position = 4
        second_mixin.save!
        second_mixin.reload.position.should == 4
        Mixin.all(:order => 'position ASC').collect(&:position).should == [1,2,3,4]
      end
      
      it "should create an order if there is none" do
        ActiveRecord::Base.connection.execute("update mixins set position = NULL;")
        mixin = Mixin.first
        mixin.position = 3
        mixin.save!
        Mixin.all(:order => 'position ASC').collect(&:position).should == [1,2,3,4]
      end
    end
    
    describe 'reordering on deletion' do
      it 'should reset the order after deleting a record' do
        mixin = Mixin.create
        mixin.should_receive(:reset_order_after_destroy).and_return(true)
        mixin.destroy
      end
      
      it 'should automatically reorder the list if the record is deleted' do
        (1..4).each{ Mixin.create! }
        second_mixin = Mixin.first( :conditions => { :position => 2 } )
        second_mixin.destroy
        Mixin.all(:order => 'position ASC').collect(&:position).should == [1,2,3]
      end
    end
    
    it 'should return nil for scope_condition since it was not set' do
      Mixin.new.scope_condition.should be_nil
    end
  end
  
  describe 'optimistic locking' do
    before(:all) do
      ActiveRecord::Schema.define(:version => 1) do
        create_table :mixins do |t|
          t.column :position, :integer
          t.column :parent_id, :integer
          t.column :lock_version, :integer, :default => 0
          t.column :created_at, :datetime
          t.column :updated_at, :datetime
        end
      end
      
      class Mixin < ActiveRecord::Base
        acts_as_restful_list
      end
    end
    
    after(:all) do
      Object.send(:remove_const, :Mixin)

      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
      end
    end
    
    before(:each) do
      (1..4).each{ Mixin.create! }
    end
    
    describe 'reordering on destroy' do
      it 'should raise an error for stale objects' do
        second_mixin = Mixin.first( :conditions => { :position => 2 } )
        third_mixin  = Mixin.first( :conditions => { :position => 3 } )
        second_mixin.destroy
        lambda {
          third_mixin.destroy
        }.should raise_error(ActiveRecord::StaleObjectError)
      end
      
      it 'should NOT raise an error if update did not affect existing position' do
        second_mixin = Mixin.first( :conditions => { :position => 2 } )
        third_mixin  = Mixin.first( :conditions => { :position => 3 } )
        third_mixin.destroy
        lambda {
          second_mixin.destroy
        }.should_not raise_error(ActiveRecord::StaleObjectError)
        Mixin.all(:order => 'position ASC').collect(&:position).should == [1,2]
      end
    end
    
    describe 'reordering on update' do
      it 'should raise an error for stale objects' do
        first_mixin  = Mixin.first( :conditions => { :position => 1 } )
        fourth_mixin = Mixin.first( :conditions => { :position => 4 } )
        fourth_mixin.update_attributes(:position => 1)
        lambda {
          first_mixin.update_attributes(:position => 2)
        }.should raise_error(ActiveRecord::StaleObjectError)
      end
      
      it 'should NOT raise an error if update did not affect existing position' do
        first_mixin  = Mixin.first( :conditions => { :position => 1 } )
        fourth_mixin = Mixin.first( :conditions => { :position => 4 } )
        fourth_mixin.update_attributes(:position => 2)
        lambda {
          first_mixin.update_attributes(:position => 3)
        }.should_not raise_error(ActiveRecord::StaleObjectError)
        Mixin.all(:order => 'position ASC').collect(&:position).should == [1,2,3,4]
      end
    end
    
  end
  
  describe 'declaring acts_as_restful_list and setting the column' do
    before(:all) do
      ActiveRecord::Schema.define(:version => 1) do
        create_table :mixins do |t|
          t.column :pos, :integer
          t.column :parent_id, :integer
          t.column :created_at, :datetime
          t.column :updated_at, :datetime
        end
      end
      
      class Mixin < ActiveRecord::Base
        acts_as_restful_list :column => :pos
      end
    end
    
    after(:all) do
      Object.send(:remove_const, :Mixin)

      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
      end
    end
    
    it "should return pos as it's position column" do
      Mixin.new.position_column.should == 'pos'
    end
    
    it 'should set the position before creating the record' do
      mixin = Mixin.new
      mixin.should_receive(:set_position).and_return(true)
      mixin.save!
    end
    
    it 'should save the first record with position 1' do
      Mixin.create!.pos.should == 1
    end
    
    it 'should put each new record at the end of the list' do
      (1..4).each do |n|
        Mixin.create!.pos.should == n
      end
    end
    
    describe 'reordering on update' do
      before(:each) do
        (1..4).each{ Mixin.create! }
      end
      
      it 'should reset order after updating a record' do
        mixin = Mixin.create
        mixin.should_receive(:reset_order_after_update).and_return(true)
        mixin.save!
      end
      
      it 'should automatically reorder the list if a record is updated with a lower position' do
        fourth_mixin = Mixin.first( :conditions => { :pos => 4 } )
        fourth_mixin.pos = 2
        fourth_mixin.save!
        fourth_mixin.reload.pos.should == 2
        Mixin.all(:order => 'pos ASC').collect(&:pos).should == [1,2,3,4]
      end
      
      it 'should automatically reorder the list if a record is updated with a higher position' do
        second_mixin = Mixin.first( :conditions => { :pos => 2 } )
        second_mixin.pos = 4
        second_mixin.save!
        second_mixin.reload.pos.should == 4
        Mixin.all(:order => 'pos ASC').collect(&:pos).should == [1,2,3,4]
      end
    end
    
    describe 'reordering on deletion' do
      it 'should reset the order after deleting a record' do
        mixin = Mixin.create
        mixin.should_receive(:reset_order_after_destroy).and_return(true)
        mixin.destroy
      end
      
      it 'should automatically reorder the list if the record is deleted' do
        (1..4).each{ Mixin.create! }
        second_mixin = Mixin.first( :conditions => { :pos => 2 } )
        second_mixin.destroy
        Mixin.all(:order => 'pos ASC').collect(&:pos).should == [1,2,3]
      end
    end
  end
  
  describe 'declaring acts_as_restful_list and setting the scope' do
    before(:all) do
      ActiveRecord::Schema.define(:version => 1) do
        create_table :mixins do |t|
          t.column :position, :integer
          t.column :parent_id, :integer
          t.column :created_at, :datetime
          t.column :updated_at, :datetime
        end
      end
      
      class Mixin < ActiveRecord::Base
        acts_as_restful_list :scope => :parent_id
      end
    end
    
    after(:all) do
      Object.send(:remove_const, :Mixin)

      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
      end
    end
    
    it 'should define scope_condition as an instance method' do
      Mixin.new.should respond_to(:scope_condition)
    end
    
    it 'should return a scope condition that limits based on the parent_id' do
      Mixin.new(:parent_id => 3).scope_condition.should == "parent_id = 3"
    end
    
    it 'should return a scope limiting based parent_id being NULL if parent_id is nil' do
      Mixin.new.scope_condition.should == "parent_id IS NULL"
    end
    
    it 'should set the position based on the scope list when adding a new item' do
      Mixin.create!.position.should == 1
      Mixin.create!(:parent_id => 1).position.should == 1
      Mixin.create!(:parent_id => 1).position.should == 2
      Mixin.create!(:parent_id => 2).position.should == 1
    end
    
    describe 'reordering on update' do
      before(:each) do
        (1..4).each{ Mixin.create!(:parent_id => 1) }
        (1..6).each{ Mixin.create!(:parent_id => 2) }
      end
      
      it 'should automatically reorder the list if a record is updated with a lower position' do
        fourth_mixin = Mixin.first( :conditions => { :position => 4, :parent_id => 1 } )
        fourth_mixin.position = 2
        fourth_mixin.save!
        fourth_mixin.reload.position.should == 2
        Mixin.all(:conditions => { :parent_id => 1 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
        Mixin.all(:conditions => { :parent_id => 2 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4,5,6]
      end
      
      it 'should automatically reorder the list if a record is updated with a higher position' do
        second_mixin = Mixin.first( :conditions => { :position => 2, :parent_id => 1  } )
        second_mixin.position = 4
        second_mixin.save!
        second_mixin.reload.position.should == 4
        Mixin.all(:conditions => { :parent_id => 1 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
        Mixin.all(:conditions => { :parent_id => 2 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4,5,6]
      end
      
      it 'should report the old and new scope correctly' do
        second_mixin = Mixin.first( :conditions => { :position => 2, :parent_id => 1  } )
        second_mixin.parent_id = 2
        second_mixin.position = 4
        second_mixin.scope_condition_was.should == 'parent_id = 1'
        second_mixin.scope_condition.should == 'parent_id = 2'
      end
      
      it 'should automatically reorder both lists if a record is moved between them' do
        second_mixin = Mixin.first( :conditions => { :position => 2, :parent_id => 1  } )
        second_mixin.parent_id = 2
        second_mixin.position = 4
        second_mixin.save!
        second_mixin.reload.parent_id.should == 2
        second_mixin.reload.position.should == 4
        Mixin.all(:conditions => { :parent_id => 1 }, :order => 'position ASC').collect(&:position).should == [1,2,3]
        Mixin.all(:conditions => { :parent_id => 2 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4,5,6,7]
      end
    end
    
    it 'should automatically reorder the list scoped by parent if the record is deleted' do
      (1..4).each{ Mixin.create!(:parent_id => 1) }
      (1..6).each{ Mixin.create!(:parent_id => 2) }
      second_mixin = Mixin.first( :conditions => { :position => 2, :parent_id => 1 } )
      second_mixin.destroy
      Mixin.all(:conditions => { :parent_id => 1 }, :order => 'position ASC').collect(&:position).should == [1,2,3]
      Mixin.all(:conditions => { :parent_id => 2 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4,5,6]
    end
  end
  
  describe 'declaring acts_as_restful_list and setting the scope without the _id' do
    before(:all) do
      ActiveRecord::Schema.define(:version => 1) do
        create_table :mixins do |t|
          t.column :position, :integer
          t.column :parent_id, :integer
          t.column :created_at, :datetime
          t.column :updated_at, :datetime
        end
      end
      
      class Mixin < ActiveRecord::Base
        acts_as_restful_list :scope => :parent
      end
    end
    
    after(:all) do
      Object.send(:remove_const, :Mixin)

      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
      end
    end
    
    it 'should define scope_condition as an instance method' do
      Mixin.new.should respond_to(:scope_condition)
    end
    
    it 'should return a scope condition that limits based on the parent_id' do
      Mixin.new(:parent_id => 3).scope_condition.should == "parent_id = 3"
    end
  end
  
  
  describe 'declaring acts_as_restful_list and setting the scope on a column that is not an _id column' do
    before(:all) do
      ActiveRecord::Schema.define(:version => 1) do
        create_table :mixins do |t|
          t.column :position, :integer
          t.column :parent_name, :string
          t.column :created_at, :datetime
          t.column :updated_at, :datetime
        end
      end
      
      class Mixin < ActiveRecord::Base
        acts_as_restful_list :scope => :parent_name
      end
    end
    
    after(:all) do
      Object.send(:remove_const, :Mixin)
      
      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
      end
    end
    
    it 'should define scope_condition as an instance method' do
      Mixin.new.should respond_to(:scope_condition)
    end
    
    it 'should return a scope condition that limits based on the parent_id' do
      Mixin.new(:parent_name => 'Brandy').scope_condition.should == "parent_name = 'Brandy'"
    end
  end
  
  
  describe 'declaring acts_as_restful_list and setting the scope to multiple columns' do
    before(:all) do
      ActiveRecord::Schema.define(:version => 1) do
        create_table :mixins do |t|
          t.column :position, :integer
          t.column :user_id, :integer
          t.column :parent_id, :integer
          t.column :created_at, :datetime
          t.column :updated_at, :datetime
        end
      end
      
      class Mixin < ActiveRecord::Base
        acts_as_restful_list :scope => [:parent, :user]
      end
    end
    
    after(:all) do
      Object.send(:remove_const, :Mixin)
      
      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
      end
    end
    
    it 'should define scope_condition as an instance method' do
      Mixin.new.should respond_to(:scope_condition)
    end
    
    it 'should return a scope condition that limits based on the parent_id' do
      Mixin.new(:user_id => 4, :parent_id => 3).scope_condition.should == "parent_id = 3 AND user_id = 4"
    end
    
    describe 'reordering on update' do
      before(:each) do
        (1..4).each{ Mixin.create!(:parent_id => 1, :user_id => 5) }
        (1..4).each{ Mixin.create!(:parent_id => 2, :user_id => 5) }
        (1..4).each{ Mixin.create!(:parent_id => 1, :user_id => 7) }
        (1..4).each{ Mixin.create!(:parent_id => 2, :user_id => 7) }
      end
      
      it 'should automatically reorder the list if a record is updated with a lower position' do
        user5_parent1_fourth_mixin = Mixin.first( :conditions => { :position => 4, :parent_id => 1, :user_id => 5 } )
        user5_parent1_fourth_mixin.position = 2
        user5_parent1_fourth_mixin.save!
        user5_parent1_fourth_mixin.reload.position.should == 2
        Mixin.all(:conditions => { :parent_id => 1, :user_id => 5 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
        Mixin.all(:conditions => { :parent_id => 1, :user_id => 5 }, :order => 'position ASC').collect(&:id).should == [1,4,2,3]
        Mixin.all(:conditions => { :parent_id => 2, :user_id => 5 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
        Mixin.all(:conditions => { :parent_id => 2, :user_id => 5 }, :order => 'position ASC').collect(&:id).should == [5,6,7,8]
        Mixin.all(:conditions => { :parent_id => 1, :user_id => 7 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
        Mixin.all(:conditions => { :parent_id => 1, :user_id => 7 }, :order => 'position ASC').collect(&:id).should == [9,10,11,12]
        Mixin.all(:conditions => { :parent_id => 2, :user_id => 7 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
        Mixin.all(:conditions => { :parent_id => 2, :user_id => 7 }, :order => 'position ASC').collect(&:id).should == [13,14,15,16]
      end
      
      it 'should automatically reorder the list if a record is updated with a higher position' do
        second_mixin = Mixin.first( :conditions => { :position => 2, :parent_id => 1, :user_id => 5  } )
        second_mixin.position = 4
        second_mixin.save!
        second_mixin.reload.position.should == 4
        Mixin.all(:conditions => { :parent_id => 1, :user_id => 5 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
        Mixin.all(:conditions => { :parent_id => 1, :user_id => 5 }, :order => 'position ASC').collect(&:id).should == [1,3,4,2]
        Mixin.all(:conditions => { :parent_id => 2, :user_id => 5 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
        Mixin.all(:conditions => { :parent_id => 2, :user_id => 5 }, :order => 'position ASC').collect(&:id).should == [5,6,7,8]
        Mixin.all(:conditions => { :parent_id => 1, :user_id => 7 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
        Mixin.all(:conditions => { :parent_id => 1, :user_id => 7 }, :order => 'position ASC').collect(&:id).should == [9,10,11,12]
        Mixin.all(:conditions => { :parent_id => 2, :user_id => 7 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
        Mixin.all(:conditions => { :parent_id => 2, :user_id => 7 }, :order => 'position ASC').collect(&:id).should == [13,14,15,16]
      end
    end
    
    it 'should automatically reorder if the record is deleted' do
      (1..4).each{ Mixin.create!(:parent_id => 1, :user_id => 5) }
      (1..4).each{ Mixin.create!(:parent_id => 2, :user_id => 5) }
      (1..4).each{ Mixin.create!(:parent_id => 1, :user_id => 7) }
      (1..4).each{ Mixin.create!(:parent_id => 2, :user_id => 7) }
      second_mixin = Mixin.first( :conditions => { :position => 2, :parent_id => 1, :user_id => 5 } )
      second_mixin.destroy
      Mixin.all(:conditions => { :parent_id => 1, :user_id => 5 }, :order => 'position ASC').collect(&:position).should == [1,2,3]
      Mixin.all(:conditions => { :parent_id => 1, :user_id => 5 }, :order => 'position ASC').collect(&:id).should == [1,3,4]
      Mixin.all(:conditions => { :parent_id => 2, :user_id => 5 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
      Mixin.all(:conditions => { :parent_id => 2, :user_id => 5 }, :order => 'position ASC').collect(&:id).should == [5,6,7,8]
      Mixin.all(:conditions => { :parent_id => 1, :user_id => 7 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
      Mixin.all(:conditions => { :parent_id => 1, :user_id => 7 }, :order => 'position ASC').collect(&:id).should == [9,10,11,12]
      Mixin.all(:conditions => { :parent_id => 2, :user_id => 7 }, :order => 'position ASC').collect(&:position).should == [1,2,3,4]
      Mixin.all(:conditions => { :parent_id => 2, :user_id => 7 }, :order => 'position ASC').collect(&:id).should == [13,14,15,16]
    end
  end
end
