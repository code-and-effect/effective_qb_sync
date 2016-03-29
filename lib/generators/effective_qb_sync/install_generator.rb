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

      def copy_mailer_preview
        mailer_preview_path = (Rails.application.config.action_mailer.preview_path rescue nil)

        if mailer_preview_path.present?
          template 'effective_qb_sync_mailer_preview.rb', File.join(mailer_preview_path, 'effective_qb_sync_mailer_preview.rb')
        else
          puts "couldn't find action_mailer.preview_path.  Skipping effective_qb_sync_mailer_preview."
        end
      end

      def create_migration_file
        @qb_requests_table_name = ':' + EffectiveQbSync.qb_requests_table_name.to_s
        @qb_tickets_table_name = ':' + EffectiveQbSync.qb_tickets_table_name.to_s
        @qb_logs_table_name = ':' + EffectiveQbSync.qb_logs_table_name.to_s
        @qb_order_items_table_name = ':' + EffectiveQbSync.qb_order_items_table_name.to_s

        migration_template '../../../db/migrate/01_create_effective_qb_sync.rb.erb', 'db/migrate/create_effective_qb_sync.rb'
      end
    end
  end
end
