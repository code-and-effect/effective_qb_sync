module Effective
  class QbwcSupervisor
    QBXML = 'http://developer.intuit.com/'

    def authenticate(doc)
      username = doc.at_xpath('//qbxml:strUserName', 'qbxml' => QBXML).content
      password = doc.at_xpath('//qbxml:strPassword', 'qbxml' => QBXML).content

      attempt do |m|
        return [m.ticket.id.to_s, m.op_authenticate(username, password)]
      end
    end

    def sendRequestXML(doc)
      ticket = doc.at_xpath('//qbxml:ticket', 'qbxml' => QBXML).content
      strHCPResponse = doc.at_xpath('//qbxml:strHCPResponse', 'qbxml' => QBXML).content
      strCompanyFileName = doc.at_xpath('//qbxml:strCompanyFileName', 'qbxml' => QBXML).content
      qbXMLCountry = doc.at_xpath('//qbxml:qbXMLCountry', 'qbxml' => QBXML).content
      qbXMLMajorVers = doc.at_xpath('//qbxml:qbXMLMajorVers', 'qbxml' => QBXML).content
      qbXMLMinorVers = doc.at_xpath('//qbxml:qbXMLMinorVers', 'qbxml' => QBXML).content

      params = {
        ticket: ticket,
        hcpresponse: strHCPResponse,
        company: strCompanyFileName,
        country: qbXMLCountry,
        major_ver: qbXMLMajorVers,
        minor_ver: qbXMLMinorVers
      }

      attempt(ticket) do |m|
        return m.op_send_request_xml(params)
      end
    end

    def receiveResponseXML(doc)
      ticket = doc.at_xpath('//qbxml:ticket', 'qbxml' => QBXML).content
      response = doc.at_xpath('//qbxml:response', 'qbxml' => QBXML).content
      hresult = doc.at_xpath('//qbxml:hresult', 'qbxml' => QBXML).content
      message = doc.at_xpath('//qbxml:message', 'qbxml' => QBXML).content

      params = { ticket: ticket, response: response, hresult: hresult, message: message }

      attempt(ticket) do |m|
        return m.op_receive_response_xml(params)
      end
    end

    def connectionError(doc)
      ticket = doc.at_xpath('//qbxml:ticket', 'qbxml' => QBXML).content
      hresult = doc.at_xpath('//qbxml:hresult', 'qbxml' => QBXML).content
      message = doc.at_xpath('//qbxml:message', 'qbxml' => QBXML).content

      attempt(ticket) do |m|
        return m.op_connection_error(hresult, message)
      end
    end

    def closeConnection(doc)
      ticket = doc.at_xpath('//qbxml:ticket', 'qbxml' => QBXML).content

      attempt(ticket) do |m|
        return m.op_close_connection
      end
    end

    def getLastError(doc)
      ticket = doc.at_xpath('//qbxml:ticket', 'qbxml' => QBXML).content

      attempt(ticket) do |m|
        return m.op_last_error
      end
    end

    private

    # executes an operation on a machine safely, recording the failure if one occurs
    def attempt(ticket=nil)
      @qb_machine = QbMachine.new(ticket)
      begin
        return yield(@qb_machine)
      rescue
        @qb_machine.fail_unexpectedly($!)
      end
      false
    end

  end
end
