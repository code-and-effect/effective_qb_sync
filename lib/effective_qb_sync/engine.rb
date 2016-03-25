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

  end
end
