require 'spec_helper'

module Effective::QbRequestSpecHelper

  def valid_user_attributes
    {
      :email => "someone@something.com",
      :password => '1234567890',
      :password_confirmation => '1234567890'
    }
  end

  def valid_order_attributes
    {
      # These are hardcoded in the orders now instead of as attributes
      :purchasable_state => Purchasable::SUCCESS,
      :cardholder => "Cardholder Name",
      :purchased_at => Time.now,
      :card_type => "V",
      :card_num => "4242***4242",
      :exp_month => nil,
      :exp_year => "1212",
      :message => "APPROVED"
    }
  end

  def valid_order_item_attributes
    {
      :quantity=>1,
      :price=>100.00,
      :tax_rate=>0.05,
      :qb_item_name=>'Some Item',
      :name => 'Order Name'
    }
  end

  def failed_order_attributes
    valid_order_attributes.with(:status=>Purchasable::FAILED)
  end

  # valid attributes for qb requests
  def valid_request_attributes
    {
      :state=>'Processing',
      :qb_ticket => Effective::QbTicket.new,
      :order_item => OrderItem.new,
      :order => Order.new,
      :request_type=>'OrderItemSynchronization'
    }
  end

end

describe Effective::QbRequest, "Generating Request QbXML" do

  include Effective::QbRequestSpecHelper

  before :each do
    # let's generate an order that the request will need to use.
    @user = User.new(valid_user_attributes)
    @user.save!

    @order = Order.new(valid_order_attributes)
    @order.user = @user
    @order.order_items.build(valid_order_item_attributes)
    @order.save!

    @qb_request = Effective::QbRequest.new(valid_request_attributes)
    @qb_request.order = @order
    @qb_request.save!
  end

  # safety check before we get crazy
  it "should be valid" do
    @qb_request.should be_valid
  end

  it "should generate valid qb_xml for the CustomerQuery state" do
    @qb_request.state = 'CustomerQuery'
    @qb_request.should be_valid
    qb_xml = @qb_request.generate_request_xml

    @doc = Nokogiri::XML(qb_xml)

    @doc.xpath("//CustomerQueryRq").first["requestID"].should == (@qb_request.id.to_s)
    @doc.at_xpath("//CustomerQueryRq//FullName").content.should eq(@user.full_name)
  end

  it "should generate valid qb_xml for the CreateCustomer state" do
    @qb_request.state = 'CreateCustomer'
    @qb_request.should be_valid
    qb_xml = @qb_request.generate_request_xml

    @doc = Nokogiri::XML(qb_xml)

    @doc.xpath("//CustomerAddRq").first["requestID"].should == (@qb_request.id.to_s)

    @doc.xpath("//CustomerAddRq//CustomerAdd").present?.should == true

    @doc.at_xpath("//CustomerAddRq//CustomerAdd//Name").content.should eq(@user.full_name)
    @doc.at_xpath("//CustomerAddRq//CustomerAdd//FirstName").content.should eq(@user.first_name)
    @doc.at_xpath("//CustomerAddRq//CustomerAdd//LastName").content.should eq(@user.last_name)

    @doc.xpath("//CustomerAddRq//CustomerAdd//BillAddress").present?.should == true
    @doc.at_xpath("//CustomerAddRq//CustomerAdd//BillAddress//Addr2").content.should eq(@user.address1)
    @doc.at_xpath("//CustomerAddRq//CustomerAdd//BillAddress//City").content.should eq(@user.city)
    @doc.at_xpath("//CustomerAddRq//CustomerAdd//BillAddress//PostalCode").content.should eq(@user.postal_code)

    @doc.at_xpath("//CustomerAddRq//CustomerAdd//Phone").content.should eq(@user.phone_home)
    @doc.at_xpath("//CustomerAddRq//CustomerAdd//Email").content.should eq(@user.email)

  end

  it "should generate valid qb_xml for the OrderSync state" do
    @qb_request.state = 'OrderSync'

    @qb_request.should be_valid
    qb_xml = @qb_request.generate_request_xml

    @doc = Nokogiri::XML(qb_xml)

    @doc.xpath("//SalesReceiptAddRq").first["requestID"].should == (@qb_request.id.to_s)

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd").present?.should == true
    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//CustomerRef").present?.should == true

    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//CustomerRef//FullName").content.should eq(@user.full_name)

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//TxnDate").present?.should == true
    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//Memo").present?.should == true
    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//IsToBePrinted").content.should == "false"
    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//IsToBeEmailed").content.should == "false"

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd").present?.should == true
    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//ItemRef").present?.should == true
    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//ItemRef//FullName").content.should eq(valid_order_item_attributes[:qb_item_name])
    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//Desc").content.should eq(valid_order_item_attributes[:name])
    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//Amount").content.to_f.should eq(valid_order_item_attributes[:price])

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//SalesReceiptLineAdd").count.should == 2

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//SalesReceiptLineAdd//Desc").count.should == 2

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//SalesReceiptLineAdd//Desc")[1].content.should eq(QBSETTINGS[:tax_item_name])
    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//SalesReceiptLineAdd//Amount")[1].content.to_f.should eq(valid_order_item_attributes[:price] * valid_order_item_attributes[:tax_rate])
  end

  it "should raise an exception if there is no qb_item_name on the order_item" do
    @qb_request.state = 'OrderSync'
    @qb_request.order.order_items.first.qb_item_name = nil

    # This should raise an error
    lambda { @qb_request.generate_request_xml}.should raise_error
  end

  it "should raise an exception if there is no attached order to the request" do
    @qb_request.order = nil
    Effective::QbRequest::PROCESSING_STATES.each do |state|
      @qb_request.state = state
      lambda {
        @qb_request.generate_request_xml
      }.should raise_error
    end
  end

  it "handle_response_xml should transition to the CreateCustomer state if passed a 500 status Code" do
    @qb_request.state = 'CustomerQuery'
    @qb_request.should be_valid

    @xml = "<root><CustomerQueryRs statusCode=\"500\"></CustomerQueryRs></root>"

    @qb_request.handle_response_xml(@xml)

    @qb_request.state.should == 'CreateCustomer'
  end

  it "handle_response_xml should transition to the OrderSync state if passed a non-500 status Code" do
    @qb_request.state = 'CustomerQuery'
    @qb_request.should be_valid

    @xml = "<root><CustomerQueryRs statusCode=\"499\"></CustomerQueryRs></root>"

    @qb_request.handle_response_xml(@xml)

    @qb_request.state.should == 'OrderSync'
  end

  it "should be able to find the first response with a requestID" do
    @xml = "<root><Something request=\"0\"></Something><AThing requestID=\"500\"></AThing><AThing requestID=\"300\"></AThing></root>"

    Effective::QbRequest.find_first_response_having_a_request_id(@xml).attr('requestID').should eq("500")

  end


