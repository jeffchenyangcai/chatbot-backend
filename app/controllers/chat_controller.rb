class ChatController < ApplicationController
  before_action :authenticate_user!  # 确保用户已登录
  before_action :load_user_conversations, only: [:index, :show]
  # 获取当前用户收藏的消息
  #
  def collect_message
    # 找到对应的消息
    message = Message.find_by(id: params[:id])
    puts message
    if message
      # 更新 is_collected 字段为 1
      if message.update(is_collected: params[:is_collected])
        puts "收藏成功"
        render json: { message: '收藏状态更新成功', data: message }, status: :ok
      else
        render json: { error: '更新失败，请重试' }, status: :unprocessable_entity
      end
    else
      render json: { error: '消息未找到' }, status: :not_found
    end
  end

  def collect
    # 获取当前用户的 ID
    user_id = current_user.id

    # 查询所有 is_collected = 1 且 user_id = 当前用户 ID 的消息
    collected_messages = Message.where(user_id: user_id, is_collected: true)

    # 对返回的消息进行编号，并返回符合条件的记录
    if collected_messages.empty?
      render json: { messages: [] }, status: :ok
    else
      # 为每个消息添加 answerId
      numbered_messages = collected_messages.each_with_index.map do |message, index|
        {
          collectId: index + 1,
          content: message.text,
          answerId:message.id,
        }
      end

      # 返回带有编号的消息
      render json: { messages: numbered_messages }, status: :ok
      puts numbered_messages
    end
  end
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
  require 'net/http'
  require 'json'

  def update
    conversation = current_user.conversations.find_by(id: params[:id], isDelete: false)
    @current_user ||= User.find_by(id: decoded_token['user_id'])

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
        user_id: decoded_token['user_id']
      )
    end

    # 获取用户消息的文本内容
    user_message_text = messages.last[:text]

    # ZhipuAI API的URL
    url = URI("https://open.bigmodel.cn/api/paas/v4/chat/completions")

    # 构建请求头
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "TODO"  # 请填写您自己的APIKey
    }

    # 构建请求体
    request_body = {
      model: "glm-4-flash",  # 请填写您要调用的模型名称
      messages: [
        { role: "user", content: user_message_text }
      ]
    }.to_json

    # 发送HTTP POST请求
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(url, headers)
    request.body = request_body

    response = http.request(request)

    # 解析API响应
    response_body = JSON.parse(response.body)

    # 获取生成的回复
    chatbot_response = response_body['choices'][0]['message']['content']

    # 创建 Chatbot 回复消息并保存到数据库
    chatbot_message = conversation.messages.create(
      user: 'Chatbot',
      text: chatbot_response,
      created_at: Time.now,
      updated_at: Time.now,
      user_id: decoded_token['user_id']
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