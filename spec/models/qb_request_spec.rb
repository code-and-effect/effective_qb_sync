require 'spec_helper'

module Effective::QbRequestSpecHelper

  # valid attributes for qb requests
  def valid_request_attributes
    {
      :state=>'Processing',
      :qb_ticket => Effective::QbTicket.new,
      :order => Effective::Order.new,
      :request_type=>'OrderItemSynchronization'
    }
  end

end

describe Effective::QbRequest, "Generating Request QbXML" do

  include Effective::QbRequestSpecHelper

  before :each do
    # let's generate an order that the request will need to use.
    @order = FactoryGirl.create(:purchased_order)
    @user = @order.user

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

    @doc.at_xpath("//CustomerQueryRq//FullName").content.should eq(@order.billing_name)
  end

  it "should generate valid qb_xml for the CreateCustomer state" do
    @qb_request.state = 'CreateCustomer'
    @qb_request.should be_valid
    qb_xml = @qb_request.generate_request_xml

    @doc = Nokogiri::XML(qb_xml)

    @doc.xpath("//CustomerAddRq").first["requestID"].should == (@qb_request.id.to_s)

    @doc.xpath("//CustomerAddRq//CustomerAdd").present?.should == true

    @doc.at_xpath("//CustomerAddRq//CustomerAdd//Name").content.should eq(@order.billing_name)

    @doc.at_xpath("//CustomerAddRq//CustomerAdd//FirstName").content.present?.should eq true
    @doc.at_xpath("//CustomerAddRq//CustomerAdd//LastName").content.present?.should eq true

    @doc.xpath("//CustomerAddRq//CustomerAdd//BillAddress").present?.should == true
    @doc.at_xpath("//CustomerAddRq//CustomerAdd//BillAddress//Addr2").content.should eq(@order.billing_address.address1)
    @doc.at_xpath("//CustomerAddRq//CustomerAdd//BillAddress//City").content.should eq(@order.billing_address.city)
    @doc.at_xpath("//CustomerAddRq//CustomerAdd//BillAddress//PostalCode").content.should eq(@order.billing_address.postal_code)

    @doc.at_xpath("//CustomerAddRq//CustomerAdd//Phone").content.should eq(@user.phone)
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

    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//CustomerRef//FullName").content.should eq(@order.billing_name)

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//TxnDate").present?.should == true
    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//Memo").present?.should == true
    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//IsToBePrinted").content.should == 'false'
    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//IsToBeEmailed").content.should == 'false'

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd").present?.should == true
    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//ItemRef").present?.should == true
    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//ItemRef//FullName").content.should eq(@order.order_items.first.qb_item_name)
    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//Desc").content.should eq(@order.order_items.first.title)
    @doc.at_xpath("//SalesReceiptAddRq//SalesReceiptAdd//Amount").content.to_f.should eq(@order.order_items.first.subtotal / 100.0)

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//SalesReceiptLineAdd").count.should == @order.order_items.length + 1

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//SalesReceiptLineAdd//Desc").count.should == @order.order_items.length + 1

    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//SalesReceiptLineAdd//Desc").last.content.should eq(EffectiveQbSync.quickbooks_tax_name)
    @doc.xpath("//SalesReceiptAddRq//SalesReceiptAdd//SalesReceiptLineAdd//Amount").last.content.to_f.should eq(@order.tax / 100.0)
  end

  it "should raise an exception if there is no qb_item_name on the order_item" do
    @qb_request.state = 'OrderSync'
    allow(@qb_request.order.order_items.first).to receive(:qb_item_name).and_return(nil)

    # This should raise an error
    (@qb_request.generate_request_xml rescue :error).should eq :error
  end

  it "should raise an exception if there is no attached order to the request" do
    @qb_request.order = nil
    Effective::QbRequest::PROCESSING_STATES.each do |state|
      @qb_request.state = state
      (@qb_request.generate_request_xml rescue :failed).should eq :failed
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

    Effective::QbRequest.find_first_response_having_a_request_id(@xml).attr('requestID').should eq('500')

  end


 it "handle_create_customer_response_xml should return true if passed a valid status code" do
     customer_response_xml = "<root><CustomerAddRs statusCode=\"0\"></CustomerAddRs></root>"

     @qb_request.handle_create_customer_response_xml(customer_response_xml).should eq(true)
 end

  it "should raise an error if malformed xml is passed" do
    @customer_response_xml = "<root><noxml></noxml></root>"

    (@qb_request.handle_create_customer_response_xml(@customer_response_xml) rescue :error).should eq :error
  end

end

