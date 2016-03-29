# Effective Quickbooks Sync

Synchronize [effective_orders](https://github.com/code-and-effect/effective_orders) with [Quickbooks Web Connector](https://developer.intuit.com/docs/quickbooks_web_connector).

## Getting Started

Make sure [effective_orders](https://github.com/code-and-effect/effective_orders) is installed.

Ensure all your `acts_as_purchasable` objects respond to `qb_item_name`.


Add to your Gemfile:

```ruby
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

### Admin Screen

To use the Admin screen, please also install the effective_datatables gem:

```ruby
gem 'effective_datatables'
```

Then visit:

```ruby
link_to 'Quickbooks', effective_qb_sync.admin_qb_syncs_path   # /admin/qb_syncs
```

### Permissions

The Quickbooks synchronization controller does not require a logged in user, or any other rails permissions.

The sync itself checks that the Quickbooks user performing the sync has a username/password that matches the values in the config/initializers/effective_qb_sync.rb file.

For the admin screen, a logged in user is required (devise) and the user should be able to (CanCan):

```ruby
can :admin, :effective_qb_sync
```

Devise is a required dependency, but CanCan is not.  Please see the authorization_method in the initializer.

## Setting up Quickbooks

Once the gem is installed, visit the /admin/qb_syncs/instructions page for setup instructions.

## License

MIT License.  Copyright [Code and Effect Inc.](http://www.codeandeffect.com/)

Code and Effect is the product arm of [AgileStyle](http://www.agilestyle.com/), an Edmonton-based shop that specializes in building custom web applications with Ruby on Rails.

## Testing

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