#  it "handle_create_customer_response_xml should return true if passed a valid status code" do
#      customer_response_xml = "<root><CustomerAddRs statusCode=\"0\"></CustomerAddRs></root>"
#
#      @qb_request.handle_create_customer_response_xml(customer_response_xml).should eq(true)
#  end

#  it "should raise an error if malformed xml is passed" do
#      @customer_response_xml = "<root><noxml></noxml></root>"

#      @qb_request.handle_create_customer_response_xml(@customer_response_xml)
      #lambda { @qb_request.handle_create_customer_response_xml(@customer_response_xml) }.should raise_error
#  end
end

describe Effective::QbRequest do

  include Effective::QbRequestSpecHelper

  before(:each) do
    @qbxml_success = File.read(Rails.root.to_s + '/../fixtures/qbxml_response_success.xml')

    # let's generate an order that the request will need to use.
    @user = User.new(valid_user_attributes)
    @user.save!

    @order = Order.new(valid_order_attributes)
    @order.user = @user
    @order.order_items.build(valid_order_item_attributes)
    @order.save!

    @qb_request = Effective::QbRequest.new(valid_request_attributes)
    @qb_request.order = @order
    @qb_request.save!
  end

  it "should be valid" do
    @qb_request.should be_valid
  end

  it "should show an error on missing QbTicket" do
    @qb_request.qb_ticket = nil
    @qb_request.should have(1).error_on(:qb_ticket)
  end

 # it "should show an error on an invalid request_type" do
 #   @attributes = valid_request_attributes
 #   @attributes[:state] = 'InvalidRequestType'

 #   @qb_request.attributes = @attributes
 #   @qb_request.should have(1).error_on(:request_type)
 # end

  it "should show an error if request type is OrderItemSynchronization and there is no order" do
    @qb_request.attributes = valid_request_attributes
    @qb_request.request_type = 'OrderItemSynchronization'
    @qb_request.order = nil
    @qb_request.should have(1).error_on(:order)
  end

  it "should return Processing when state is empty" do
    @qb_request.state = nil
    @qb_request.state.should eq 'Processing'
  end

  it "should show an error on an invalid state" do
    @attributes = valid_request_attributes
    @attributes[:state] = 'InvalidState'

    @qb_request.attributes = @attributes
    @qb_request.should have(1).error_on(:state)
  end

  it "should return a found record using response qb xml" do
    Effective::QbRequest.stub!(:find_by_id).with(34).and_return(@qb_request)
    request = Effective::QbRequest.find_using_response_qbxml(@qbxml_success)
    request.should eql(@qb_request)
  end

  it "should return nil if it cannot find the corresponding request using the response qb xml" do
    response_qbxml = '<QBXML><QBXMLMsgsRs></QBXMLMsgsRs></QBXML>'
    Effective::QbRequest.stub!(:find_by_id).with(34).and_return(@qb_request)
    request = Effective::QbRequest.find_using_response_qbxml(response_qbxml)
    request.should be_nil
  end

