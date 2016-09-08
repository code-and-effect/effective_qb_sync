if defined?(EffectiveDatatables)
  module Effective
    module Datatables
      class QbSyncs < Effective::Datatable
        datatable do
          default_order :created_at, :desc

          table_column :created_at
          table_column :state, filter: { values: QbTicket::STATES }

          array_column :num_orders, visible: false do |qb_ticket|
            qb_ticket.qb_requests.length
          end

          table_column :orders, sortable: false, as: :obfuscated_id do |qb_ticket|
            qb_ticket.qb_requests.select { |qb_request| qb_request.order.present? }
              .map { |qb_request| link_to "##{qb_request.order.to_param}", effective_orders.admin_order_path(qb_request.order) }
              .join('<br>').html_safe
          end

          actions_column partial: 'admin/qb_syncs/actions', partial_local: :qb_sync
        end

        def collection
          Effective::QbTicket.includes(qb_requests: :order)
        end

        def search_column(collection, table_column, search_term, sql_column)
          if table_column[:name] == 'orders'
            order = Effective::Order.where(id: search_term).first

            if order.present?
              collection.where(id: Effective::QbRequest.where(order_id: order.id).pluck(:qb_ticket_id))
            else
              collection.none
            end
          else
            super
          end
        end

      end
    end
  end
end
