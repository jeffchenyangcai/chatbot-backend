class ChatController < ApplicationController
  before_action :authenticate_user!  # 确保用户已登录
  before_action :load_user_conversations, only: [:index, :show]

  def index
    # 默认加载显示最近的一次会话
    @current_conversation = @conversations.last

    @first_conversation_id = @conversations.minimum(:id) # 获取最小的 conversation.id

    # 如果有当前会话，加载会话中的所有消息
    @messages = @current_conversation&.messages || [{ user: 'Chatbot', text: '你好，请问有什么问题？' }]

    # 如果用户发送了新消息
    if params[:message].present?
      # 创建用户消息
      user_message = @current_conversation.messages.create(user: current_user.username, text: params[:message])

      # 创建 Chatbot 回复消息
      chatbot_message = @current_conversation.messages.create(user: 'Chatbot', text: '这是我的固定回复')

      # 将新消息传递给视图层
      @new_messages = [user_message, chatbot_message]

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to chat_path }
      end
    end
  end

  # 显示特定会话
  def show
    @current_conversation = Conversation.find_by(id: params[:id], isDelete: false)

    if @current_conversation.nil?
      render json: { error: '未找到会话' }, status: :not_found
      return
    end

    @messages = @current_conversation.messages

    render json: { messages: @messages }
  end

  # 创建新会话
  def create
    new_conversation = current_user.conversations.create
    new_conversation.messages.create(user: 'Chatbot', text: '这是我的固定回复')

    render json: { id: new_conversation.id, messages: new_conversation.messages }, status: :created
  end

  # 删除会话（标记为删除）
  def destroy
    conversation = current_user.conversations.find_by(id: params[:id])

    if conversation
      conversation.update(isDelete: true)
      render json: { message: '会话已标记为删除' }, status: :ok
    else
      render json: { error: '未找到会话' }, status: :not_found
    end
  end

  # 获取所有会话 ID
  def conversations
    conversation_ids = current_user.conversations.where(isDelete: false).pluck(:id)
    render json: { conversation_ids: conversation_ids }
  end

  # 更新会话（添加新消息）
  def update
    conversation = current_user.conversations.find_by(id: params[:id], isDelete: false)

    if conversation.nil?
      render json: { error: '未找到会话' }, status: :not_found
      return
    end

    # 解析请求中的消息数据
    messages = params[:messages]

    if messages.nil? || messages.empty?
      render json: { error: '消息不能为空' }, status: :unprocessable_entity
      return
    end

    # 创建新消息并保存到数据库
    new_messages = messages.map do |message|
      conversation.messages.create(
        user: message[:user],
        text: message[:text],
        created_at: message[:created_at],
        updated_at: message[:updated_at],
        user_id: message[:user_id]
      )
    end

    # 创建 Chatbot 回复消息
    chatbot_message = conversation.messages.create(
      user: 'Chatbot',
      text: '这是我的固定回复',
      created_at: Time.now,
      updated_at: Time.now,
      user_id: nil
    )

    # 返回新创建的消息和 Chatbot 回复消息
    render json: { messages: [chatbot_message] }, status: :ok
  end

  private

  # 加载当前用户的所有会话
  def load_user_conversations
    @conversations = Conversation.where(user_id: current_user.id, isDelete: false)
  end

  # 保存当前会话的消息
  def save_current_conversation(conversation, messages)
    conversation.messages.create(messages)
  end

  # 获取当前用户
  def current_user
    @current_user ||= User.find_by(id: decoded_token['user_id'])
  end

  # 解析 JWT 令牌
  def decoded_token
    token = request.headers['Authorization']&.split(' ')&.last
    JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256').first
  rescue JWT::DecodeError
    {}
  end

  # 用户认证
  def authenticate_user!
    unless current_user
      render json: { error: '请先登录' }, status: :unauthorized
    end
  end
end