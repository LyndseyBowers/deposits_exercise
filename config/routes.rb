Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # JSON-only API: render Jbuilder templates even when the client sends no Accept header.
  defaults format: :json do
    resources :tradelines, only: %i[index show] do
      resources :deposits, only: %i[index show create]
    end
  end
end
