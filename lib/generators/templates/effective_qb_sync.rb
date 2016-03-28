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

  # All EffectiveQbSync controllers will use this layout
  config.layout = 'application'

  # SimpleForm Options
  # This Hash of options will be passed into any admin facing simple_form_for() calls
  config.admin_simple_form_options = {} # For the /admin/qb_tickets form

  # Quickbooks Company File Settings

  # The username / password of the Quickbooks user that should be allowed to synchronize.
  # This must match the user configured in the Quickbooks .qwc file
  config.quickbooks_username = ''
  config.quickbooks_password = ''

  # Quickbooks sales tax can behave in two ways:
  # 1. Sales tax should be added by Quickbooks
  #    - Set below: config.quickbooks_tax_name = ''
  #    - In Quickbooks: Edit -> Preferences -> Sales Tax -> Company Preferences -> Do you charge sales tax? Yes
  # 2. Sales tax should be added by the website
  #    - Set below: config.quickbooks_tax_name = 'GST Collected'
  #    - In Quickbooks: Edit -> Preferences -> Sales Tax -> Company Preferences -> Do you charge sales tax? No
  #    - In Quickbooks: Add a regular Quickbooks Item matching the config.quickbooks_tax_name
  config.quickbooks_tax_name = ''

  # If a synchronization errors occurs, send an email with steps to fix the error, to this address
  # Uses effective_orders mailer layout and settings
  # Leave nil to use EffectiveOrders.mailer[:admin_email] value, or provide any valid email here
  config.error_email = nil

end
