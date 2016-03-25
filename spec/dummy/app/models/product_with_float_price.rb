class ProductWithFloatPrice < ActiveRecord::Base
  acts_as_purchasable

  after_purchase do |order, order_item|
  end

  after_decline do |order, order_item|
  end

  def qb_item_name
    'ProductWithFloatPrice'
  end
end
