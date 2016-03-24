# EffectiveQbSync Rails Engine

EffectiveQbSync.setup do |config|
  # Configure Database Tables
  config.qb_requests_table_name = :qb_requests
  config.qb_tickets_table_name = :qb_tickets
  config.qb_logs_table_name = :qb_logs
  config.qb_order_items_table_name = :qb_order_items

  # Authorization Method
  #
  # This method is called by all controller actions with the appropriate action and resource
  # If the method returns false, an Effective::AccessDenied Error will be raised (see README.md for complete info)
  #
  # Use via Proc (and with CanCan):
  # config.authorization_method = Proc.new { |controller, action, resource| authorize!(action, resource) }
  #
  # Use via custom method:
  # config.authorization_method = :my_authorization_method
  #
  # And then in your application_controller.rb:
  #
  # def my_authorization_method(action, resource)
  #   current_user.is?(:admin)
  # end
  #
  # Or disable the check completely:
  # config.authorization_method = false
  config.authorization_method = Proc.new { |controller, action, resource| true }

end
