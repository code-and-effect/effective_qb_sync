module Effective
  class QbLog < ActiveRecord::Base
    belongs_to :qb_ticket

    # structure do
    #   message       :text
    #   timestamps
    # end

    validates :qb_ticket, presence: true
    validates :message, presence: true

  end
end
