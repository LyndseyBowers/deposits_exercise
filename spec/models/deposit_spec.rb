require 'rails_helper'

# Assertions use error codes (errors.of_kind?), not message text, so messages can change freely.
RSpec.describe Deposit, type: :model do
  let(:tradeline) { FactoryBot.create :tradeline, amount: 100 }

  def build_deposit(**attrs)
    tradeline.deposits.build({ amount: 50, deposit_date: Date.current }.merge(attrs))
  end

  it 'is valid with an amount within the outstanding balance' do
    expect(build_deposit).to be_valid
  end

  it 'allows a deposit equal to the outstanding balance' do
    expect(build_deposit(amount: 100)).to be_valid
  end

  it 'allows a past deposit date' do
    expect(build_deposit(deposit_date: Date.current - 30)).to be_valid
  end

  it 'requires a deposit date' do
    deposit = build_deposit(deposit_date: nil)

    expect(deposit).not_to be_valid
    expect(deposit.errors.of_kind?(:deposit_date, :blank)).to be(true)
  end

  it 'treats an unparseable deposit date as missing' do
    deposit = build_deposit(deposit_date: 'next tuesday-ish')

    expect(deposit).not_to be_valid
    expect(deposit.errors.of_kind?(:deposit_date, :blank)).to be(true)
  end

  it 'requires an amount' do
    deposit = build_deposit(amount: nil)

    expect(deposit).not_to be_valid
    expect(deposit.errors.of_kind?(:amount, :blank)).to be(true)
  end

  [0, -5].each do |amount|
    it "rejects an amount of #{amount}" do
      deposit = build_deposit(amount: amount)

      expect(deposit).not_to be_valid
      expect(deposit.errors.details[:amount]).to eq([{ error: :greater_than, value: amount, count: 0 }])
    end
  end

  it 'rejects a non-numeric amount' do
    deposit = build_deposit(amount: 'abc')

    expect(deposit).not_to be_valid
    expect(deposit.errors.of_kind?(:amount, :not_a_number)).to be(true)
  end

  it 'rejects an amount exceeding the outstanding balance' do
    deposit = build_deposit(amount: 100.01)

    expect(deposit).not_to be_valid
    expect(deposit.errors.of_kind?(:amount, :exceeds_outstanding_balance)).to be(true)
  end

  it 'includes the remaining balance in the message' do
    deposit = build_deposit(amount: 100.01)
    deposit.validate

    expect(deposit.errors.messages_for(:amount).first).to include('100.00')
  end

  it 'accounts for existing deposits, including future-dated ones' do
    FactoryBot.create :deposit, tradeline: tradeline, amount: 60, deposit_date: Date.current + 30

    deposit = build_deposit(amount: 41)

    expect(deposit).not_to be_valid
    expect(deposit.errors.details[:amount]).to include(error: :exceeds_outstanding_balance, balance: '40.00')
  end

  it 'rejects deposits on a tradeline with no amount' do
    tradeline.update!(amount: nil)

    deposit = build_deposit

    expect(deposit).not_to be_valid
    expect(deposit.errors.of_kind?(:tradeline, :no_amount)).to be(true)
  end

  it 'enforces a positive amount at the database level' do
    deposit = FactoryBot.create :deposit, tradeline: tradeline

    expect { deposit.update_column(:amount, 0) }.to raise_error(ActiveRecord::StatementInvalid, /deposits_amount_positive/)
  end
end
