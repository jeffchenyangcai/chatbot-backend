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

      # 通过 respond_to 返回不同的格式，支持 HTML 和 JS
      respond_to do |format|
        format.html { redirect_to chat_path }  # 如果是 HTML 请求，重定向到聊天页面
        format.js   # 如果是 Ajax 请求，渲染 JS 文件
      end
    end
  end
end