end


module Effective::SyncOrderItemSpecHelper

  def valid_user_attributes
    {
      :email => "someone@something.com",
      :password => '1234567890',
      :password_confirmation => '1234567890'
    }
  end

  def valid_order_attributes
    {
      # These are hardcoded in the orders now instead of as attributes
      :purchasable_state => Purchasable::SUCCESS,
      :cardholder => "Cardholder Name",
      :purchased_at => Time.now,
      :card_type => "V",
      :card_num => "4242***4242",
      :exp_month => nil,
      :exp_year => "1212",
      :message => "APPROVED"
    }
  end

  def valid_order_item_attributes(order)
    {
      :qb_item_name=>'Web Sale',
      :price=>100,
      :quantity=>1,
      :tax_rate=>2.50,
      :order=>order
    }
  end

end

describe Effective::QbRequest, "Working with Synchronizing OrderItems" do

  include Effective::SyncOrderItemSpecHelper

  # we will create an order with five order items attached to it
  before :each do
    @qb_machine = Effective::QbMachine.new

    # let's generate an order that the request will need to use.
    @user = User.new(valid_user_attributes)
    @user.save!

    @order = Order.new(valid_order_attributes)

    @order.user = @user
    5.times do
      @order.order_items.build(valid_order_item_attributes(@order))
    end
    @order.save!
    @order.mark_successful

  end

  it "Order should be valid" do
    @order.should be_valid
  end

  it "test should verify that the order items are attached to the order" do
    Order.first.order_items.size.should eql(5)
  end

  it "should return an empty array if there are no order items to be synchronized" do
    Order.delete_all
    requests = Effective::QbRequest.new_requests_for_unsynced_items
    requests.should_not be_nil
    requests.size.should eql(0)
  end

  it "should create a request for each order that has no corresponding QbRequest attached to it" do
    requests = Effective::QbRequest.new_requests_for_unsynced_items
    requests.size.should eql(1)
  end

  it "should not return a request for an OrderItem if its Order has a 'Failed' status" do
    @order.purchasable_state = Purchasable::FAILED
    @order.save!

    # return 0 requests because they all belong to the same Failed order
    Effective::QbRequest.new_requests_for_unsynced_items.size.should eql(0)
  end

  # it "should not return a request for an Order if a request has already been created for it" do
  #   requests = Effective::QbRequest.new_requests_for_unsynced_items
  #   request = requests.first

  #   # save and persist this request
  #   request.qb_ticket = @qb_machine.ticket
  #   request.save!

  #   new_requests = Effective::QbRequest.new_requests_for_unsynced_items
  #   new_requests.size.should eql(requests.size-1)
  # end

  it "should return an array of type QbRequest" do
    Effective::QbRequest.new_requests_for_unsynced_items.each do |req|
      req.class.should eql(Effective::QbRequest)
    end
  end

  it "should return each request as having a member OrderItem" do
    Effective::QbRequest.new_requests_for_unsynced_items.each do |req|
      req.order.should_not be_nil
    end
  end

  it "should return each OrderItem having the correct fields filled in" do
    Effective::QbRequest.new_requests_for_unsynced_items.each do |req|
      req.order.order_items.first.qb_item_name.should eql('Web Sale')
      req.order.order_items.first.price.should eql(100)
      req.order.order_items.first.quantity.should eql(1)
    end
  end

  it "should not return any OrderItem that has no QuickBooks item name" do
    requests = Effective::QbRequest.new_requests_for_unsynced_items
    OrderItem.update_all(:qb_item_name => '')
    new_requests = Effective::QbRequest.new_requests_for_unsynced_items

    requests.size.should_not eq new_requests.size
  end

end
