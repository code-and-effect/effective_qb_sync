# Effective Quickbooks Sync

Synchronize [effective_orders](https://github.com/code-and-effect/effective_orders) with [Quickbooks Web Connector](https://developer.intuit.com/docs/quickbooks_web_connector).

## Getting Started

Make sure [effective_orders](https://github.com/code-and-effect/effective_orders) is installed.

Ensure all your `acts_as_purchasable` objects respond to `qb_item_name`.


Add to your Gemfile:

```ruby
gem 'effective_orders'
gem 'effective_qb_sync'
```

Run the bundle command to install it:

```console
bundle install
```

Then run the generator:

```ruby
rails generate effective_qb_sync:install
```

The generator will install an initializer which describes all configuration options and creates a database migration.

If you want to tweak the table name (to use something other than the default 'qb_requests', 'qb_tickets', 'qb_logs' and 'qb_order_items'), manually adjust both the configuration file and the migration now.

Then migrate the database:

```ruby
rake db:migrate
```

## Setting up Quickbooks

Connect the Quickbooks Web Connector to Quickbooks company file

1. Open the Quickbooks Pro company file we'd like to sync with

2. Click Company -> Set up Users and Passwords -> Set Up Users...
  - Add a User "quickbookssync" with password "qbpass"
  - Access for user: "Selected areas of Quickbooks"
    - Sales and Accounts Receivable "Selective Access - Create transactions only"
    - Purchases and Accounts Payable "No Access"
    - Chequing and Credit Cards "No Access"
    - Payroll and Employees "No Access"
    - Sales Tax "No Access"
    - Sensitive Accounting Activities "No Access"
    - Sensitive Financial Reporting "No Access"
    - Chanting or Deleting Transactions  "Yes" and "No"
  - Finished
  - Then make sure that whichever user you use (you CAN ignore above and use Admin...) has its password in our quickbook_settings.yml file

3. Open the Quickbooks Web Connector
  - Add an Application
  - Select the .qwc file.  Don't store it on the desktop in a Mac Parallels, move it into any other directory


4. Customers are added on the fly, but each item must be set up in Quickbooks before it will work on the website.
  - To add an Item:
    - Open Quickbooks
    - Click the menu bar Lists -> Item List
    - In the bottom left, Item -> New
      - Make sure the "Item Name/Number" matches up with the purchasable.purchasable_qb_item_name value
      - The website's price values override Quickbooks
  - Make sure the "GST" line from Quickbooks matches our configuration file ("GST")

## License

MIT License.  Copyright [Code and Effect Inc.](http://www.codeandeffect.com/)

Code and Effect is the product arm of [AgileStyle](http://www.agilestyle.com/), an Edmonton-based shop that specializes in building custom web applications with Ruby on Rails.


## Testing

The test suite for this gem is mostly complete.

Run tests by:

```ruby
rspec
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Bonus points for test coverage
6. Create new Pull Request

