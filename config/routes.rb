Rails.application.routes.draw do
  mount EffectiveQbSync::Engine => '/', as: 'effective_qb_sync'
end

EffectiveQbSync::Engine.routes.draw do
  scope module: 'effective' do
    namespace :admin do
    end
  end
end
