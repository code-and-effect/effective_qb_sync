module Effective
  class QbOrderItem < ActiveRecord::Base
    belongs_to :order_item

    effective_resource do
      name        :string
      timestamps
    end

    validates :name, presence: true
  end
end
