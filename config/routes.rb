Rails.application.routes.draw do
  devise_for :users
  root "home#index"
  get "home/index"
  
  # Admin routes
  get "admin/dashboard", to: "admin#dashboard", as: :admin_dashboard
  get "admin/users", to: "admin#users", as: :admin_users
  patch "admin/users/:id/toggle_admin", to: "admin#toggle_admin", as: :admin_toggle_admin
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
