require 'rails_helper'

# Seeds go through the real validations, so a rule change could quietly break `db:seed`.
RSpec.describe 'db/seeds.rb' do
  def load_seeds
    expect { Rails.application.load_seed }.to output(/Seeded/).to_stdout
  end

  it 'loads without errors' do
    load_seeds

    expect(Tradeline.count).to eq(6)
    expect(Deposit.count).to eq(7)
  end

  it 'is idempotent' do
    load_seeds
    load_seeds

    expect(Tradeline.count).to eq(6)
    expect(Deposit.count).to eq(7)
  end

  it 'never leaves a negative balance' do
    load_seeds

    expect(Tradeline.all.filter_map(&:outstanding_balance)).to all(be >= 0)
  end
end
