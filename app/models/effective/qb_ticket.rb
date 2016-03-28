module Effective
  class QbTicket < ActiveRecord::Base
    belongs_to :qb_request # the current request
    has_many :qb_requests
    has_many :qb_logs

    STATES = ['Ready', 'Authenticated', 'Processing', 'Finished', 'ConnectionError', 'RequestError']

    # structure do
    #   username                  :string
    #   company_file_name         :string
    #   country                   :string

    #   qbxml_major_version       :string
    #   qbxml_minor_version       :string

    #   state                     :string, :default => 'Ready', :validates => [:presence, :inclusion => { :in => STATES}]
    #   percent                   :integer, :default => 0

    #   hpc_response              :text
    #   connection_error_hresult  :text
    #   connection_error_message  :text
    #   last_error                :text

    #   site_id                   :integer    # ActsAsSiteSpecific

    #   timestamps
    # end

    validates :state, inclusion: { in: STATES }

    # attr_accessible :username, :company_file_name, :country, :qbxml_major_version,
    #   :qbxml_minor_version, :state, :percent, :hpc_response, :connection_error_hresult,
    #   :connection_error_message, :last_error, :qb_request

    # This is something busted with the communication between the website and Quickbooks itself
    # In practice, we have not been seeing these errors at all
    def request_error!(error, atts={})
      self.error!(error, atts.reverse_merge({state: 'RequestError'}))
    end

    # This is the entry point for a standard error.
    def error!(error, atts={})
      binding.pry
      Effective::OrdersMailer.order_error(
        order: qb_request.order,
        to: EffectiveQbSync.error_email,
        subject: "Quickbooks failed to synchronize order ##{qb_request.order.to_param}",
        template: 'qb_sync_error'
      ).try(:deliver_now).try(:deliver)

      self.update_attributes!(atts.reverse_merge({last_error: error}))
    end

    # persists a new log message to this ticket
    def log(message)
      qb_logs.create(message: message, qb_ticket: self)
    end
  end
end
