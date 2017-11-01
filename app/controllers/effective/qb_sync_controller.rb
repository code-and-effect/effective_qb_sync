module Effective
  class QbSyncController < ApplicationController
    skip_authorization_check if defined?(CanCan)
    respond_to?(:skip_before_action) ? skip_before_action(:verify_authenticity_token) : skip_before_filter(:verify_authenticity_token)

    def api
      # respond successfully to a GET which some versions of the Web Connector send to verify the url
      (render(nothing: true) and return) if request.get?

      # Examine raw post and determine which API call to process
      doc = Nokogiri::XML(request.raw_post)
      @qbwcSupervisor = QbwcSupervisor.new

      api_verb = (doc.at_xpath('//soap:Body').children.first.node_name rescue '')

      case api_verb
      when 'serverVersion'
        @version = '1.0'
      when 'clientVersion'
        @version = nil
      when 'authenticate'
        @token, @message = @qbwcSupervisor.authenticate(doc)
      when 'sendRequestXML'
        @message = @qbwcSupervisor.sendRequestXML(doc)
      when 'receiveResponseXML'
        @message = @qbwcSupervisor.receiveResponseXML(doc)
      when 'getLastError'
        @message = @qbwcSupervisor.getLastError(doc)
      when 'connectionError'
        @message = @qbwcSupervisor.connectionError(doc)
      when 'closeConnection'
        @message = @qbwcSupervisor.closeConnection(doc)
      else
        ''
      end

      render(template: "/effective/qb_sync/#{api_verb}.erb", layout: false, content_type: 'text/xml')
    end
  end
end
