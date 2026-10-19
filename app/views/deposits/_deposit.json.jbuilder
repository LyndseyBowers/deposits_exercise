json.extract! deposit, :id, :tradeline_id, :deposit_date
json.amount money(deposit.amount)
json.extract! deposit, :created_at, :updated_at
