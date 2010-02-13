require 'rubygems'
gem 'activerecord', '>= 1.15.4.7794'
require 'active_record'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'acts_as_restful_list'
require 'spec'
require 'spec/autorun'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

Spec::Runner.configure do |config|
  config.before(:all) do
    ActiveRecord::Schema.define(:version => 1) do
      create_table :mixins do |t|
        t.column :position, :integer
        t.column :parent_id, :integer
        t.column :created_at, :datetime      
        t.column :updated_at, :datetime
      end
    end
  end
  
  config.after(:all) do
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
  end
end
