unless Gem::Version.new(EffectiveDatatables::VERSION) < Gem::Version.new('3.0')
  class EffectiveQbSyncDatatable < Effective::Datatable
    datatable do
      order :created_at, :desc

      col :created_at
      col :state, search: { collection: Effective::QbTicket::STATES }

      val :num_orders, visible: false do |qb_ticket|
        qb_ticket.qb_requests.length
      end

      val :orders, sort: false, as: :obfuscated_id do |qb_ticket|
        qb_ticket.qb_requests.select { |qb_request| qb_request.order.present? }
      end.format do |requests|
        requests.map { |qb_request| link_to "##{qb_request.order.to_param}", effective_orders.admin_order_path(qb_request.order) }
        .join('<br>').html_safe
      end.search do |collection, term, column, sql_column|
        order = Effective::Order.where(id: search_term).first

        if order.present?
          collection.where(id: Effective::QbRequest.where(order_id: order.id).pluck(:qb_ticket_id))
        else
          collection.none
        end
      end

      actions_col partial: 'admin/qb_syncs/actions', partial_as: :qb_sync
    end

    collection do
      Effective::QbTicket.includes(qb_requests: :order)
    end

  end
end
