require 'rails_helper'

# Request specs exercise the full stack (router, middleware, Jbuilder views) the way a client would.
# These replace the starter repo's controller specs, which bypassed the router and view rendering.
RSpec.describe 'Tradelines', type: :request do
  # A method, not let: the journey spec makes several requests and needs each response parsed fresh.
  def json = JSON.parse(response.body)

  describe 'GET /tradelines' do
    it 'responds with a 200 and JSON, even without an Accept header' do
      get '/tradelines'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
    end

    it 'returns an empty array when there are no tradelines' do
      get '/tradelines'

      expect(json).to eq([])
    end

    it 'returns every tradeline' do
      FactoryBot.create :tradeline, name: 'Card A'
      FactoryBot.create :tradeline, name: 'Card B', amount: 100

      get '/tradelines'

      expect(json.map { |t| t['name'] }).to contain_exactly('Card A', 'Card B')
    end

    it 'includes each outstanding balance' do
      a = FactoryBot.create :tradeline, amount: 100
      b = FactoryBot.create :tradeline, amount: 50
      FactoryBot.create :deposit, tradeline: a, amount: 30

      get '/tradelines'

      balances = json.to_h { |t| [t['id'], t['outstanding_balance']] }
      expect(balances).to eq(a.id => '70.00', b.id => '50.00')
    end

    it 'loads balances without a query per tradeline' do
      3.times do
        tradeline = FactoryBot.create :tradeline, amount: 100
        FactoryBot.create :deposit, tradeline: tradeline, amount: 10
      end

      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { get '/tradelines' }

      expect(queries.size).to eq(1)
    end
  end

  describe 'GET /tradelines/:id' do
    let(:tradeline) { FactoryBot.create :tradeline }

    it 'responds with a 200' do
      get "/tradelines/#{tradeline.id}"

      expect(response).to have_http_status(:ok)
    end

    # Pins down the JSON contract so changes to it are deliberate.
    it 'returns exactly the documented fields' do
      get "/tradelines/#{tradeline.id}"

      expect(json.keys).to contain_exactly('id', 'name', 'amount', 'outstanding_balance', 'created_at', 'updated_at')
      expect(json).to include('id' => tradeline.id, 'name' => 'Some Credit Card')
    end

    it 'serializes amount as an exact decimal string' do
      get "/tradelines/#{tradeline.id}"

      expect(json['amount']).to eq('3223.54')
    end

    it 'always formats money with two decimals' do
      tradeline.update!(amount: 18_500)

      get "/tradelines/#{tradeline.id}"

      expect(json).to include('amount' => '18500.00', 'outstanding_balance' => '18500.00')
    end

    it 'subtracts all deposits, including future-dated ones, from the outstanding balance' do
      FactoryBot.create :deposit, tradeline: tradeline, amount: 200, deposit_date: Date.current - 7
      FactoryBot.create :deposit, tradeline: tradeline, amount: 404, deposit_date: Date.current + 14

      get "/tradelines/#{tradeline.id}"

      expect(json['outstanding_balance']).to eq('2619.54')
    end

    it 'returns a null amount and balance when the tradeline has none' do
      tradeline.update!(amount: nil)

      get "/tradelines/#{tradeline.id}"

      expect(json).to include('amount' => nil, 'outstanding_balance' => nil)
    end

    it 'responds with a 404 when the tradeline is not found' do
      get '/tradelines/1000'

      expect(response).to have_http_status(:not_found)
      expect(json['errors']).to contain_exactly(a_hash_including('code' => 'not_found'))
    end
  end

  it 'reflects deposits in the balance until it is paid down, then rejects more' do
    tradeline = FactoryBot.create :tradeline, name: 'Pre-Beyond Finance Credit Card', amount: 100
    deposit = ->(amount) { post "/tradelines/#{tradeline.id}/deposits", params: { deposit: { amount: amount, deposit_date: '2026-12-01' } }, as: :json }

    deposit.call(60)
    expect(response).to have_http_status(:created)

    get "/tradelines/#{tradeline.id}"
    expect(json['outstanding_balance']).to eq('40.00')

    deposit.call(40)
    expect(response).to have_http_status(:created)

    get '/tradelines'
    expect(json.first['outstanding_balance']).to eq('0.00')

    deposit.call(0.01)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json['errors'].first['code']).to eq('exceeds_outstanding_balance')

    get "/tradelines/#{tradeline.id}/deposits"
    expect(json.map { |d| d['amount'] }).to eq(%w[60.00 40.00])
  end
end
