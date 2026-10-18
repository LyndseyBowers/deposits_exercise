json.extract! tradeline, :id, :name
json.amount money(tradeline.amount)
json.outstanding_balance money(tradeline.outstanding_balance)
json.extract! tradeline, :created_at, :updated_at
