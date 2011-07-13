#!/bin/sh

set -e

gem list --local bundler | grep bundler || gem install bundler --no-ri --no-rdoc

echo 'Running bundle exec rspec spec against activesupport / activerecord 2.3.12...'

AARL_ACTIVERECORD_VERSION=2.3.12 bundle update activerecord
bundle exec rspec spec

echo 'Running bundle exec rspec spec against activesupport / activerecord 3.0.9...'

AARL_ACTIVERECORD_VERSION=3.0.9 bundle update activerecord
bundle exec rspec spec

echo 'Success!'