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

          array_column :orders do |qb_ticket|
            qb_ticket.qb_requests.select { |qb_request| qb_request.order.present? }
              .map { |qb_request| link_to "##{qb_request.order.to_param}", effective_orders.admin_order_path(qb_request.order) }
              .join('<br>').html_safe
          end

          table_column :actions, sortable: false, filter: false, partial: 'admin/qb_syncs/actions', partial_local: :qb_sync
        end

        def collection
          Effective::QbTicket.includes(qb_requests: :order)
        end
      end
    end
  end
end
