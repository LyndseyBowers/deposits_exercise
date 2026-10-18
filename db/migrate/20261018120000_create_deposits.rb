class CreateDeposits < ActiveRecord::Migration[7.1]
  def change
    create_table :deposits do |t|
      t.references :tradeline, null: false, foreign_key: true
      t.decimal :amount, precision: 8, scale: 2, null: false
      t.date :deposit_date, null: false

      t.timestamps
    end

    add_check_constraint :deposits, 'amount > 0', name: 'deposits_amount_positive'
  end
end
