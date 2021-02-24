module EffectiveQbSync
  class Engine < ::Rails::Engine
    engine_name 'effective_qb_sync'

    # Set up our default configuration options.
    initializer "effective_qb_sync.defaults", before: :load_config_initializers do |app|
      eval File.read("#{config.root}/config/effective_qb_sync.rb")
    end

  end
end
