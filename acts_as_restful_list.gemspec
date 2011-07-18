# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/',__FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = %q{acts_as_restful_list}
  s.version     = "0.6"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Trey Bean']
  s.email       = "trey@12spokes.com"
  s.homepage    = "http://github.com/12spokes/acts_as_restful_list"
  s.summary     = "Restful acts_as_list"
  s.description = "Just like acts_as_list, but allows updating through standard restful methods."
  
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  
  s.date = %q{2011-07-18}
  
  
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files =  Dir.glob("lib/**/*") + %w(.gitignore History.rdoc LICENSE README.rdoc Todo.rdoc VERSION ) 
 
  
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_path = "lib"
  s.test_files = Dir.glob('test/**/*.rb')

  s.add_development_dependency "rspec"
  s.add_development_dependency "rake"
  s.add_development_dependency "sqlite3"
end

