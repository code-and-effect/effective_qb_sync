# a state controller that will help orchestrate the different state transitions in the dance with the QBWC
# Note that all methods that are prefixed with op_ should correspond directly to the QuickBooks web connector API.

module Effective
  class QbMachine

    attr_reader :ticket
    attr_reader :last_log_message

    # creates a new machine. this implicitly creates a new ticket unless one is supplied
    def initialize(ticket_id = nil)
      if ticket_id
        @ticket = Effective::QbTicket.find_by_id(ticket_id)
      else
        @ticket = Effective::QbTicket.create
      end
    end

    # authenticates a user for a particular session
    #
    # returns
    # - 'nvu' if the user login was invalid
    # - 'none' if the user login was valid but there is no work to be done
    # - '' if the user login was valid and there is work to be done
    def op_authenticate(username, password)
      return 'nvu' unless valid?

      unless authentication_valid?(username, password)
        log "Authentication failed for user #{username}"
        @ticket.update_attributes!(username: username, state: 'Finished', last_error: @last_log_message)
        return 'nvu' # not valid user
      end

      if has_work?
        log "Authentication successful. Reporting to QuickBooks that there is work to be done."
        @ticket.update_attributes!(username: username, state: 'Authenticated')
        ''  # "Any other string value = use this name for company file"
      else
        log "Authentication successful, but there is no work to be done"
        @ticket.update_attributes!(username: username, state: 'Finished')
        'none'
      end
    end

    # processes a message from the QBWC that corresponds to
    #
    # string sendRequestXML(ticket, hcpresponse, company, country, major_ver, minor_ver)
    #
    # in the QBWC api
    #
    # The params input should have members that correspond to the above parameters except for ticket, since
    # the ticket has already been used to build this state machine.
    #
    # Returns:
    # - '' if there is no work to be done
    # - Some qbXML if there is work to be done
    def op_send_request_xml(params)
      return '' unless valid?

      # update the ticket with the metadata sent at the first request for XML (i.e. if not blank)
      @ticket.update_attributes!(
        hpc_response: (@ticket.hpc_response || params[:hcpresponse]),
        company_file_name: (@ticket.company_file_name || params[:company]),
        country: (@ticket.country || params[:country]),
        qbxml_major_version: (@ticket.qbxml_major_version || params[:major_ver]),
        qbxml_minor_version: (@ticket.qbxml_minor_version || params[:minor_ver])
      )

      # only process when in the Authenticated or Processing states
      unless ['Authenticated', 'Processing'].include?(@ticket.state)
        @ticket.request_error!(@last_log_message)
        return ''
      end

      # either grab the current request or create a new one
      request = @ticket.qb_request
      unless request
        request = create_request
        @ticket.qb_request = request
      end

      # if we don't have a request, then we are done.
      unless request
        log "There is no more work to be done. Marking ticket state as finished"
        @ticket.update_attributes!(state: 'Finished')
        return ''
      end

      request.update_attributes!(qb_ticket: @ticket, request_sent_at: Time.zone.now)
      qb_xml = request.to_qb_xml
      request.update_attributes!(request_qbxml: qb_xml)

      # set the ticket into a Processing state
      @ticket.state = 'Processing'

      # save the changes.
      @ticket.save!

      log "Sending request [#{request.state}] XML to QuickBooks"

      qb_xml
    end

    # processes a message from the QBWC that corresponds to
    #
    # int receiveResponseXML(ticket, response, hresult, message)
    #
    # in the QBWC api
    #
    # The params input should have members that correspond to the above parameters except for ticket
    #
    # Returns:
    #    - negative value for error
    #    - postive value < 100 for percent complete (more work is to be done)
    #    - 100 if there is no more work
    def op_receive_response_xml(params)
      return -1 unless valid?

      # only process when in the 'Processing' state
      unless @ticket.state == 'Processing'
        log "Ticket state #{@ticket.state} not valid for processing responses"
        @ticket.request_error! @last_log_message
        return -1
      end

      responseXML = params[:response]
      log "Received response XML from QuickBooks"

      # handle a connection error
      unless params[:hresult].blank? and params[:message].blank?
        log "Connection error with QuickBooks: #{params[:hresult]} : #{params[:message]}"

        @ticket.request_error!(@last_log_message, connection_error_hresult: params[:hresult], connection_error_message: params[:message])

        # also update the request if it is able to be found
        request = find_outstanding_request(responseXML)
        request.update_attributes!(response_qbxml: responseXML, state: 'Error') if request

        return -1
      end

      # find the corresponding request
      request = find_outstanding_request(responseXML)

      unless request
        log "Received response back from QuickBooks but it did not correspond to any outstanding ticket request"
        @ticket.request_error! @last_log_message
        return -1
      end

      log "Found corresponding request [#{request.state}]"

      # safety check. we should always get a response back for the current request
      unless request == @ticket.qb_request
        log "Received response from QuickBooks but it references a request other than the current request"
        @ticket.request_error! @last_log_message
        return -1
      end

      # process the response XML now
      unless request.consume_response_xml(responseXML)
        # this request for some reason did not succeeed. Update the request and the ticket
        log "Request [#{request.state}] could not process the QuickBooks response: #{request.error}"
        request.update_attributes!(response_qbxml: responseXML, state: 'Error')
        @ticket.error! @last_log_message
        return -1
      end

      # the request has processed the response XML. if it does not have any more work to do, then detach it

      if request.has_more_work?
        log "Request [#{request.state}] has more work to do on the next request"
      else
        # detach the current request
        @ticket.update_attributes!(qb_request: nil)
        log "Request [#{request.state}] has completed its work"
      end

      work_done = @ticket.qb_requests.size
      work_left = how_much_more_work
      work_left = work_left + 1 if @ticket.qb_request # if there is still a current request we need to add that to the work_left

      work_left == 0 ? 100 : (work_done * 100 / (work_done + work_left))
    end

    # processes a message from the QBWC that corresponds to
    #
    # string connectionError(string ticket, string hresult, string message)
    #
    # in the QBWC api, signfiying that the connection with QuickBooks was lost
    #
    # The params input should have members that correspond to the above parameters except for ticket
    #
    # Returns: 'done' to indicate that activity on this ticket should not be resumed
    def op_connection_error(hresult,message)
      if valid?
        @ticket.connection_error_hresult = hresult
        @ticket.connection_error_message = message
        @ticket.state = 'ConnectionError'
      end

      'done'
    end

    # processes a message from the QBWC that corresponds to
    #
    # string closeConnection(string ticket)
    #
    # in the QBWC api, signifying that this connection should be terminated.
    #
    # returns the connection closing result (e.g. 'OK')
    def op_close_connection
      return 'Close error: invalid ticket' unless valid?

      @ticket.update_attributes!(state: 'Finished') unless ['ConnectionError', 'RequestError'].include?(@ticket.state)
      log "Closed connection with QuickBooks"

      'OK'
    end

    # processes a message from the QBWC that corresponds to
    #
    # string getLastError(string ticket)
    #
    # in the QBWC api
    #
    # Returns: the last error recorded for that ticket
    def op_last_error
      return 'Invalid Ticket Id' unless valid?
      @ticket.last_error || ''
    end

    # returns true if this machine is a valid machine
    def valid?
      @ticket.present?
    end

    # logs a message to the ticket if it exists
    def log(message)
      @ticket.log(message) unless message.blank?
      # always save the last log message
      @last_log_message = message
    end

    # sets the ticket as failed and records the message
    def fail_unexpectedly(message)
      log "An unexpected error occurred: #{message}"
      @ticket.request_error! @last_log_message
    end

    protected

    # determines if this username and password is valid
    def authentication_valid?(username,password)
      (username == EffectiveQbSync.quickbooks_username) && (password == EffectiveQbSync.quickbooks_password)
    end

    # returns how much more work is to be done. If there is no more work to be done, it will return 0, else,
    # the number of requests that need to be processed.
    def how_much_more_work
      Effective::QbRequest.new_requests_for_unsynced_items.size
    end

    # returns true if there is work to be done
    def has_work?
      how_much_more_work > 0
    end

    # creates a new request object for a unit of work to be done. returns nil if no work can be found
    def create_request
      Effective::QbRequest.new_requests_for_unsynced_items.first
    end

    # returns a qb request that corresponds to the first element in the response with a requestID
    def find_outstanding_request(responseXML)
      Effective::QbRequest.find_using_response_qbxml(responseXML)
    end
  end
end
