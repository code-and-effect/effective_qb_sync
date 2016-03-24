require 'haml-rails'
require 'simple_form'
require 'effective_orders'
require 'effective_qb_sync/engine'
require 'effective_qb_sync/version'

module EffectiveQbSync
  # The following are all valid config keys
  mattr_accessor :qb_requests_table_name
  mattr_accessor :qb_tickets_table_name
  mattr_accessor :qb_logs_table_name
  mattr_accessor :qb_order_items_table_name

  mattr_accessor :authorization_method

  mattr_accessor :layout
  mattr_accessor :simple_form_options

  def self.setup
    yield self
  end

  def self.authorized?(controller, action, resource)
    if authorization_method.respond_to?(:call) || authorization_method.kind_of?(Symbol)
      raise Effective::AccessDenied.new() unless (controller || self).instance_exec(controller, action, resource, &authorization_method)
    end
    true
  end

  def self.permitted_params
    [
      :note
    ]
  end

end
