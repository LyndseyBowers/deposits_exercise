class Tradeline < ApplicationRecord
  has_many :deposits, dependent: :restrict_with_error

  # nil when the tradeline has no amount: the balance is unknown, not zero.
  def outstanding_balance
    return if amount.nil?

    amount - deposits.sum(:amount)
  end

  # The only safe way to create a deposit: the row lock serializes concurrent
  # deposits so the balance check can't be raced. See docs/DECISIONS.md §4.
  def create_deposit(attrs)
    with_lock { deposits.create(attrs) }
  end
end
