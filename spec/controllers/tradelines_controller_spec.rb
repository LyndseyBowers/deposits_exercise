require 'rails_helper'

RSpec.describe TradelinesController, type: :controller do
  let(:json) { JSON.parse(response.body) }

  describe '#index' do
    it 'responds with a 200' do
      get :index

      expect(response).to have_http_status(:ok)
    end

    it 'returns an empty array when there are no tradelines' do
      get :index

      expect(json).to eq([])
    end

    it 'returns every tradeline' do
      FactoryBot.create :tradeline, name: 'Card A'
      FactoryBot.create :tradeline, name: 'Card B', amount: 100

      get :index

      expect(json.map { |t| t['name'] }).to contain_exactly('Card A', 'Card B')
    end
  end

  describe '#show' do
    let(:tradeline) { FactoryBot.create :tradeline }

    it 'responds with a 200' do
      get :show, params: { id: tradeline.id }
      expect(response).to have_http_status(:ok)
    end

    # Pins down the current JSON contract so changes to it are deliberate.
    it 'returns the tradeline attributes' do
      get :show, params: { id: tradeline.id }

      expect(json.keys).to contain_exactly('id', 'name', 'amount', 'created_at', 'updated_at')
      expect(json).to include('id' => tradeline.id, 'name' => 'Some Credit Card')
    end

    it 'serializes amount as an exact decimal string' do
      get :show, params: { id: tradeline.id }

      expect(json['amount']).to eq('3223.54')
    end

    it 'returns a null amount when the tradeline has none' do
      tradeline.update!(amount: nil)

      get :show, params: { id: tradeline.id }

      expect(json['amount']).to be_nil
    end

    context 'if the loan is not found' do
      it 'responds with a 404' do
        get :show, params: { id: 1000 }
        expect(response).to have_http_status(:not_found)
        expect(json['errors']).to contain_exactly(a_hash_including('code' => 'not_found'))
      end
    end
  end
end
