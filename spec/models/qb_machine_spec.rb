require 'spec_helper'

describe Effective::QbMachine, "Basic Functionality" do

  before :each do
  end

  it "should be valid" do
    @qb_machine = Effective::QbMachine.new
    @qb_machine.should be_valid
  end

  it "should initialize a ticket in the Ready state when constructed" do
    @qb_machine = Effective::QbMachine.new
    @qb_machine.ticket.state.should eql('Ready')
  end

  it "should not create a ticket if the ticket could not be found" do
    @qb_machine = Effective::QbMachine.new(1976)
    @qb_machine.ticket.should be_nil
  end

  it "should not be valid if a ticket could not be found" do
    @qb_machine = Effective::QbMachine.new(1976)
    @qb_machine.should_not be_valid
  end

  it "should be valid upon finding an existing ticket" do
    @qb_ticket = Effective::QbTicket.create
    @qb_machine = Effective::QbMachine.new(@qb_ticket.id)
    @qb_machine.should be_valid
  end

  it "should delegate logging functionality to the ticket" do
    @qb_machine = Effective::QbMachine.new
    Effective::QbLog.any_instance.should_receive(:create)
    @qb_machine.log('Message')
  end

  it "should not record an empty log message" do
    @qb_machine = Effective::QbMachine.new
    Effective::QbLog.should_not_receive(:create)
    @qb_machine.log('')
  end

  it "should record the last log message in an instance member" do
    @qb_machine = Effective::QbMachine.new
    message = 'A message'
    @qb_machine.log(message)
    @qb_machine.last_log_message.should eql(message)
  end

end

describe Effective::QbMachine, "Authentication Behavior (op_authenticate)" do

  before :each do
    @qb_machine = Effective::QbMachine.new
  end

  it "should be valid" do
    @qb_machine.should be_valid
  end

  it "should authenticate successfully with the QB_ADMIN_PASSWORD password" do
    result = @qb_machine.op_authenticate('username', QBSETTINGS[:quickbooks_user_password])
    result.should_not eql('nvu')
  end

  it "should not authenticate successfully with a different password" do
    result = @qb_machine.op_authenticate('username', '12345')
    result.should eql('nvu')
  end

  it "should transition ticket to Finished state upon unsuccessful authentication" do
    @qb_machine.should_receive(:authentication_valid?).and_return(false)
    @qb_machine.op_authenticate('username','incorrectpassword')
    @qb_machine.ticket.state.should eql('Finished')
  end

  it "should populate last_error with authentication failure message upon unsuccessful authentication" do
    @qb_machine.should_receive(:authentication_valid?).and_return(false)
    @qb_machine.op_authenticate('username','incorrectpassword')
    @qb_machine.ticket.last_error.should_not be_blank
  end

  it "should keep ticket in the Authenticated state after authentication if there is work to be done" do
    @qb_machine.should_receive(:authentication_valid?).and_return(true)
    @qb_machine.should_receive(:has_work?).and_return(true)

    @qb_machine.op_authenticate('username','password')
    @qb_machine.ticket.state.should eql('Authenticated')
  end

  it "should transition ticket to Finished state if there is not any work to be done" do
    @qb_machine.should_receive(:authentication_valid?).and_return(true)
    @qb_machine.should_receive(:has_work?).and_return(false)

    @qb_machine.op_authenticate('username','password')
    @qb_machine.ticket.state.should eql('Finished')
  end

  it "should return 'nvu' from op_authentication if the user login is invalid" do
    @qb_machine.should_receive(:authentication_valid?).and_return(false)
    result = @qb_machine.op_authenticate('username','incorrectpassword')
    result.should eql('nvu')
  end

  it "should return 'none' from op_authentication if the login is valid but no work to be done" do
    @qb_machine.should_receive(:authentication_valid?).and_return(true)
    @qb_machine.should_receive(:has_work?).and_return(false)
    result = @qb_machine.op_authenticate('username','password')
    result.should eql('none')
  end

  it "should return '' from op_authentication if the login is valid and there is work to be done" do
    @qb_machine.should_receive(:authentication_valid?).and_return(true)
    @qb_machine.should_receive(:has_work?).and_return(true)
    result = @qb_machine.op_authenticate('username','password')
    result.should eql('')
  end

  it "should record the ticket username field on successful authentication" do
    @qb_machine.should_receive(:authentication_valid?).and_return(true)
    username = 'successful user'
    @qb_machine.op_authenticate(username,'password')
    @qb_machine.ticket.username.should eql(username)
  end

  it "should record the ticket username field on unsuccessful authentication" do
    @qb_machine.should_receive(:authentication_valid?).and_return(false)
    username = 'unsuccessful user'
    @qb_machine.op_authenticate(username,'password')
    @qb_machine.ticket.username.should eql(username)
  end

  it "should not have a current request after successful authentication" do
    @qb_machine.should_receive(:authentication_valid?).and_return(true)
    @qb_machine.op_authenticate('username','password')
    @qb_machine.ticket.qb_request.should be_nil
  end

