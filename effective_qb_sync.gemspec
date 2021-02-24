$:.push File.expand_path('../lib', __FILE__)

require 'effective_qb_sync/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'effective_qb_sync'
  s.version     = EffectiveQbSync::VERSION
  s.authors     = ['Code and Effect']
  s.email       = ['info@codeandeffect.com']
  s.homepage    = 'https://github.com/code-and-effect/effective_qb_sync'
  s.summary     = 'Synchronize EffectiveOrders with QuickBooks Web Connector.'
  s.description = 'Synchronize EffectiveOrders with QuickBooks Web Connector.'
  s.licenses    = ['MIT']

  s.files = Dir['{app,config,db,lib}/**/*'] + ['MIT-LICENSE', 'Rakefile']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'rails', '>= 4.2.0'
  s.add_dependency 'nokogiri'
  s.add_dependency 'effective_resources'
  s.add_dependency 'effective_datatables'
  s.add_dependency 'effective_orders'
end
