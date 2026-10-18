require 'rails_helper'

RSpec.describe Tradeline, type: :model do
  let(:tradeline) { FactoryBot.create :tradeline, amount: 100 }

  describe '#outstanding_balance' do
    it 'equals the amount when there are no deposits' do
      expect(tradeline.outstanding_balance).to eq(100)
    end

    it 'subtracts all deposits' do
      FactoryBot.create :deposit, tradeline: tradeline, amount: 25.50
      FactoryBot.create :deposit, tradeline: tradeline, amount: 10.25, deposit_date: Date.current + 60

      expect(tradeline.outstanding_balance).to eq(BigDecimal('64.25'))
    end

    it 'is nil when the tradeline has no amount' do
      tradeline.update!(amount: nil)

      expect(tradeline.outstanding_balance).to be_nil
    end
  end

  describe '.with_deposits_total' do
    it 'preloads the same balance that is computed on demand' do
      FactoryBot.create :deposit, tradeline: tradeline, amount: 25.50
      empty = FactoryBot.create :tradeline, amount: 10

      loaded = Tradeline.with_deposits_total.where(id: [tradeline.id, empty.id]).index_by(&:id)

      expect(loaded[tradeline.id].outstanding_balance).to eq(BigDecimal('74.50'))
      expect(loaded[empty.id].outstanding_balance).to eq(10)
    end

    it 'never lets a stale preloaded total leak into the overpayment check' do
      stale = Tradeline.with_deposits_total.find(tradeline.id) # preloads a total of 0
      FactoryBot.create :deposit, tradeline: tradeline, amount: 90

      deposit = stale.create_deposit(amount: 20, deposit_date: Date.current)

      expect(deposit.errors.of_kind?(:amount, :exceeds_outstanding_balance)).to be(true)
    end
  end

  describe '#create_deposit' do
    it 'creates a valid deposit' do
      deposit = tradeline.create_deposit(amount: 40, deposit_date: Date.current)

      expect(deposit).to be_persisted
      expect(tradeline.outstanding_balance).to eq(60)
    end

    it 'returns an unsaved deposit with errors when invalid' do
      deposit = tradeline.create_deposit(amount: 150, deposit_date: Date.current)

      expect(deposit).not_to be_persisted
      expect(deposit.errors[:amount]).to be_present
      expect(tradeline.deposits.count).to eq(0)
    end

    it 'takes a row lock on the tradeline' do
      expect(tradeline).to receive(:with_lock).and_call_original

      tradeline.create_deposit(amount: 40, deposit_date: Date.current)
    end
  end

  describe 'deletion' do
    it 'is prevented when deposits exist' do
      FactoryBot.create :deposit, tradeline: tradeline

      expect(tradeline.destroy).to be(false)
      expect(tradeline.errors[:base]).to include('Cannot delete record because dependent deposits exist')
      expect(Tradeline.exists?(tradeline.id)).to be(true)
    end

    it 'is allowed when there are no deposits' do
      expect(tradeline.destroy).to be_truthy
    end

    it 'is blocked by the foreign key when callbacks are skipped' do
      FactoryBot.create :deposit, tradeline: tradeline

      expect { tradeline.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
