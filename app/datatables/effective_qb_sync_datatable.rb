class EffectiveQbSyncDatatable < Effective::Datatable
  datatable do
    order :created_at, :desc

    col :created_at
    col :state

    val :num_orders, visible: false do |qb_ticket|
      qb_ticket.qb_requests.length
    end

    col :orders

    actions_col do |qb_ticket|
      dropdown_link_to 'Show', effective_qb_sync.admin_qb_sync_path(qb_ticket)
    end

  end

  collection do
    Effective::QbTicket.deep.includes(:orders).all
  end

end
