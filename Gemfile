# A sample Gemfile
source "http://rubygems.org"
gemspec
# gem "rails"

group :development do
  activerecord_version = ENV['AARL_ACTIVERECORD_VERSION']

  if activerecord_version && activerecord_version.strip != ""
    gem "activerecord", activerecord_version
  else
    gem "activerecord"
  end
end