#!/usr/bin/env rake
require "bundler/gem_tasks"

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.pattern = "spec/**/*_spec.rb"
end

task :default => :test

task :herokuize do
  gems = ['service-client', 'datastore-client', 'graph-client']
  paths = gems.map {|gem| [gem, `bundle show --paths|grep #{gem}`.chomp]}

  root = File.dirname(__FILE__)

  gemfile = File.read(File.expand_path('./Gemfile', root))
  original_gemfile = gemfile.clone

  `rm -rf #{root}/vendor/gems`
  `mkdir -p #{root}/vendor/gems`

  `git branch -D heroku`
  `git checkout -b heroku`

  paths.each do |gem, path|
    basename = File.basename(path)
    `rm -rf /tmp/#{basename}`
    `cp -r #{path} /tmp/#{basename}`
    `rm -rf /tmp/#{basename}/.git`
    `cp -r /tmp/#{basename} #{root}/vendor/gems`
    gemfile.gsub!(/^gem '#{gem}',.*$/, "gem '#{gem}', path: 'vendor/gems/#{basename}'")
  end

  File.open(File.expand_path("./Gemfile", root), 'w') {|f| f.write(gemfile)}
  `bundle`
  `git add Gemfile*`
  `git add vendor/*`
  `git commit -m "Heroku Deploy"`
  `git push heroku heroku:master -f`
  `git co -`
  `git checkout Gemfile`
  `git checkout Gemfile.lock`

  `rm -rf #{root}/vendor/gems`
end
