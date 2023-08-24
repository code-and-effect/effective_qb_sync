class CreateEffectiveQbSync < ActiveRecord::Migration[6.0]
  def change
    create_table :qb_requests do |t|
      t.integer   :order_id
      t.integer   :qb_ticket_id

      t.string    :state, default: 'Processing'
      t.text      :error

      t.string    :request_type
      t.text      :request_qbxml
      t.text      :response_qbxml

      t.datetime  :request_sent_at
      t.datetime  :response_received_at

      t.timestamps
    end
    add_index :qb_requests, :order_id

    create_table :qb_tickets do |t|
      t.integer   :qb_request_id

      t.string    :username
      t.text      :hpc_response
      t.string    :company_file_name
      t.string    :country
      t.string    :qbxml_major_version
      t.string    :qbxml_minor_version

      t.string    :state, default: 'Ready'
      t.integer   :percent, default: 0

      t.text      :connection_error_hresult
      t.text      :connection_error_message
      t.text      :last_error

      t.timestamps
    end
    add_index :qb_tickets, :qb_request_id

    create_table :qb_logs do |t|
      t.integer   :qb_ticket_id
      t.text      :message

      t.timestamps
    end
    add_index :qb_logs, :qb_ticket_id

    create_table :qb_order_items do |t|
      t.integer    :order_item_id
      t.string     :name

      t.timestamps
    end
    add_index :qb_order_items, :order_item_id

  end
end
