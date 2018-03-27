EffectiveQbSync::Engine.routes.draw do
  scope :module => 'effective' do
    match 'quickbooks/api', to: 'qb_sync#api', as: 'qb_sync', via: :all
  end

  namespace :admin do
    resources :qb_syncs, only: [:index, :show, :update] do
      get :instructions, on: :collection
      get :qwc, on: :collection
      post :set_all_orders_finished, on: :collection
    end
  end
end

Rails.application.routes.draw do
  mount EffectiveQbSync::Engine => '/', as: 'effective_qb_sync'
end
