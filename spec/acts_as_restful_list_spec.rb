require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ActsAsRestfulList" do
  after(:each) do
    ActiveRecord::Base.connection.execute("DELETE FROM mixins")
    ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence where name='mixins'")
  end
  
  describe 'standard declaration with no options' do
    before(:all) do
      class Mixin < ActiveRecord::Base
        acts_as_restful_list
      end
    end
    
    after(:all) do
      Object.send(:remove_const, :Mixin)
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
      
      it 'should automatically reorder the list if a record is updated with a higher position' do
        second_mixin = Mixin.first( :conditions => { :position => 2 } )
        second_mixin.position = 4
        second_mixin.save!
        second_mixin.reload.position.should == 4
        Mixin.all(:order => 'position ASC').collect(&:position).should == [1,2,3,4]
      end
    end
      
    describe 'reordering on deletion' do
      it 'should reset the order after deleting a record' do
        mixin = Mixin.create
        mixin.should_receive(:reset_order_after_destroy).and_return(true)
        mixin.destroy
      end
      
      it 'should automatically reorder the list if the record id deleted' do
        (1..4).each{ Mixin.create! }
        second_mixin = Mixin.first( :conditions => { :position => 2 } )
        second_mixin.destroy
        Mixin.all(:order => 'position ASC').collect(&:position).should == [1,2,3]
      end
    end
  end
end
