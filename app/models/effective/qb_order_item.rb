module Effective
  class QbOrderItem < ActiveRecord::Base
    belongs_to :order_item

    # Attributes
    # name                   :string
    # timestamps

    validates :order_item, presence: true
    validates :name, presence: true
  end
end
