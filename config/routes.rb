Rails.application.routes.draw do
  # 開発環境でのメール確認用
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"

  namespace :api do
    namespace :v1 do
      # Authentication routes
      post :signin, to: "sessions#create"
      post :signup, to: "registrations#create"
      post :oauth_register, to: "registrations#oauth_register"
      get :validate_token, to: "sessions#validate_token"
      resources :password_resets, only: [ :create, :update ]

      resources :daily_logs do
        collection do
          get "date/:date", to: "daily_logs#show_by_date"
          get "date_range_30days", to: "daily_logs#by_date_range_30days"
          get "by_month", to: "daily_logs#by_month"
          post "morning", to: "daily_logs#morning"
          post "evening", to: "daily_logs#evening"
        end
        member do
          patch "self_score", to: "daily_logs#update_self_score"
        end
      end

      resources :users, only: [ :show, :update, :destroy ] do
        collection do
          get :default_prefecture
        end
      end
      resources :prefectures, only: [ :index, :show ]
      resources :suggestions, only: [ :index ]
      resources :concern_topics, only: [ :index ]
      resource :user_concern_topics, only: [ :show, :update ]

      resources :push_subscriptions, only: [ :create ] do
        collection do
          delete :by_endpoint, to: "push_subscriptions#destroy_by_endpoint"
        end
      end

      resources :reports, only: [] do
        collection do
          get :weekly
        end
      end

      # 24時間予報（Open-Meteo 時系列）の取得
      get :forecast, to: "forecasts#index"
    end
  end
end
