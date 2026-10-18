require 'rails_helper'

RSpec.describe 'Deposits', type: :request do
  let(:tradeline) { FactoryBot.create :tradeline, amount: 100 }
  let(:json) { JSON.parse(response.body) }
  let(:error_codes) { json['errors'].map { |e| e['code'] } }

  def post_deposit(body, tradeline_id: tradeline.id)
    post "/tradelines/#{tradeline_id}/deposits", params: body.to_json,
                                                 headers: { 'Content-Type' => 'application/json' }
  end

  describe 'GET /tradelines/:tradeline_id/deposits' do
    it "returns the tradeline's deposits ordered by date" do
      later = FactoryBot.create :deposit, tradeline: tradeline, amount: 10, deposit_date: Date.current + 30
      sooner = FactoryBot.create :deposit, tradeline: tradeline, amount: 20, deposit_date: Date.current + 1
      FactoryBot.create :deposit, amount: 5 # belongs to another tradeline

      get "/tradelines/#{tradeline.id}/deposits"

      expect(response).to have_http_status(:ok)
      expect(json.map { |d| d['id'] }).to eq([sooner.id, later.id])
    end

    it 'returns an empty array when there are no deposits' do
      get "/tradelines/#{tradeline.id}/deposits"

      expect(json).to eq([])
    end

    it 'returns 404 for an unknown tradeline' do
      get '/tradelines/0/deposits'

      expect(response).to have_http_status(:not_found)
      expect(error_codes).to eq(['not_found'])
    end
  end

  describe 'GET /tradelines/:tradeline_id/deposits/:id' do
    let(:deposit) { FactoryBot.create :deposit, tradeline: tradeline, amount: 25, deposit_date: Date.new(2026, 11, 1) }

    it 'returns the deposit' do
      get "/tradelines/#{tradeline.id}/deposits/#{deposit.id}"

      expect(response).to have_http_status(:ok)
      expect(json).to include(
        'id' => deposit.id,
        'tradeline_id' => tradeline.id,
        'amount' => '25.00',
        'deposit_date' => '2026-11-01'
      )
    end

    it "returns 404 for another tradeline's deposit" do
      other = FactoryBot.create :deposit

      get "/tradelines/#{tradeline.id}/deposits/#{other.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /tradelines/:tradeline_id/deposits' do
    it 'creates a deposit and returns 201' do
      post_deposit({ deposit: { amount: '40.50', deposit_date: '2026-12-01' } })

      expect(response).to have_http_status(:created)
      expect(response.location).to end_with("/tradelines/#{tradeline.id}/deposits/#{json['id']}")
      expect(json).to include('amount' => '40.50', 'deposit_date' => '2026-12-01')
      expect(tradeline.outstanding_balance).to eq(BigDecimal('59.50'))
    end

    it 'accepts unwrapped JSON params' do
      post_deposit({ amount: 10, deposit_date: '2026-12-01' })

      expect(response).to have_http_status(:created)
    end

    it 'returns 422 with error codes and messages when the deposit exceeds the balance' do
      post_deposit({ deposit: { amount: 100.01, deposit_date: '2026-12-01' } })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json['errors']).to contain_exactly(
        a_hash_including('attribute' => 'amount', 'code' => 'exceeds_outstanding_balance',
                         'message' => a_string_including('100.00'))
      )
      expect(tradeline.deposits.count).to eq(0)
    end

    it 'returns every validation error at once' do
      post_deposit({ deposit: { amount: -1, deposit_date: '' } })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_codes).to contain_exactly('greater_than', 'blank')
    end

    it 'returns 422 for a tradeline with no amount' do
      tradeline.update!(amount: nil)

      post_deposit({ deposit: { amount: 10, deposit_date: '2026-12-01' } })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(error_codes).to eq(['no_amount'])
    end

    it 'returns 400 when the deposit params are missing' do
      post_deposit({})

      expect(response).to have_http_status(:bad_request)
      expect(error_codes).to eq(['parameter_missing'])
    end

    it 'returns 404 for an unknown tradeline' do
      post_deposit({ deposit: { amount: 10, deposit_date: '2026-12-01' } }, tradeline_id: 0)

      expect(response).to have_http_status(:not_found)
    end
  end
end
