# This is a form object base class for the /admin/qb_syncs/:id "update qb item names" action

module Effective
  class QbOrderItemsForm
    include ActiveModel::Model

    attr_accessor :id, :orders

    def initialize(id:, orders:)
      @id = id
      @orders = Array(orders)
    end

    def qb_order_items
      @qb_order_items||= orders.flat_map { |order| order.order_items.map { |oi| oi.qb_item_name; oi.qb_order_item } }
    end

    # This is required by SimpleForm and Rails for non-ActiveRecord nested attributes
    def qb_order_items_attributes=(qb_order_item_atts)
      qb_order_item_atts.each do |attributes|
        qb_order_item = qb_order_items.find { |qb_order_item| qb_order_item.order_item_id.to_s == attributes[:order_item_id] }
        raise "unable to find qb_order_item with order_item_id #{attributes[:order_item_id]}" unless qb_order_item.present?

        qb_order_item.attributes = attributes.except(:id, :order_item_id)
      end
    end

    def save
      qb_order_items.each { |qb_order_item| qb_order_item.valid? }
      return false unless qb_order_items.all? { |qb_order_item| qb_order_item.valid? }

      success = false

      Effective::QbOrderItem.transaction do
        begin
          qb_order_items.each { |qb_order_item| qb_order_item.save! }
          success = true
        rescue => e
          raise ActiveRecord::Rollback
        end
      end

      success
    end

    def to_param
      id
    end

    def persisted?
      true
    end

  end
end
