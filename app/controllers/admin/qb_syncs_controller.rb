module Admin
  class QbSyncsController < ApplicationController
    before_filter :authenticate_user!   # This is devise, ensure we're logged in.
    before_filter :restrict_access

    layout (EffectiveQbSync.layout.kind_of?(Hash) ? EffectiveQbSync.layout[:admin_qb_tickets] : EffectiveQbSync.layout)

    def index
      @datatable = Effective::Datatables::QbSyncs.new()
      @page_title = 'Quickbooks Synchronizations'
    end

    def show
      @qb_ticket = Effective::QbTicket.includes(:qb_requests, :qb_logs).find(params[:id])
      @page_title = "Quickbooks Sync ##{@qb_ticket.id}"

      @qb_order_items_form = Effective::QbOrderItemsForm.new(id: @qb_ticket.id, orders: @qb_ticket.orders)
    end

    def update
      @qb_ticket = Effective::QbTicket.includes(:qb_requests, :qb_logs).find(params[:id])
      @page_title = "Quickbooks Sync ##{@qb_ticket.id}"

      @qb_order_items_form = Effective::QbOrderItemsForm.new(id: @qb_ticket.id, orders: @qb_ticket.orders)
      @qb_order_items_form.qb_order_items_attributes = permitted_qb_order_items_params[:qb_order_items_attributes].values

      if @qb_order_items_form.save
        flash[:success] = 'Successfully updated Quickbooks item names'
        redirect_to effective_qb_sync.admin_qb_sync_path(@qb_ticket)
      else
        flash.now[:danger] = 'Unable to update Quickbooks item names'
        render action: :show
      end
    end

    def instructions
      @page_title = 'Quickbooks Setup Instructions'
    end

    def qwc
      @filename = Rails.application.class.parent_name.downcase + '.qwc'

      response.headers['Content-Disposition'] = "attachment; filename=\"#{@filename}\""

      render '/effective/qb_web_connector/quickbooks.qwc', layout: false
    end

    private

    def restrict_access
      EffectiveQbSync.authorized?(self, :admin, :effective_qb_sync)
    end

    def permitted_qb_order_items_params
      params.require(:effective_qb_order_items_form).permit(:id, qb_order_items_attributes: [:name, :id, :order_item_id])
    end


  end
end
