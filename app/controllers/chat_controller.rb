class ChatController < ApplicationController
  def index
    Rails.logger.info "Params: #{params.inspect}"  # 输出所有参数

    # 如果 session[:messages] 为空，初始化为一个空数组
    session[:messages] ||= [{ user: 'Chatbot', text: '你好，请问我问题：' }]

    # 使用 session[:messages] 来持久化消息
    @messages = session[:messages]

    if params[:message].present?
      Rails.logger.info "Received message: #{params[:message]}"

      # 添加用户的消息到 @messages
      @messages << { user: 'User', text: params[:message] }

      # 模拟调用 ChatGPT API 并返回固定的回复
      @messages << { user: 'Chatbot', text: '这是我的固定回复' }

      # 将 @messages 保存到 session
      session[:messages] = @messages

      Rails.logger.info "Messages: #{@messages.inspect}"
    end
  end
end
