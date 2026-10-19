require 'rails_helper'

# The scaffolded `resources :tradelines` exposed these with no controller actions behind them.
RSpec.describe 'Tradeline routes', type: :routing do
  it { expect(get: '/tradelines').to route_to('tradelines#index', format: :json) }
  it { expect(get: '/tradelines/1').to route_to('tradelines#show', id: '1', format: :json) }

  it { expect(post: '/tradelines').not_to be_routable }
  it { expect(patch: '/tradelines/1').not_to be_routable }
  it { expect(delete: '/tradelines/1').not_to be_routable }
  it { expect(delete: '/tradelines/1/deposits/1').not_to be_routable }
end
