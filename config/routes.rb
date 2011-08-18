Notifiy::Application.routes.draw do
  devise_for :users, :path => "users", :path_names => { 
    :sign_in => 'login', 
    :sign_out => 'logout', 
    :password => 'secret', 
    :confirmation => 'verification', 
    :unlock => 'unblock', 
    :registration => 'register', 
    :sign_up => 'sign_up' 
  }
  resources :users
  
  post 'pusher/auth'

  resources :messages
  root :to => "home#index"
  
end
