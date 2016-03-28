module Admin
  class QbSyncsController < ApplicationController
    before_filter :authenticate_user!   # This is devise, ensure we're logged in.

    layout (EffectiveQbSync.layout.kind_of?(Hash) ? EffectiveQbSync.layout[:admin_qb_tickets] : EffectiveQbSync.layout)

    def index
      @datatable = Effective::Datatables::QbSyncs.new() if defined?(EffectiveDatatables)
      @page_title = 'Quickbooks Synchronizations'

      EffectiveQbSync.authorized?(self, :admin, :effective_qb_sync)
    end

    def show
      @qb_ticket = Effective::QbTicket.includes(:qb_requests, :qb_logs).find(params[:id])
      @page_title = "Quickbooks Sync ##{@qb_ticket.id}"

      EffectiveQbSync.authorized?(self, :show, @qb_ticket)
    end

  end
end
