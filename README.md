# Effective Quickbooks Sync

Synchronize [effective_orders](https://github.com/code-and-effect/effective_orders) with [Quickbooks Web Connector](https://developer.intuit.com/docs/quickbooks_web_connector).

## Getting Started

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

