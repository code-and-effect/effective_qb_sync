module Effective
  class QbOrderItem < ActiveRecord::Base
    belongs_to :order_item

    effective_resource do
      name        :string
      timestamps
    end

    validates :order_item, presence: true
    validates :name, presence: true
  end
end
