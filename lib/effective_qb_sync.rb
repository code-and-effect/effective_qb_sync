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

  mattr_accessor :quickbooks_username
  mattr_accessor :quickbooks_password
  mattr_accessor :quickbooks_tax_name

  mattr_accessor :error_email

  mattr_accessor :layout
  mattr_accessor :admin_simple_form_options

  def self.setup
    yield self
  end

  def self.authorized?(controller, action, resource)
    @_exceptions ||= [Effective::AccessDenied, (CanCan::AccessDenied if defined?(CanCan)), (Pundit::NotAuthorizedError if defined?(Pundit))].compact

    return !!authorization_method unless authorization_method.respond_to?(:call)
    controller = controller.controller if controller.respond_to?(:controller)

    begin
      !!(controller || self).instance_exec((controller || self), action, resource, &authorization_method)
    rescue *@_exceptions
      false
    end
  end

  def self.authorize!(controller, action, resource)
    raise Effective::AccessDenied.new('Access Denied', action, resource) unless authorized?(controller, action, resource)
  end

  def self.permitted_params
    [:note]
  end

  def self.skip_order!(order)
    raise 'expected an instance of Effective::Order' unless order.kind_of?(Effective::Order)

    return true if Effective::QbRequest.where(state: 'Finished', order: order).first.present?

    error = nil

    Effective::QbTicket.transaction do
      begin
        qb_ticket = Effective::QbTicket.new(state: 'Finished')
        qb_ticket.qb_logs.build(message: "#{order} set_qb_sync_finished")
        qb_ticket.save!

        qb_request = Effective::QbRequest.new(order: order)
        qb_request.qb_ticket = qb_ticket
        qb_request.transition_to_finished
      rescue => e
        error = e.message
        raise ::ActiveRecord::Rollback
      end
    end

    raise "Failed to skip quickbooks sync for #{order}: #{error}" if error

    true
  end

end
