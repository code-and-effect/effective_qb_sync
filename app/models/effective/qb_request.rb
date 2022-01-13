module Effective
  class QbRequest < ActiveRecord::Base
    belongs_to :qb_ticket
    belongs_to :order

    # NOTE: Anything that is 'raise' here finds its way to qb_ticket#error

    # these are the states that signal a request is finished
    COMPLETED_STATES = ['Finished', 'Error']
    PROCESSING_STATES = ['Processing', 'CustomerQuery', 'CreateCustomer', 'OrderSync']

    effective_resource do
      state                 :string
      error                 :text

      request_type          :string

      request_qbxml         :text
      response_qbxml        :text

      request_sent_at       :datetime
      response_received_at  :datetime

      timestamps
    end

    validates :state, inclusion: { in: COMPLETED_STATES + PROCESSING_STATES }
    validates :qb_ticket, presence: true
    validates :order, presence: true

    # creates (does not persist) QbRequests for outstanding orders.  The caller may choose to
    # persist a request when that request starts communicating with QuickBooks
    def self.new_requests_for_unsynced_items(before: nil, order_ids: nil)
      finished_order_ids = Effective::QbRequest.where(state: 'Finished').pluck(:order_id)
      finished_orders = Effective::Order.purchased.includes(order_items: [:purchasable, :qb_order_item]).where.not(id: finished_order_ids)

      if before.present?
        raise('expected before to be a date') unless before.respond_to?(:strftime)
        finished_orders = finished_orders.where('purchased_at < ?', before)
      end

      if order_ids.present?
        finished_orders = finished_orders.where(id: order_ids)
      end

      finished_orders.map { |order| Effective::QbRequest.new(order: order) }
    end

    # Finds a QbRequest using response qb_xml.  If the response could not be parsed, or if there was no
    # corresponding record, nil will be returned.
    def self.find_using_response_qbxml(xml)
      return nil if xml.blank?
      element = Effective::QbRequest.find_first_response_having_a_request_id(xml)

      Effective::QbRequest.find_by_id(element.attr('requestID').to_i) if element
    end

    def has_more_work?
      PROCESSING_STATES.include?(state)
    end

    def state
      self[:state] || 'Processing'
    end

    # searches the XML and returns the first element having a requestID attribute. Since the
    # application does not bundle requests (yet), this should work.
    def self.find_first_response_having_a_request_id(xml)
      doc = Nokogiri::XML(xml)
      doc.xpath('//*[@requestID]')[0]
    end

    # parses the response XML and processes it.
    # returns true if the  responseXML indicates success, false otherwise
    def consume_response_xml(xml)
      update!(response_qbxml: xml)
      handle_response_xml(xml)
    end

    # handle response xml
    def handle_response_xml(xml)
      case state
      when 'CustomerQuery'
        handle_customer_query_response_xml(xml)
      when 'CreateCustomer'
        handle_create_customer_response_xml(xml)
      when 'OrderSync'
        handle_order_sync_response_xml(xml)
      else
        raise "Request in state #{state} was not expecting a response from the server"
      end
    end

    # outputs this request in qb_xml_format
    def to_qb_xml
      if state == 'Processing'
        # this is a dummy state -- we need to transition to the CustomerQuery state before any XML goes out.
        transition_state 'CustomerQuery'
      end

      xml = generate_request_xml
      wrap_qbxml_request(xml)
    end

    # generates the actual request XML that will be wrapped in a qbxml_request
    def generate_request_xml
      # safety checks to make sure we are linked in to the order
      raise 'Missing Order' unless order

      if order.order_items.any? { |order_item| order_item.qb_item_name.blank? }
        raise 'expected .qb_item_name() to be present on Effective::OrderItem'
      end

      case self.state
      when 'CustomerQuery'
        generate_customer_query_request_xml
      when 'OrderSync'
        generate_order_sync_request_xml
      when 'CreateCustomer'
        generate_create_customer_request_xml
      else
        raise "Unsupported state for generating request XML: #{state}"
      end
    end

    # transitions the request state and also outputs a log statement
    def transition_state(state)
      old_state = self.state
      update!(state: state)
      log "Transitioned request state from [#{old_state}] to [#{state}]"
    end

    def transition_to_finished
      # We create one QbOrderItem for each OrderItem here.
      order.order_items.each do |order_item|
        order_item.qb_item_name
        order_item.qb_order_item.save
      end

      transition_state('Finished')
    end

    # This should be private too, but test needs it
    def handle_create_customer_response_xml(xml)
      queryResponse = Nokogiri::XML(xml).xpath('//CustomerAddRs').first['statusCode']
      statusMessage = Nokogiri::XML(xml).xpath('//CustomerAddRs').first['statusMessage']

      if '0' == queryResponse
        # the customer was created
        log "Customer #{order.billing_name} created successfully"
        transition_state 'OrderSync'
      else
        raise "[Order ##{order.id}] Customer #{order.billing_name} could not be created in QuickBooks: #{statusMessage}"
      end

      true # indicate success
    end

    private

    # ensures that the total amount includes two decimal places
    def qb_amount(amount)
      raise 'amount should be an Integer representing the price in number of cents' unless amount.kind_of?(Integer)
      sprintf('%0.2f', (amount / 100.0))
    end

    def truncate(str, max_chars)
      str[(0...max_chars)] rescue ''
    end

    def generate_create_customer_request_xml
      Nokogiri::XML::Builder.new do |xml|
        xml.CustomerAddRq(requestID: id) {
          xml.CustomerAdd {
            xml.Name(truncate(order.billing_name, 41))
            xml.FirstName(truncate(order.billing_name.split(' ').first, 25))
            xml.LastName(truncate(order.billing_name.split(' ')[1..-1].join(' '), 25))
            xml.BillAddress {
              xml.Addr1(truncate(order.billing_name, 41))
              xml.Addr2(truncate(order.billing_address.address1, 41))
              xml.Addr3(truncate(order.billing_address.address2, 41))
              xml.City(truncate(order.billing_address.city, 31))
              xml.PostalCode(truncate(order.billing_address.postal_code, 13))
            }
            xml.Phone(truncate((order.user.try(:phone) || order.user.try(:cell_phone)), 21))
            xml.Email(truncate(order.user.try(:email), 1023))
          }
        }
      end.doc.root.to_s
    end

    def generate_customer_query_request_xml
      Nokogiri::XML::Builder.new do |xml|
        xml.CustomerQueryRq(requestID: id) {
          xml.FullName(truncate(order.billing_name, 209))
        }
      end.doc.root.to_s
    end

    def handle_customer_query_response_xml(xml)
      queryResponse = Nokogiri::XML(xml).xpath('//CustomerQueryRs').first['statusCode']

      if '500' == queryResponse # the user was not found.
        log "Customer #{order.billing_name} was not found"
        transition_state 'CreateCustomer'
      else # the user was found
        log "Customer #{order.billing_name} exists"
        transition_state 'OrderSync'
      end

      true # indicate success
    end

    # delegates logging to the ticket
    def log(message)
      qb_ticket.log("Request: #{message}") if qb_ticket
    end

    def generate_order_sync_request_xml
      Nokogiri::XML::Builder.new do |xml|
        xml.SalesReceiptAddRq(requestID: id) {
          xml.SalesReceiptAdd {
            xml.CustomerRef { xml.FullName(truncate(order.billing_name, 209)) }
            xml.TxnDate(order.purchased_at.strftime("%Y-%m-%d"))
            xml.Memo("Order ##{order.to_param} from website")
            xml.IsToBePrinted('false')
            xml.IsToBeEmailed('false')

            order.order_items.each do |order_item|
              xml.SalesReceiptLineAdd {
                xml.ItemRef { xml.FullName(order_item.qb_item_name) }
                xml.Desc(order_item.name)
                xml.Amount(qb_amount(order_item.subtotal))
              }
            end

            if EffectiveQbSync.quickbooks_tax_name.present?
              xml.SalesReceiptLineAdd {
                xml.ItemRef { xml.FullName(EffectiveQbSync.quickbooks_tax_name) }
                xml.Desc(EffectiveQbSync.quickbooks_tax_name)
                xml.Amount(qb_amount(order.tax))
              }
            end
          }
        }
      end.doc.root.to_s
    end

    def handle_order_sync_response_xml(xml)
      queryResponse = Nokogiri::XML(xml).xpath('//SalesReceiptAddRs').first['statusCode']
      statusMessage = Nokogiri::XML(xml).xpath('//SalesReceiptAddRs').first['statusMessage']

      if '0' == queryResponse
        log "Order #{order.to_param} successfully syncronized"
        transition_to_finished
      elsif '3180' == queryResponse
        log "Order #{order.to_param} was not recorded by quickbooks because it was an empty transaction"
        transition_to_finished
      else
        raise "[Order ##{order.to_param}] could not be synchronized with QuickBooks: #{statusMessage}"
      end

      true # indicate success
    end

    # Simple wrapping helper

    def wrap_qbxml_request(body)
      '<?xml version="1.0" ?><?qbxml version="6.0" ?><QBXML><QBXMLMsgsRq onError="continueOnError">' + (body || '') + '</QBXMLMsgsRq></QBXML>'
    end
  end
end
