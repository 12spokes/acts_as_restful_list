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
end
