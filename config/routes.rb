Rails.application.routes.draw do
  mount RailsAdmin::Engine => "/admin", as: "rails_admin"
  mount MissionControl::Jobs::Engine, at: "/jobs"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "events#index"

  resources :events, only: %i[new create] do
    post :extract, on: :collection
  end

  get "feed" => "events#feed", as: :feed, defaults: { format: "rss" }

  resource :bookmarks, only: %i[show update] do
    post :merge
    get :qr
  end

  get "status" => "status#show", as: :status
  post "status/refetch" => "status#refetch", as: :status_refetch
  get "impressum" => "pages#imprint", as: :imprint
  get "datenschutz" => "pages#privacy", as: :privacy
end
