EffectiveQbSync.setup do |config|
  # Layout Settings
  # config.layout = { admin: 'admin' }

  # Quickbooks Company File Settings
  # The username / password of the Quickbooks user that should be allowed to synchronize.
  # This must match the user configured in the Quickbooks .qwc file
  config.quickbooks_username = ''
  config.quickbooks_password = ''

  # Sales tax can be added to an order in two ways:
  # 1. Sales tax should be added by Quickbooks
  #    - Set below: config.quickbooks_tax_name = ''
  #    - In Quickbooks: Edit -> Preferences -> Sales Tax -> Company Preferences -> Do you charge sales tax? Yes
  # 2. Sales tax should be added by the website
  #    - Set below: config.quickbooks_tax_name = 'GST Collected'
  #    - In Quickbooks: Edit -> Preferences -> Sales Tax -> Company Preferences -> Do you charge sales tax? No
  #    - In Quickbooks: Add a regular Quickbooks Item matching the config.quickbooks_tax_name
  # See /admin/qb_syncs/instructions for more information.
  config.quickbooks_tax_name = ''

  # If a synchronization errors occurs, send an email with steps to fix the error, to this address
  # Uses effective_orders mailer layout and settings
  # Leave nil to use EffectiveOrders.mailer[:admin_email] value, or provide a to email address here
  config.error_email = nil

end
