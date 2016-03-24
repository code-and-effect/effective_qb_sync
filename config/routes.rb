Rails.application.routes.draw do
  mount EffectiveQbSync::Engine => '/', as: 'effective_qb_sync'
end

EffectiveQbSync::Engine.routes.draw do
  scope module: 'effective' do

    match 'quickbooks/api', to: 'qb_sync#api', as: 'qb_sync', via: :all

    namespace :admin do
    end
  end
end