end

describe Effective::QbMachine, "Sending Request qbXML to QuickBooks (op_send_request_xml)" do

  before :each do
    @qb_machine = Effective::QbMachine.new
    @qb_machine.stub!(:authentication_valid?).and_return(true)
    @qb_machine.stub!(:has_work?).and_return(true)
    @qb_machine.op_authenticate('username','password')

    # Here the machine should be in the Authenticated State

    # - signature: string sendRequestXML(ticket, hcpresponse, company, country, major_ver, minor_ver)

    @hcpresponse = 'some response'
    @company = 'some company'
    @country = 'US'
    @major_ver = '8'
    @minor_ver = '2'

    @default_request_params = {
      :hcpresponse=>@hcpresponse,
      :company=>@company,
      :country=>@country,
      :major_ver=>@major_ver,
      :minor_ver=>@minor_ver
    }

    # the default order item we'll be using when mocking out QbMachine#create_request
    @order = Order.new
    @order_item = OrderItem.new(order: @order)

    # the default request we'll use when mocking out QbMachine#create_request
    @qb_request = Effective::QbRequest.new(:request_type=>'OrderItemSynchronization', :order_item=>@order_item, :order=>@order)
    @qb_request.stub!(:to_qb_xml).and_return('<qbXML></qbXML>') # we are not worried about qbXML correctness here

    @qb_machine.stub!(:create_request).and_return(@qb_request)
  end

  it "should populate ticket fields [hpc_response,company_file_name, etc] when non-blank" do
    @qb_machine.stub!(:has_work?).and_return(false)
    @qb_machine.op_send_request_xml(@default_request_params)

    @qb_machine.ticket.hpc_response.should eql(@hcpresponse)
    @qb_machine.ticket.company_file_name.should eql(@company)
    @qb_machine.ticket.country.should eql(@country)
    @qb_machine.ticket.qbxml_major_version.should eql(@major_ver)
    @qb_machine.ticket.qbxml_minor_version.should eql(@minor_ver)
  end

  it "should not overwrite ticket fields [hpc_response,company_file_name, etc] on subsequent request XML calls if those fields are blank" do
    @qb_machine.stub!(:has_work?).and_return(false)
    @qb_machine.op_send_request_xml(@default_request_params)

    @qb_machine.ticket.hpc_response.should eql(@hcpresponse)
    @qb_machine.ticket.company_file_name.should eql(@company)
    @qb_machine.ticket.country.should eql(@country)
    @qb_machine.ticket.qbxml_major_version.should eql(@major_ver)

    # now blank out the fields and call again

    @qb_machine.op_send_request_xml(@default_request_params.except(:hcpresponse,:company,:country,:major_ver,:minor_ver))

    @qb_machine.ticket.hpc_response.should eql(@hcpresponse)
    @qb_machine.ticket.company_file_name.should eql(@company)
    @qb_machine.ticket.country.should eql(@country)
    @qb_machine.ticket.qbxml_major_version.should eql(@major_ver)
  end

  it "should transition ticket to the RequestError state if the ticket is not in the Authenticated or Processing states" do
    @qb_machine.ticket.update_attributes! :state=>'Finished'
    @qb_machine.op_send_request_xml(@default_request_params)
    @qb_machine.ticket.state.should eql('RequestError')
  end

  it "should return a non-empty string if there is work to be done" do
    @qb_machine.stub!(:has_work?).and_return(true)

    result = @qb_machine.op_send_request_xml(@default_request_params)
    result.should_not be_blank
  end

  it "should create a QbRequest model and attach to the ticket for the corresponding qbXML" do
    @qb_machine.stub!(:has_work?).and_return(true)
    @qb_machine.op_send_request_xml(@default_request_params)
    @qb_request.id.should_not be_nil
    @qb_machine.ticket.qb_requests.should_not be_empty
  end

  it "should only create one QbRequest model when sending request xml" do
    @qb_machine.stub!(:has_work?).and_return(true)
    @qb_machine.op_send_request_xml(@default_request_params)
    @qb_machine.ticket.qb_requests.size.should eql(1)
  end

  it "should put the QbRequest model into the Processing state after sending work to QuickBooks" do
    @qb_machine.stub!(:has_work?).and_return(true)
    @qb_machine.op_send_request_xml(@default_request_params)
    request = @qb_machine.ticket.qb_requests.first
    request.state.should eql('Processing')
  end

  it "should set the QbTicket model into the Processing state after sending work to QuickBooks" do
    @qb_machine.stub!(:has_work?).and_return(true)
    @qb_machine.op_send_request_xml(@default_request_params)
    @qb_machine.ticket.state.should eql('Processing')
  end

  it "should store the qbXML into the QbRequest model" do
    @qb_machine.stub!(:has_work?).and_return(true)
    qbXML = @qb_machine.op_send_request_xml(@default_request_params)
    request = @qb_machine.ticket.qb_requests.first
    request.request_qbxml.should eql(qbXML)
  end

  it "should set the request_sent_at field in the QbRequest model" do
    @qb_machine.stub!(:has_work?).and_return(true)
    qbXML = @qb_machine.op_send_request_xml(@default_request_params)
    request = @qb_machine.ticket.qb_requests.first
    request.request_sent_at.should_not be_nil
  end

  it "should set the current request in the ticket" do
    @qb_machine.stub!(:has_work?).and_return(true)
    @qb_machine.op_send_request_xml(@default_request_params)
    @qb_machine.ticket.qb_request.should_not be_nil
    @qb_machine.ticket.qb_request.should eql(@qb_request)
  end

