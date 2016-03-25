module EffectiveQbSync
  class Engine < ::Rails::Engine
    engine_name 'effective_qb_sync'

    config.autoload_paths += Dir["#{config.root}/app/models/**/"]

    # Set up our default configuration options.
    initializer "effective_qb_sync.defaults", before: :load_config_initializers do |app|
      eval File.read("#{config.root}/lib/generators/templates/effective_qb_sync.rb")
    end

    # Ensure every acts_as_purchasable object responds to qb_item_name
    initializer 'effective_qb_sync.assert_qb_item_names_present' do |app|
      if Rails.env.development?
        Rails.application.eager_load!

        invalids = ActsAsPurchasable.descendants.reject { |klass| klass.new().try(:qb_item_name).present? }

        if invalids.present?
          raise "expected acts_as_purchasable objects #{invalids.map(&:to_s).to_sentence} .qb_item_name() to be present."
        end
      end
    end

    # Include acts_as_addressable concern and allow any ActiveRecord object to call it
    initializer 'effective_qb_sync.active_record' do |app|
      ActiveSupport.on_load :active_record do
        Effective::OrderItem.class_eval do
          has_one :qb_order_item

          def qb_item_name
            qb_order_item.try(:name) || purchasable.try(:qb_item_name)
          end
        end
      end
    end

  end
end
