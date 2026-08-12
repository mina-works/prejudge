Rails.application.routes.draw do
  get 'sessions/new'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  
  resource :session,
            only: %i[new create destroy]
  
  resources :artifacts do
    member do
      patch :submit
      patch :resubmit
    end
    
    resources :reviews, only: [:index, :new, :create, :show]
  end
end