end


describe Effective::QbMachine, "Receiving response qbXML from QuickBooks (op_receive_response_xml)" do

  before :each do
    @qb_machine = Effective::QbMachine.new

    # fake out authentication to pass successfully
    @qb_machine.stub!(:authentication_valid?).and_return(true)
    @qb_machine.stub!(:has_work?).and_return(true)
    @qb_machine.op_authenticate('username','password')

    @default_request_params = {
      :hcpresponse=>'some response',
      :company=>'some company',
      :country=>'US',
      :major_ver=>'8',
      :minor_ver=>'2'
    }

    # the default order item we'll be using when mocking out QbMachine#create_request
    @order = Order.new
    @order_item = OrderItem.new
    @qb_request = Effective::QbRequest.new(:id=>1, :request_type=>'OrderItemSynchronization', :order_item=>@order_item, :order=>@order, :state=>'CustomerQuery')
    @qb_request_xml = '<qbXML></qbXML>'
    @qb_request.stub!(:to_qb_xml).and_return(@qb_request_xml) # we are not worried about qbXML correctness here

    # set the machine to send some request qbXML to quickbooks
    @qb_machine.stub!(:has_work?).and_return(true)
    @qb_machine.stub!(:create_request).and_return(@qb_request)
    @qb_machine.op_send_request_xml(@default_request_params)

    @qb_response_xml = '<qbXML><QBXMLMsgsRs><AccountQueryRs requestID="1" statusCode="0"></AccountQueryRs></QBXMLMsgsRs></qbXML>'
    # int receiveResponseXML(ticket, response, hresult, message)
    @default_response_params = {
      :response=>@qb_response_xml,
      :hresult=>'',
      :message=>''
    }

    # by default always report no more work to be done
    @qb_machine.stub!(:how_much_more_work).and_return(0)
  end

  it "should return -1 to indicate error if the ticket state is not in the Processing state" do
    @qb_machine.ticket.update_attributes! :state=>'Finished'
    result = @qb_machine.op_receive_response_xml(@default_response_params)
    result.should eql(-1)
  end

  it "should set the ticket state to RequestError if the ticket state was previously Authenticated" do
    @qb_machine.ticket.update_attributes! :state=>'Authenticated'
    @qb_machine.op_receive_response_xml(@default_response_params)
    @qb_machine.ticket.state.should eql('RequestError')
  end

  it "should set the ticket state to RequestError if the ticket state was previously Ready" do
    @qb_machine.ticket.update_attributes! :state=>'Ready'
    @qb_machine.op_receive_response_xml(@default_response_params)
    @qb_machine.ticket.state.should eql('RequestError')
  end

  it "should set the ticket state to RequestError if the ticket state was previously Finished" do
    @qb_machine.ticket.update_attributes! :state=>'Finished'
    @qb_machine.op_receive_response_xml(@default_response_params)
    @qb_machine.ticket.state.should eql('RequestError')
  end

  it "should send the ticket into a RequestError state if there is no matching Processing request" do
    @qb_machine.stub!(:find_outstanding_request).and_return(nil)
    @qb_machine.op_receive_response_xml(@default_response_params)
    @qb_machine.ticket.state.should eql('RequestError')
  end

  it "should set the request state to Error if the response indicates error" do
    @qb_machine.stub!(:find_outstanding_request).and_return(@qb_request)
    @qb_request.stub!(:consume_response_xml).and_return(false)
    @qb_machine.op_receive_response_xml(@default_response_params)
    @qb_request.state.should eql('Error')
  end

  it "should set the ticket last_error field if the response indicates error" do
    @qb_machine.stub!(:find_outstanding_request).and_return(@qb_request)
    @qb_request.stub!(:consume_response_xml).and_return(false)
    @qb_machine.op_receive_response_xml(@default_response_params)
    @qb_machine.ticket.last_error.should_not be_blank
  end

  it "should set the request state to Error if there was a connection error with QuickBooks" do
    @qb_machine.stub!(:find_outstanding_request).and_return(@qb_request)
    @qb_request.stub!(:consume_response_xml).and_return(true)

    @params = @default_response_params
    @params[:hresult] = 'error_result'
    @params[:message] = 'error_message'

    @qb_machine.op_receive_response_xml(@params)
    @qb_request.state.should eql('Error')
  end

  it "should set the set the ticket state to RequestError if there was a connection error with QuickBooks" do
    @qb_machine.stub!(:find_outstanding_request).and_return(@qb_request)
    @qb_request.stub!(:consume_response_xml).and_return(true)

    @params = @default_response_params
    @params[:hresult] = 'error_result'
    @params[:message] = 'error_message'

    @qb_machine.op_receive_response_xml(@params)
    @qb_machine.ticket.state.should eql('RequestError')
  end

  it "should set the ticket last_error field if there was a connection error with QuickBooks" do
    @qb_machine.stub!(:find_outstanding_request).and_return(@qb_request)
    @qb_request.stub!(:consume_response_xml).and_return(true)

    @params = @default_response_params
    @params[:hresult] = 'error_result'
    @params[:message] = 'error_message'

    @qb_machine.op_receive_response_xml(@params)
    @qb_machine.ticket.last_error.should_not be_blank
  end

  it "should return -1 if there was a connection error with QuickBooks" do
    @qb_machine.stub!(:find_outstanding_request).and_return(@qb_request)
    @qb_request.stub!(:consume_response_xml).and_return(true)

    @params = @default_response_params
    @params[:hresult] = 'error_result'
    @params[:message] = 'error_message'

    response = @qb_machine.op_receive_response_xml(@params)
    response.should eql(-1)
  end

  it "should set the ticket connection_error_hresult and connection_error_message fields upon a connection error with QuickBooks" do
    @qb_machine.stub!(:find_outstanding_request).and_return(@qb_request)
    @qb_request.stub!(:consume_response_xml).and_return(true)

    @params = @default_response_params
    @params[:hresult] = 'error_result'
    @params[:message] = 'error_message'

    @qb_machine.op_receive_response_xml(@params)
    @qb_machine.ticket.connection_error_hresult.should_not be_blank
    @qb_machine.ticket.connection_error_message.should_not be_blank
  end

  it "should return a number between 1 and 99, inclusive, if there is more work to be done" do
    @qb_machine.stub!(:find_outstanding_request).and_return(@qb_request)
    @qb_request.stub!(:consume_response_xml).and_return(true)
    @qb_machine.stub!(:how_much_more_work).and_return(15)
    result = @qb_machine.op_receive_response_xml(@default_response_params)
    result.should be > 0
    result.should be < 100
  end

  it "should set the response_qbxml field in the QbRequest model" do
    @qb_machine.stub!(:find_outstanding_request).and_return(@qb_request)
    @qb_request.stub!(:handle_response_xml).and_return(true)
    @qb_machine.op_receive_response_xml(@default_response_params)
    @qb_request.response_qbxml.should eql(@qb_response_xml)
  end

  it "should release the ticket's current request if that request signals that it is done" do
    @qb_machine.stub!(:find_outstanding_request).and_return(@qb_request)
    @qb_request.stub!(:consume_response_xml).and_return {
      @qb_request.state = 'Finished'
      # return true to indicate success
      true
    }
    @qb_machine.op_receive_response_xml(@default_response_params)

    # it should be nil because the request is in a finished state
    @qb_machine.ticket.qb_request.should be_nil
  end

