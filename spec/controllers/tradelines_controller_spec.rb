require 'rails_helper'

RSpec.describe TradelinesController, type: :controller do
  # Controller specs skip view rendering and the router's JSON default; both are needed for Jbuilder output.
  render_views

  let(:json) { JSON.parse(response.body) }

  describe '#index' do
    it 'responds with a 200' do
      get :index, format: :json

      expect(response).to have_http_status(:ok)
    end

    it 'returns an empty array when there are no tradelines' do
      get :index, format: :json

      expect(json).to eq([])
    end

    it 'returns every tradeline' do
      FactoryBot.create :tradeline, name: 'Card A'
      FactoryBot.create :tradeline, name: 'Card B', amount: 100

      get :index, format: :json

      expect(json.map { |t| t['name'] }).to contain_exactly('Card A', 'Card B')
    end

    it 'includes each outstanding balance' do
      a = FactoryBot.create :tradeline, amount: 100
      b = FactoryBot.create :tradeline, amount: 50
      FactoryBot.create :deposit, tradeline: a, amount: 30

      get :index, format: :json

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
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { get :index, format: :json }

      expect(queries.size).to eq(1)
    end
  end

  describe '#show' do
    let(:tradeline) { FactoryBot.create :tradeline }

    it 'responds with a 200' do
      get :show, params: { id: tradeline.id }, format: :json
      expect(response).to have_http_status(:ok)
    end

    # Pins down the JSON contract so changes to it are deliberate.
    it 'returns the tradeline attributes' do
      get :show, params: { id: tradeline.id }, format: :json

      expect(json.keys).to contain_exactly('id', 'name', 'amount', 'outstanding_balance', 'created_at', 'updated_at')
      expect(json).to include('id' => tradeline.id, 'name' => 'Some Credit Card')
    end

    it 'serializes amount as an exact decimal string' do
      get :show, params: { id: tradeline.id }, format: :json

      expect(json['amount']).to eq('3223.54')
    end

    it 'always formats money with two decimals' do
      tradeline.update!(amount: 18_500)

      get :show, params: { id: tradeline.id }, format: :json

      expect(json).to include('amount' => '18500.00', 'outstanding_balance' => '18500.00')
    end

    it 'subtracts all deposits, including future-dated ones, from the outstanding balance' do
      FactoryBot.create :deposit, tradeline: tradeline, amount: 200, deposit_date: Date.current - 7
      FactoryBot.create :deposit, tradeline: tradeline, amount: 404, deposit_date: Date.current + 14

      get :show, params: { id: tradeline.id }, format: :json

      expect(json['outstanding_balance']).to eq('2619.54')
    end

    it 'returns a null amount and balance when the tradeline has none' do
      tradeline.update!(amount: nil)

      get :show, params: { id: tradeline.id }, format: :json

      expect(json).to include('amount' => nil, 'outstanding_balance' => nil)
    end

    context 'if the loan is not found' do
      it 'responds with a 404' do
        get :show, params: { id: 1000 }, format: :json
        expect(response).to have_http_status(:not_found)
        expect(json['errors']).to contain_exactly(a_hash_including('code' => 'not_found'))
      end
    end
  end
end
