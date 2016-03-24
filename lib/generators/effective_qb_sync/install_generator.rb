module EffectiveQbSync
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      desc "Creates an EffectiveQbSync initializer in your application."

      source_root File.expand_path("../../templates", __FILE__)

      def self.next_migration_number(dirname)
        if not ActiveRecord::Base.timestamped_migrations
          Time.new.utc.strftime("%Y%m%d%H%M%S")
        else
          "%.3d" % (current_migration_number(dirname) + 1)
        end
      end

      def copy_initializer
        template "effective_qb_sync.rb", "config/initializers/effective_qb_sync.rb"
      end

      def create_migration_file
        @qb_requests_table_name = ':' + EffectiveQbSync.qb_requests_table_name.to_s
        @qb_tickets_table_name = ':' + EffectiveQbSync.qb_tickets_table_name.to_s
        @qb_logs_table_name = ':' + EffectiveQbSync.qb_logs_table_name.to_s
        @qb_order_items_table_name = ':' + EffectiveQbSync.qb_order_items_table_name.to_s

        migration_template '../../../db/migrate/01_create_effective_qb_sync.rb.erb', 'db/migrate/create_effective_qb_sync.rb'
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
