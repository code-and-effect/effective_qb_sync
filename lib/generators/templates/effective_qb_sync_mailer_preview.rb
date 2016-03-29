# In Rails 4.1 and above, visit:
# http://localhost:3000/rails/mailers
# to see a preview of the following emails:

class EffectiveQbSyncMailerPreview < ActionMailer::Preview
  # All order_errors are called from QbTicket.error!
  # There are 3 general types of errors that occur

  def error_record_does_not_exist
    order_error('Invalid argument. The specified record does not exist in the list.')
  end

  def error_invalid_reference_to_item
    order_error('There is an invalid reference to QuickBooks Item "Tax On Sale" in the SalesReceipt line.')
  end

  def error_element_already_in_use
    order_error('The name "Peter Pan" of the list element is already in use.')
  end

  def error_unknown
    order_error('unknown')
  end

  private

  def order_error(error)
    order = Effective::Order.new()

    Effective::OrdersMailer.order_error(
      order: order,
      error: error,
      to: EffectiveQbSync.error_email,
      subject: "Quickbooks failed to synchronize order ##{order.to_param}",
      template: 'qb_sync_error'
    )
  end

end
