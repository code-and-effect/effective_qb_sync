module Admin
  class QbSyncsController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_qb_sync) }

    include Effective::CrudController

    if (config = EffectiveQbSync.layout)
      layout(config.kind_of?(Hash) ? config[:admin] : config)
    end

    def index
      @datatable = EffectiveQbSyncDatatable.new(self)
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
      @qb_order_items_form.qb_order_items_attributes = permitted_params[:qb_order_items_attributes].values

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
      @filename = EffectiveQbSync.qwc_name.parameterize + '.qwc'

      data = render_to_string('effective/qb_web_connector/quickbooks', layout: false)

      send_data(data, filename: 'quickbooks.qwc', disposition: 'attachment')
    end

    def set_all_orders_finished
      Effective::QbTicket.transaction do
        begin
          Effective::QbTicket.set_orders_finished!

          flash[:success] = 'Successfully set all orders finished'
        rescue => e
          flash[:danger] = "Unable to set all orders finished: #{e.message}"
          raise ActiveRecord::Rollback
        end
      end

      redirect_to effective_qb_sync.admin_qb_syncs_path
    end

    private

    def permitted_params
      params.require(:effective_qb_order_items_form).permit!
    end

  end
end
