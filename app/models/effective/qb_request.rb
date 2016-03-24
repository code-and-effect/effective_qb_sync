module Effective
  class QbRequest < ActiveRecord::Base
    belongs_to :qb_ticket
    belongs_to :order

    # NOTE:
    # Anything that is 'raise' here finds its way to qb_ticket#error!
    # If we pass the raise string with "[Order ##{order.id}]"
    # Our email handler will pick out the order id and assign the order accordingly

    # these are the states that signal a request is finished
    COMPLETED_STATES = ['Finished', 'Error']
    PROCESSING_STATES = ['Processing', 'CustomerQuery', 'CreateCustomer', 'OrderSync']

    # structure do
    #   request_qbxml         :text
    #   response_qbxml        :text

    #   request_sent_at       :datetime
    #   response_received_at  :datetime

    #   state                 :string, :validates => [:presence, :inclusion => { :in => COMPLETED_STATES + PROCESSING_STATES}]
    #   error                 :text

    #   site_id               :integer    # ActsAsSiteSpecific

    #   timestamps
    # end

    # attr_accessible :request_qbxml, :response_qbxml, :request_sent_at, :response_received_at,
    #   :state, :error, :order, :qb_ticket, :order_id

    validates :state, inclusion: { in: COMPLETED_STATES + PROCESSING_STATES }
    validates :qb_ticket, presence: true
    validates :order, presence: true

    # creates (does not persist) QbRequests for outstanding orders.  The caller may choose to
    # persist a request when that request starts communicating with QuickBooks
    def self.new_requests_for_unsynced_items
      Order.unscoped.includes(:order_items).where(purchasable_state: Purchasable::SUCCESS).order(:id).all.to_a
        .select { |order| order.qb_sync_status != Purchasable::QBSUCCESS }
        .select { |order| order.order_items.all? { |order_item| order_item.quickbooks_item_name.present? } }
        .map { |order| QbRequest.new(order: order) }
    end

    # Finds a QbRequest using response qb_xml.  If the response could not be parsed, or if there was no
    # corresponding record, nil will be returned.
    def self.find_using_response_qbxml(xml)
      return nil if xml.blank?
      element = QbRequest.find_first_response_having_a_request_id(xml)

      QbRequest.find_by_id(element.attr('requestID').to_i) if element
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
      update_attribute :response_qbxml, xml
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

      if order.order_items.any? { |order_item| order_item.quickbooks_item_name.blank? }
        raise 'Missing QuickBooks Item Name on Order Item'
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
      update_attributes!(state: state)
      log "Transitioned request state from [#{old_state}] to [#{state}]"
    end

    private

    # generates the full name of the user who made the order
    def order_full_name
      "#{order.qb_billing_first_name} #{order.qb_billing_last_name}".strip
    end

    # generates the total price of the order item
    def order_total_amount
      order.sub_total
    end

    # generates the total tax for the order
    def order_tax_amount
      order.total_tax
    end

    # ensures that the total amount includes two decimal places
    def format_qbxml_amount(amount)
      sprintf('%0.2f',amount)
    end

    def truncate(str, max_chars)
      str[(0...max_chars)] rescue ''
    end

    def generate_create_customer_request_xml
      Nokogiri::XML::Builder.new do |xml|
        xml.CustomerAddRq(:requestID => self.id) {
          xml.CustomerAdd {
            xml.Name(truncate(order_full_name, 41))
            xml.FirstName(truncate(order.qb_billing_first_name, 25))
            xml.LastName(truncate(order.qb_billing_last_name, 25))
            xml.BillAddress {
              xml.Addr1(truncate(order_full_name, 41))
              xml.Addr2(truncate(order.qb_billing_address1, 41))
              xml.Addr3(truncate(order.qb_billing_address2, 41))
              xml.City(truncate(order.qb_billing_city, 31))
              xml.PostalCode(truncate(order.qb_billing_pc, 13))
            }
            xml.Phone(truncate(order.qb_billing_phone,21))
            xml.Email(truncate(order.qb_billing_email,1023))
          }
        }
      end.doc.root.to_s
    end

    def handle_create_customer_response_xml(xml)
      queryResponse = Nokogiri::XML(xml).xpath('//CustomerAddRs').first['statusCode']
      statusMessage = Nokogiri::XML(xml).xpath('//CustomerAddRs').first['statusMessage']

      if '0' == queryResponse
        # the customer was created
        log "Customer #{order_full_name} created successfully"
        transition_state 'OrderSync'
      else
        raise "[Order ##{order.id}] Customer #{order_full_name} could not be created in QuickBooks: #{statusMessage}"
      end

      true # indicate success
    end

    def generate_customer_query_request_xml
      Nokogiri::XML::Builder.new do |xml|
        xml.CustomerQueryRq(requestID: id) {
          xml.FullName(truncate(order_full_name,209))
        }
      end.doc.root.to_s
    end

    def handle_customer_query_response_xml(xml)
      queryResponse = Nokogiri::XML(xml).xpath('//CustomerQueryRs').first['statusCode']

      if "500" == queryResponse # the user was not found.
        log "Customer #{order_full_name} was not found"
        transition_state 'CreateCustomer'
      else # the user was found
        log "Customer #{order_full_name} exists"
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
            xml.CustomerRef { xml.FullName(truncate(order_full_name,209)) }
            xml.TxnDate(order.created_at.strftime("%Y-%m-%d"))
            xml.Memo("Order ##{order.id} from website")
            xml.IsToBePrinted('false')
            xml.IsToBeEmailed('false')

            order.order_items.each do |order_item|
              xml.SalesReceiptLineAdd {
                xml.ItemRef { xml.FullName(order_item.quickbooks_item_name) }
                xml.Desc(order_item.name)
                xml.Amount(sprintf('%0.2f',order_item.sub_total))
              }
            end

            xml.SalesReceiptLineAdd {
              if QBSETTINGS[:tax_item_name].present?
                xml.ItemRef { xml.FullName(QBSETTINGS[:tax_item_name]) }
                xml.Desc(QBSETTINGS[:tax_item_name])
                xml.Amount(sprintf('%0.2f',order.total_tax))
              end
            }
          }
        }
      end.doc.root.to_s
    end

    # Problems here perhaps
    def handle_order_sync_response_xml(xml)
      queryResponse = Nokogiri::XML(xml).xpath('//SalesReceiptAddRs').first['statusCode']
      statusMessage = Nokogiri::XML(xml).xpath('//SalesReceiptAddRs').first['statusMessage']

      if '0' == queryResponse
        log "Order #{order.id} successfully syncronized"
        order.update_attribute(:qb_sync_status, Purchasable::QBSUCCESS)
        transition_state 'Finished'
      elsif '3180' == queryResponse
        log "Order #{order.id} was not recorded by quickbooks because it was an empty transaction"
        order.update_attribute(:qb_sync_status, Purchasable::QBSUCCESS)
        transition_state 'Finished'
      else
        order.update_attribute(:qb_sync_status, Purchasable::QBFAILED)
        raise "[Order ##{order.id}] could not be synchronized with QuickBooks: #{statusMessage}"
      end

      true # indicate success
    end

    # Simple wrapping helper

    def wrap_qbxml_request(body)
      '<?xml version="1.0" ?><?qbxml version="6.0" ?><QBXML><QBXMLMsgsRq onError="continueOnError">' + (body || '') + '</QBXMLMsgsRq></QBXML>'
    end
  end
end
