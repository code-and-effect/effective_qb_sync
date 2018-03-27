module Effective
  class QbLog < ActiveRecord::Base
    belongs_to :qb_ticket

    # Attributes
    # message       :text
    # timestamps

    validates :qb_ticket, presence: true
    validates :message, presence: true
  end
end
