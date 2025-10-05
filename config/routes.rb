Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Hello world endpoint
  get "hello" => "hello#index"

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      # Authentication routes
      post :signin, to: 'sessions#create'
      post :refresh, to: 'sessions#refresh'
      post :signup, to: 'registrations#create'
      post :oauth_register, to: 'registrations#oauth_register'

      resources :daily_logs do
        collection do
          get 'date/:date', to: 'daily_logs#show_by_date'
          get 'date_range_30days', to: 'daily_logs#by_date_range_30days'
        end
        member do
          patch 'self_score', to: 'daily_logs#update_self_score'
        end
      end

      resources :users, only: [:show, :update]
      resources :symptoms, only: [:index, :show]
      resources :prefectures, only: [:index, :show]
      resources :suggestions, only: [:index]
    end
  end
end
