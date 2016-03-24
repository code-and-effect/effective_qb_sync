require 'spec_helper'

describe Effective::QbTicket do

  before(:each) do
    @qb_ticket = Effective::QbTicket.new
  end

  it "should be valid when initialized without any values" do
    @qb_ticket.should be_valid
  end

  it "should report a zero percent by default" do
    @qb_ticket.percent.should eql(0)
  end

  it "should report an error on state" do
    @qb_ticket.state = nil
    @qb_ticket.save
    @qb_ticket.errors[:state].present?.should eq true
  end

  it "should start out in the Ready state" do
    @qb_ticket.state.should eql('Ready')
  end

  it "should load the same one when finding by username" do
    @qb_ticket.save
    @ticket = Effective::QbTicket.find_by_username(@qb_ticket.username)
    @ticket.id.should eql(@qb_ticket.id)
  end

  it "should be able to contain other QbRequests" do
    @qb_ticket.save
    @qb_request = Effective::QbRequest.new(order: Effective::Order.new, request_type: 'OrderItemSynchronization')
    @qb_ticket.qb_requests.push @qb_request
    @qb_ticket.save!

    @qb_ticket.qb_requests.should_not be_empty
    @qb_request.id.should_not be_nil
  end

  it "should return a recorded log message when #log is called" do
    @qb_ticket.save
    log = @qb_ticket.log('This is a log message')
    log.should_not be_nil
    log.should_not be_new_record # make sure it's saved
  end

  it "should increase the number of log messages when #log is called" do
    @qb_ticket.save

    @before = Effective::QbLog.count
    @qb_ticket.log('This is a message')
    @after = Effective::QbLog.count

    @before.should eql(0)
    @after.should eql(1)
    @qb_ticket.qb_logs.count.should eql(1)
  end

end
