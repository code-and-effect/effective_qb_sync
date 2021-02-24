module EffectiveQbSync
  class Engine < ::Rails::Engine
    engine_name 'effective_qb_sync'

    # Set up our default configuration options.
    initializer "effective_qb_sync.defaults", before: :load_config_initializers do |app|
      eval File.read("#{config.root}/config/effective_qb_sync.rb")
    end

    # Include acts_as_addressable concern and allow any ActiveRecord object to call it
    initializer 'effective_qb_sync.active_record' do |app|
      Rails.application.config.to_prepare do
        ActiveSupport.on_load :active_record do
          Effective::OrderItem.class_eval do
            has_one :qb_order_item

            # first or build
            def qb_item_name
              (qb_order_item || build_qb_order_item(name: purchasable.qb_item_name)).name
            end
          end
        end
      end
    end

  end
end
