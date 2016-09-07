namespace :effective_qb_sync do
  desc 'Overwrite all quickbooks item names with current acts_as_purchasable object qb_item_name'
  task overwrite_qb_item_names: :environment do
    puts 'WARNING: this task will overwrite all quickbooks item names with new qb_item_names. Proceed? (y/n)'
    (puts 'Aborted' and exit) unless STDIN.gets.chomp.downcase == 'y'

    Effective::QbOrderItem.transaction do
      begin

        Effective::QbOrderItem.includes(order_item: :purchasable).find_each do |qb_order_item|
          order_item = qb_order_item.order_item
          purchasable = qb_order_item.order_item.purchasable

          new_qb_item_name = purchasable.qb_item_name

          unless new_qb_item_name
            raise "acts_as_purchasable object #{order_item.purchasable_type.try(:classify)}<#{order_item.purchasable_id}>.qb_item_name() from Effective::OrderItem<#{order_item.id}> cannot be nil."
          end

          qb_order_item.update_column(:name, new_qb_item_name) # This intentionally skips validation
        end

        puts 'Successfully updated all quickbooks item names.'
      rescue => e
        puts "An error has occurred: #{e.message}"
        puts "(effective_qb_sync) Rollback. No quickbooks item names have been changed."
        raise ActiveRecord::Rollback
      end
    end
  end
end
