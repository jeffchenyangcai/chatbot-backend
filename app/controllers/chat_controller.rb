# app/controllers/chat_controller.rb

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
    @current_conversation = Conversation.find_by(id: params[:id])

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

  # 删除会话
  def destroy
    conversation = current_user.conversations.find_by(id: params[:id])

    if conversation
      conversation.destroy
      render json: { message: '会话已删除' }, status: :ok
    else
      render json: { error: '未找到会话' }, status: :not_found
    end
  end

  # 获取所有会话 ID
  def conversations
    conversation_ids = current_user.conversations.pluck(:id)
    render json: { conversation_ids: conversation_ids }
  end

  private

  # 加载当前用户的所有会话
  def load_user_conversations
    @conversations = Conversation.where(user_id: @current_user.id)
  end

  # 保存当前会话的消息
  def save_current_conversation(conversation, messages)
    conversation.messages.create(messages)
  end

  # MOCK获取当前用户（假设存在用户ID 1）
  def current_user
    # 假设使用一个 ID 为 1 的假用户
    @current_user ||= User.find_or_create_by(id: 1) do |user|
      user.username = 'testuser'
      user.password_digest = 'password'  # 简单的密码，开发测试用
    end
  end

  # 模拟用户认证（跳过实际认证）
  def authenticate_user!
    unless current_user
      redirect_to login_path, alert: '请先登录'
    end
  end
end
