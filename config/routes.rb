Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"

  root 'chat#index'

  # 获取所有的 conversationid
  get 'api/conversations', to: 'chat#conversations'

  # 定义聊天页面的主路由
  get 'chat', to: 'chat#index'

  # 定义根据会话 ID 显示特定对话记录的路由
  get 'api/chat/:id', to: 'chat#show', as: 'conversation'
  # 在视图中你可以用 conversation_path(1) 来生成 /conversations/1 的链接。

  # 添加一个 POST 路由用于发送消息
  post 'chat', to: 'chat#index'

  # 添加用于创建新会话的路由
  post 'chat/new', to: 'chat#create', as: 'new_conversation'

  delete 'chat/:id', to: 'chat#destroy'
end