end


describe Effective::QbMachine, "Receiving notification that the QBWC cannot connect to QuickBooks (op_connection_error)" do

  before :each do
    @qb_machine = Effective::QbMachine.new
    @hresult = 'hresult'
    @message = 'message'
    @result = @qb_machine.op_connection_error(@hresult,@message)
  end

  it "should always return 'done'" do
    @result.should eql('done')
  end

  it "should store the hresult and message in the ticket" do
    @qb_machine.ticket.connection_error_hresult.should eql(@hresult)
    @qb_machine.ticket.connection_error_message.should eql(@message)
  end

  it "should set the ticket state to ConnectionError" do
    @qb_machine.ticket.state.should eql('ConnectionError')
  end

end

describe Effective::QbMachine, "Receiving a request from the QBWC to provide the last error message (op_last_error)" do

  before :each do
    @qb_machine = Effective::QbMachine.new
    @last_error = 'What?'
    @qb_machine.ticket.update_attributes! :last_error=>@last_error
  end

  it "should return the last error" do
    error = @qb_machine.op_last_error
  end

  it "should return '' if the last error is blank" do
    @qb_machine.ticket.update_attributes! :last_error=>nil
    error = @qb_machine.op_last_error
    error.should eql('')

    @qb_machine.ticket.update_attributes! :last_error=>''
    error = @qb_machine.op_last_error
    error.should eql('')
  end

