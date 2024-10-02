class ChatController < ApplicationController
  before_action :load_conversations, only: [:index, :show]

  # 主聊天页面
  def index
    session[:conversations] ||= []
    session[:current_conversation_id] ||= 0 # 默认值为 0

    # 获取当前会话的消息
    @messages = session[:conversations][session[:current_conversation_id]] || [{ user: 'Chatbot', text: '你好，请问我问题：' }]

    if params[:message].present?
      user_message = { user: 'User', text: params[:message] }
      chatbot_message = { user: 'Chatbot', text: '这是我的固定回复' }

      # 将新消息加入当前会话
      @messages << user_message
      @messages << chatbot_message

      # 保存当前会话
      save_current_conversation(@messages)  # 传递当前会话的消息

      # 传递两条新消息给视图层
      @new_messages = [user_message, chatbot_message]

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to chat_path }  # 兼容传统 HTML 提交
      end
    end
  end

  # 显示特定的会话
  def show
    conversation_id = params[:id].to_i
    session[:current_conversation_id] = conversation_id # 更新当前会话ID
    @messages = session[:conversations][conversation_id] || [] # 获取当前会话的消息

    respond_to do |format|
      format.json { render json: { messages: @messages } }
      format.html { render :index }  # 允许用户从 HTML 直接访问
    end
  end

  # 创建新会话
  def create
    session[:conversations] ||= []
    # 创建一个新的会话，默认有一条消息
    new_conversation = [{ user: 'Chatbot', text: '你好，请问我问题：' }]
    session[:conversations] << new_conversation

    # 返回最新的会话 ID
    new_conversation_id = session[:conversations].size - 1
    session[:current_conversation_id] = new_conversation_id

    # 重定向到新的会话
    respond_to do |format|
      format.json { render json: { id: new_conversation_id, messages: new_conversation }, status: :created }
    end
  end

  # 删除会话
  def destroy
    conversation_id = params[:id].to_i

    if session[:conversations] && session[:conversations][conversation_id]
      session[:conversations].delete_at(conversation_id)  # 删除会话

      # 如果删除的是当前会话，则更新当前会话 ID
      if session[:current_conversation_id] == conversation_id
        session[:current_conversation_id] = [0, session[:conversations].size - 1].min  # 重置为第一个会话
      end

      render json: { message: '会话已删除' }, status: :ok
    else
      render json: { error: '未找到会话' }, status: :not_found
    end
  end

  private

  # 加载所有会话
  def load_conversations
    session[:conversations] ||= []
    @conversations = session[:conversations]
  end

  # 保存当前会话
  def save_current_conversation(messages)
    # 更新当前会话的消息
    session[:conversations][session[:current_conversation_id]] = messages.dup
  end
end
