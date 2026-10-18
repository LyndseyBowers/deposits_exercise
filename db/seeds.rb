# Seed data for Lyndsey's very real, very serious finances.
# Idempotent: safe to run repeatedly with `bin/rails db:seed`.
# Each tradeline also covers an edge case for deposits/balances (noted in brackets).

TRADELINES = [
  { name: 'Pre-Beyond Finance Credit Card',    amount: 3223.54 },    # [typical]
  { name: 'Car Loan for the Commute to BF HQ', amount: 18_500.00 },  # [larger balance]
  { name: 'Cold Brew Line of Credit',          amount: 0.01 },       # [smallest payable balance] Fueled this submission.
  { name: 'Imposter Syndrome',                 amount: 0 },          # [nothing left to deposit] Paid in full.
  { name: 'Value Lyndsey Adds to the Team',    amount: 999_999.99 }, # [max for decimal(8,2)] The real number needs a migration.
  { name: 'Reasons Not to Hire Lyndsey',       amount: nil }         # [nil amount] None on record. Deposits rejected.
].freeze

TRADELINES.each do |attrs|
  Tradeline.find_or_create_by!(name: attrs[:name]) do |t|
    t.amount = attrs[:amount]
  end
end

# Deposits are only seeded for tradelines that have none, keeping this idempotent.
today = Date.current
first_paycheck = today + 14 # optimistic, but the deposit date is "most likely a future date"

DEPOSITS = {
  'Pre-Beyond Finance Credit Card' => [
    [200.00, today - 7],      # 200 OK
    [404.00, first_paycheck]  # Excuses for not paying this off: Not Found
  ],
  'Car Loan for the Commute to BF HQ' =>
    (1..3).map { |m| [450.00, first_paycheck.next_month(m)] }, # monthly, starting after onboarding
  'Cold Brew Line of Credit' => [[0.01, today + 1]],           # balance: 0.00, caffeine: 100%
  'Value Lyndsey Adds to the Team' => [[42.00, first_paycheck]] # a down payment; the rest is delivered on the job
}.freeze

DEPOSITS.each do |name, deposits|
  tradeline = Tradeline.find_by!(name: name)
  next if tradeline.deposits.exists?

  deposits.each do |amount, date|
    deposit = tradeline.create_deposit(amount: amount, deposit_date: date)
    raise "Seed deposit invalid for #{name}: #{deposit.errors.full_messages.join(', ')}" unless deposit.persisted?
  end
end

puts "Seeded #{Tradeline.count} tradelines, #{Deposit.count} deposits. Outstanding offers: 0 (for now)."
