class Deposit < ApplicationRecord
  belongs_to :tradeline

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :deposit_date, presence: true
  validate :amount_within_outstanding_balance

  private

  # Only concurrency-safe when called inside Tradeline#create_deposit, which holds a row lock.
  def amount_within_outstanding_balance
    return if tradeline.nil? || amount.blank? || !amount.positive?

    balance = tradeline.outstanding_balance

    if balance.nil?
      errors.add(:tradeline, :no_amount)
    elsif amount > balance
      errors.add(:amount, :exceeds_outstanding_balance, balance: format('%.2f', balance))
    end
  end
end