end

describe Effective::QbMachine, "Closing the connection (op_close_connection)" do

  before :each do
    @qb_machine = Effective::QbMachine.new
  end

  it "should not transition ticket state on close_connection if state is Finished" do
    @qb_machine.ticket.update_attributes! :state=>'Finished'
    @qb_machine.op_close_connection
    @qb_machine.ticket.state.should eql('Finished')
  end

  it "should not transition ticket state on close_connection if state is ConnectionError" do
    @qb_machine.ticket.update_attributes! :state=>'ConnectionError'
    @qb_machine.op_close_connection
    @qb_machine.ticket.state.should eql('ConnectionError')
  end

  it "should not transition ticket state on close_connection if state is RequestError" do
    @qb_machine.ticket.update_attributes! :state=>'RequestError'
    @qb_machine.op_close_connection
    @qb_machine.ticket.state.should eql('RequestError')
  end

  it "should transition ticket state to Finished if state is Ready " do
    @qb_machine.ticket.update_attributes! :state=>'Ready'
    @qb_machine.op_close_connection
    @qb_machine.ticket.state.should eql('Finished')
  end

  it "should transition ticket state to Finished if state is Authenticated" do
    @qb_machine.ticket.update_attributes! :state=>'Authenticated'
    @qb_machine.op_close_connection
    @qb_machine.ticket.state.should eql('Finished')
  end

  it "should transition ticket state to Finished if state is Processing" do
    @qb_machine.ticket.update_attributes! :state=>'Processing'
    @qb_machine.op_close_connection
    @qb_machine.ticket.state.should eql('Finished')
  end


end


