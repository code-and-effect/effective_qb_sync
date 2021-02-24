module Effective
  class QbTicket < ActiveRecord::Base
    belongs_to :qb_request # the current request
    has_many :qb_requests
    has_many :orders, through: :qb_requests
    has_many :qb_logs

    STATES = ['Ready', 'Authenticated', 'Processing', 'Finished', 'ConnectionError', 'RequestError']

    effective_resource do
      username                  :string
      company_file_name         :string
      country                   :string

      qbxml_major_version       :string
      qbxml_minor_version       :string

      state                     :string, default: 'Ready'
      percent                   :integer

      hpc_response              :text
      connection_error_hresult  :text
      connection_error_message  :text
      last_error                :text

      timestamps
    end

    scope :deep, -> { includes(qb_requests: :order) }

    validates :state, inclusion: { in: STATES }

    def request_error!(error, atts={})
      self.error!(error, atts.reverse_merge({state: 'RequestError'}))
    end

    # This is the entry point for a standard error.
    def error!(error, atts={})
      Effective::OrdersMailer.order_error(
        order: qb_request.try(:order),
        error: error,
        to: EffectiveQbSync.error_email,
        subject: "Quickbooks failed to synchronize order ##{qb_request.try(:order).try(:to_param) || 'unknown'}",
        template: 'qb_sync_error'
      ).public_send(EffectiveOrders.mailer[:deliver_method])

      self.update_attributes!(atts.reverse_merge({last_error: error}))
    end

    # persists a new log message to this ticket
    def log(message)
      qb_logs.create(message: message, qb_ticket: self)
    end

  end
end
