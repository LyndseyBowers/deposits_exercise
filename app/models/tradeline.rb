class Tradeline < ApplicationRecord
  has_many :deposits, dependent: :restrict_with_error

  # Loads each tradeline's deposit sum in the same query, so listing N tradelines
  # doesn't run N extra SUM queries.
  scope :with_deposits_total, lambda {
    select(<<~SQL.squish)
      tradelines.*,
      (SELECT COALESCE(SUM(deposits.amount), 0) FROM deposits WHERE deposits.tradeline_id = tradelines.id) AS deposits_total
    SQL
  }

  # nil when the tradeline has no amount: the balance is unknown, not zero.
  def outstanding_balance
    return if amount.nil?

    amount - deposits_total
  end

  # Uses the preloaded total from .with_deposits_total when present, otherwise sums in SQL.
  # with_lock reloads the record, which drops any preloaded value, so the balance
  # check in create_deposit always sums fresh.
  def deposits_total
    has_attribute?(:deposits_total) ? self[:deposits_total] : deposits.sum(:amount)
  end

  # The only safe way to create a deposit: the row lock serializes concurrent
  # deposits so the balance check can't be raced. See docs/DECISIONS.md §4.
  def create_deposit(attrs)
    with_lock { deposits.create(attrs) }
  end
end
