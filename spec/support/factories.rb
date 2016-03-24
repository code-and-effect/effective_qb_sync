require 'factory_girl'

FactoryGirl.define do
  factory :address, class: Effective::Address do
    category 'billing'
    full_name 'Peter Pan'
    sequence(:address1) { |n| "1234#{n} Fake Street" }
    city 'A canadian city'
    state_code ['AB', 'BC', 'MB', 'NB', 'NL', 'NT', 'NS', 'ON', 'PE', 'QC', 'SK', 'YT', 'NU'].sample
    country_code 'CA'
    postal_code 'T5T2T1'
  end

  factory :product do # This only exists in the dummy/ app
    sequence(:title) { |n| "Product #{n}" }

    price 1000
    tax_exempt false
  end

  factory :product_with_float_price do # This only exists in the dummy/ app
    sequence(:title) { |n| "Product #{n}" }

    price 10.00
    tax_exempt false
  end

  factory :user do # This only exists in the dummy/ app
    sequence(:email) { |n| "user_#{n}@effective_qb_sync.test"}

    password '12345678'

    after(:build) { |user| user.skip_confirmation! if user.respond_to?(:skip_confirmation!) }
  end

  factory :cart, class: Effective::Cart do
    association :user

    before(:create) do |cart|
      3.times { cart.cart_items << FactoryGirl.create(:cart_item, cart: cart) }
    end
  end

  factory :cart_item, class: Effective::CartItem do
    association :purchasable, factory: :product
    association :cart, factory: :cart

    quantity 1
  end

  factory :cart_with_items, class: Effective::Cart do
    association :user

    before(:create) do |cart|
      3.times { cart.cart_items << FactoryGirl.create(:cart_item, cart: cart) }
    end
  end

  factory :order, class: Effective::Order do
    association :user

    before(:create) do |order|
      order.billing_address = FactoryGirl.build(:address, addressable: order)
      order.shipping_address = FactoryGirl.build(:address, addressable: order)

      3.times { order.order_items << FactoryGirl.create(:order_item, order: order) }
    end
  end

  factory :order_item, class: Effective::OrderItem do
    association :purchasable, factory: :product
    association :order, factory: :order

    sequence(:title) { |n| "Order Item #{n}" }
    quantity 1
    price 1000
    tax_exempt false
  end

  factory :purchased_order, parent: :order do
    payment_provider 'admin'
    payment_card 'unknown'

    after(:create) { |order| order.purchase! }
  end

  factory :declined_order, parent: :order do
    payment_provider 'admin'

    after(:create) { |order| order.decline! }
  end

  factory :pending_order, parent: :order do
    purchase_state 'pending'
  end

end
