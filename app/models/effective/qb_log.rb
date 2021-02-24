module Effective
  class QbLog < ActiveRecord::Base
    belongs_to :qb_ticket

    effective_resource do
      message       :text
      timestamps
    end

    validates :qb_ticket, presence: true
    validates :message, presence: true
  end
end