describe Effective::QbRequest do

  include Effective::QbRequestSpecHelper

  before(:each) do
    @qbxml_success = File.read(Rails.root.to_s + '/../fixtures/qbxml_response_success.xml')

    # let's generate an order that the request will need to use.
    @order = FactoryGirl.create(:purchased_order)
    @user = @order.user

    @qb_request = Effective::QbRequest.new(valid_request_attributes)
    @qb_request.order = @order
    @qb_request.save!
  end

  it "should be valid" do
    @qb_request.should be_valid
  end

  it "should show an error on missing QbTicket" do
    @qb_request.qb_ticket = nil
    @qb_request.save
    @qb_request.errors[:qb_ticket].present?.should eq true
  end

  it "should show an error if request type is OrderItemSynchronization and there is no order" do
    @qb_request.attributes = valid_request_attributes
    @qb_request.request_type = 'OrderItemSynchronization'
    @qb_request.order = nil
    @qb_request.save
    @qb_request.errors[:order].present?.should eq true
  end

  it "should return Processing when state is empty" do
    @qb_request.state = nil
    @qb_request.state.should eq 'Processing'
  end

  it "should show an error on an invalid state" do
    @attributes = valid_request_attributes
    @attributes[:state] = 'InvalidState'

    @qb_request.attributes = @attributes
    @qb_request.save
    @qb_request.errors[:state].present?.should eq true
  end

  it "should return a found record using response qb xml" do
    allow(Effective::QbRequest).to receive(:find_by_id).and_return(@qb_request)
    request = Effective::QbRequest.find_using_response_qbxml(@qbxml_success)
    request.should eql(@qb_request)
  end

  it "should return nil if it cannot find the corresponding request using the response qb xml" do
    response_qbxml = '<QBXML><QBXMLMsgsRs></QBXMLMsgsRs></QBXML>'
    allow(Effective::QbRequest).to receive(:find_by_id).and_return(@qb_request)
    request = Effective::QbRequest.find_using_response_qbxml(response_qbxml)
    request.should be_nil
  end
end

describe Effective::QbRequest, "Working with Synchronizing Orders" do

  include Effective::QbRequestSpecHelper

  # we will create an order with five order items attached to it
  before :each do
    @qb_machine = Effective::QbMachine.new

    # let's generate an order that the request will need to use.
    @order = FactoryGirl.create(:purchased_order)
    @user = @order.user
  end

  it "Order should be valid" do
    @order.should be_valid
  end

  it "test should verify that the order items are attached to the order" do
    (Effective::Order.first.order_items.size > 1).should eq true
  end

  it "should return an empty array if there are no order items to be synchronized" do
    Effective::Order.delete_all
    requests = Effective::QbRequest.new_requests_for_unsynced_items
    requests.should_not be_nil
    requests.size.should eql(0)
  end

  it "should create a request for each order that has no corresponding QbRequest attached to it" do
    requests = Effective::QbRequest.new_requests_for_unsynced_items
    requests.size.should eql(1)
  end

  it "should not return a request for an OrderItem if its Order has a 'Failed' status" do
    @order.purchase_state = 'declined'
    @order.save(validate: false)

    # return 0 requests because they all belong to the same Failed order
    Effective::QbRequest.new_requests_for_unsynced_items.size.should eql(0)
  end

  it "should not return a request for an Order if a request has already been created for it" do
    requests = Effective::QbRequest.new_requests_for_unsynced_items
    request = requests.first

    # save and persist this request
    request.qb_ticket = @qb_machine.ticket
    request.save!
    request.transition_state('Finished')  # This was changed for effective_qb_sync

    new_requests = Effective::QbRequest.new_requests_for_unsynced_items
    new_requests.size.should eql(requests.size-1)
  end

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
      order_item = req.order.order_items.first

      order_item.purchasable.kind_of?(Product).should eq true
      order_item.qb_item_name.should eq 'Product'
      order_item.price.should eq 1000
      order_item.quantity.should eq 1
    end
  end

  it 'should create one qb_order_item for each order_item' do
    Effective::QbRequest.new_requests_for_unsynced_items.each do |req|
      req.qb_ticket = Effective::QbTicket.new()
      req.transition_to_finished

      # One QbOrderItem per OrderItem
      Effective::QbOrderItem.count.should eq req.order.order_items.length

      Effective::OrderItem.all.each { |oi| oi.qb_order_item.present?.should eq true }
    end
  end

  # it "should not return any OrderItem that has no QuickBooks item name" do
  #   requests = Effective::QbRequest.new_requests_for_unsynced_items
  #   Effective::OrderItem.update_all(:qb_item_name => '')
  #   new_requests = Effective::QbRequest.new_requests_for_unsynced_items

  #   requests.size.should_not eq new_requests.size
  # end

end
