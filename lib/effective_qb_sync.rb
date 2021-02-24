require 'effective_resources'
require 'effective_orders'
require 'effective_qb_sync/engine'
require 'effective_qb_sync/version'

module EffectiveQbSync

  def self.config_keys
    [
      :qb_requests_table_name, :qb_tickets_table_name, :qb_logs_table_name, :qb_order_items_table_name,
      :quickbooks_username, :quickbooks_password, :quickbooks_tax_name,
      :layout, :error_email
    ]
  end

  include EffectiveGem

  def self.permitted_params
    @permitted_params ||= [:note]
  end

  def self.skip_order!(order)
    raise 'expected an instance of Effective::Order' unless order.kind_of?(Effective::Order)

    return true if Effective::QbRequest.where(state: 'Finished', order: order).first.present?

    error = nil

    Effective::QbTicket.transaction do
      begin
        qb_ticket = Effective::QbTicket.new(state: 'Finished')
        qb_ticket.qb_logs.build(message: "Skip Order: #{order} skipped")
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

  def self.qwc_name
    (defined?(Tenant) ? Tenant.current.to_s : Rails.application.class.parent_name).downcase
  end

end
