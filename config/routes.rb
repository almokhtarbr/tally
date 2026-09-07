Rails.application.routes.draw do
  match "/api/v1/*path", to: proc { [ 204, {}, [ "" ] ] }, via: :options

  namespace :api do
    namespace :v1 do
      post "track", to: "track#create"
      post "batch", to: "batch#create"
      post "identify", to: "identify#create"
      post "alias", to: "alias#create"

      namespace :queries do
        get "event_counts", to: "/api/v1/queries#event_counts"
        get "top_events", to: "/api/v1/queries#top_events"
        get "user_timeline", to: "/api/v1/queries#user_timeline"
      end
    end
  end

  get "setup", to: "setup#new", as: :setup
  post "setup", to: "setup#create"

  get "login", to: "sessions#new", as: :new_session
  post "login", to: "sessions#create", as: :session
  delete "logout", to: "sessions#destroy", as: :destroy_session

  resources :password_resets, only: %i[new create], path: "reset-password"
  get "reset-password/:token", to: "password_resets#edit",   as: :edit_password_reset
  patch "reset-password/:token", to: "password_resets#update", as: :password_reset

  get   "invitations/:token", to: "invitations#edit",   as: :edit_invitation
  patch "invitations/:token", to: "invitations#update", as: :invitation

  resources :users, except: [ :show ] do
    member do
      post :resend_invitation
    end
    collection do
      get :edit_profile
      patch :update_profile
    end
  end

  root "dashboard#index"

  # Public read-only dashboard, reached by a project's share token — no login.
  get "s/:token", to: "public_dashboards#show", as: :public_dashboard

  resources :projects, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    member do
      post :share
      delete :unshare
      get :api_keys
      get :errors
      get :error_detail
      get :event_explorer
      get :user_profile
      get :funnels
      get :retention
      get :users
      get :export_csv
      get :user_paths
      get :forms
      get :anomalies
    end

    resources :segments
    resources :saved_reports, only: [ :index, :show, :create, :destroy ]
    resources :dashboards, only: [ :index, :show, :create, :destroy ] do
      resources :dashboard_widgets, only: [ :create, :update, :destroy ]
    end
    resources :webhooks do
      member do
        post :toggle
        post :test
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
