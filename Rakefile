# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'active_record'
require 'yaml'

namespace :db do
  db_config = YAML.load_file('config/database.yml')

  desc 'Create the database'
  task :create do
    ActiveRecord::Base.establish_connection(db_config['development'])
    ActiveRecord::Base.connection
  end

  desc 'Migrate the database'
  task :migrate do
    ActiveRecord::Base.establish_connection(db_config['development'])
    ActiveRecord::Migrator.migrate('db/migrate')
  end

  desc 'Drop the database'
  task :drop do
    File.delete(db_config['development']['database']) if File.exist?(db_config['development']['database'])
  end

  desc 'Generate migration file'
  task :generate_migration do
    name = ENV['NAME']
    if name.nil?
      puts 'Please specify the NAME environment variable'
    else
      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      migration_file = File.join('db', 'migrate', "#{timestamp}_#{name}.rb")
      File.write(migration_file, "class #{name.camelize} < ActiveRecord::Migration[7.1]\n  def change\n  end\nend\n")
    end
  end
end
