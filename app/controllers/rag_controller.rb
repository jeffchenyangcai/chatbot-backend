class RagController < ApplicationController
  before_action :authenticate_user! # 确保用户已登录
  def history
    knowledge_base_id = params[:knowledge_base_id]

    # 参数校验
    if knowledge_base_id.blank?
      render json: { success: false, message: '知识库ID不能为空' }, status: :bad_request
      return
    end

    # 确保知识库存在且属于当前用户
    knowledge_base = current_user.knowledge_bases.find_by(id: knowledge_base_id)
    if knowledge_base.nil?
      render json: { success: false, message: '知识库不存在或无权限访问' }, status: :not_found
      return
    end

    # 获取历史对话记录
    messages = ChatHistory.where(
      knowledge_base_id: knowledge_base_id,
      user_id: current_user.id
    ).order(:created_at)

    render json: {
      success: true,
      messages: messages.map do |msg|
        {
          id: msg.id,
          sender: msg.sender,
          message: msg.message,
          created_at: msg.created_at
        }
      end
    }
  rescue => e
    Rails.logger.error("获取历史对话失败: #{e.message}")
    render json: { success: false, message: '获取历史对话失败，请稍后再试' }, status: 500
  end
  # RAG 查询接口
  def query
    knowledge_base_id = params[:knowledge_base_id]
    question = params[:question]
    mode = params[:mode] # 'context' 或 'rag'
    user_id = current_user.id
    # 参数校验
    if knowledge_base_id.blank? || question.blank? || mode.blank?
      render json: { success: false, message: '缺少必要参数' }, status: :bad_request
      return
    end

    # 获取历史上下文
    context = ChatHistory.where(
      knowledge_base_id: knowledge_base_id,
      user_id: current_user.id
    ).order(:created_at).last(10) # 最近10条对话

    # 处理上下文
    prompt_context = context.map { |msg| "#{msg.sender}: #{msg.message}" }.join("\n")

    # 调用大模型生成回答
    if mode == 'rag'
      # RAG 模式：调用大模型时，添加额外的信息
      additional_context = generate_rag_additional_context(user_id,knowledge_base_id,question)
      full_prompt_rag = "#{prompt_context}\nSystem: #{additional_context}\nUser: #{question}"
      rag_answer = generate_from_llm(full_prompt_rag)

      # 上下文模式回答
      full_prompt_context = "#{prompt_context}\nUser: #{question}"
      context_answer = generate_from_llm(full_prompt_context)

      # 存储用户问题和模型回答
      ChatHistory.create!(user_id: current_user.id, knowledge_base_id: knowledge_base_id, sender: 'User', message: question)
      ChatHistory.create!(user_id: current_user.id, knowledge_base_id: knowledge_base_id, sender: 'Assistant', message: rag_answer)

      # 返回 RAG 和上下文模式的回答
      render json: { success: true, ragAnswer: rag_answer, contextAnswer: context_answer }
    else
      # 上下文模式：仅使用上下文和用户问题
      full_prompt_context = "#{prompt_context}\nUser: #{question}"
      context_answer = generate_from_llm(full_prompt_context)

      # 存储用户问题和模型回答
      ChatHistory.create!(user_id: current_user.id, knowledge_base_id: knowledge_base_id, sender: 'User', message: question)
      ChatHistory.create!(user_id: current_user.id, knowledge_base_id: knowledge_base_id, sender: 'Assistant', message: context_answer)

      # 返回仅上下文模式的回答
      render json: { success: true, contextAnswer: context_answer }
    end
  rescue => e
    Rails.logger.error("RAG 查询失败: #{e.message}")
    render json: { success: false, message: '查询失败，请稍后再试' }, status: 500
  end


  private

  # 模拟生成 RAG 模式下的额外信息
  def generate_rag_additional_context(user_id, knowledge_base_id, question)
    # 1. 构建请求地址和参数
    fastapi_url = URI("http://127.0.0.1:8002/search")
    headers = { 'Content-Type' => 'application/json' }
    request_body = {
      user_id: user_id,
      knowledge_base_id: knowledge_base_id,
      question: question
    }.to_json

    # 2. 发起 HTTP 请求到 FastAPI
    begin
      http = Net::HTTP.new(fastapi_url.host, fastapi_url.port)
      request = Net::HTTP::Post.new(fastapi_url, headers)
      request.body = request_body

      response = http.request(request)

      # 3. 处理返回结果
      if response.code.to_i == 200
        response_json = JSON.parse(response.body)

        # FastAPI返回示例:
        # {
        #   "results": [
        #     { "distance": 0.01, "sentence_id": "123", "sentence": "相关内容" },
        #     ...
        #   ]
        # }
        sentences_str = response_json["results"]

        # 如果没检索到内容
        if sentences_str.empty?
          return "未检索到相关内容。"
        end

        return "以下是从知识库 #{knowledge_base_id} 中检索到的相关信息:\n\n#{sentences_str}"
      else
        Rails.logger.error("调用 FastAPI 失败: #{response.code} - #{response.body}")
        return "无法获取额外上下文 (FastAPI 调用异常)。"
      end
    rescue => e
      Rails.logger.error("调用 FastAPI 时发生错误: #{e.message}")
      return "无法获取额外上下文 (FastAPI 调用出现异常)。"
    end
  end

  def generate_from_llm(prompt)
    # ZhipuAI API的URL
    url = URI("https://open.bigmodel.cn/api/paas/v4/chat/completions")

    # 构建请求头
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "8ca9dd8f25c35dbb7c68511c2a718f07.EWWMOmKkVNQyb77s"  # 替换为您的 ZhipuAI API Key
    }

    # 构建请求体
    request_body = {
      model: "glm-4-flash",  # 模型名称，确保与 ZhipuAI 支持的模型一致
      messages: [
        { role: "user", content: prompt }
      ]
    }.to_json

    begin
      # 发送HTTP POST请求
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(url, headers)
      request.body = request_body

      response = http.request(request)

      # 解析API响应
      if response.code.to_i == 200
        response_body = JSON.parse(response.body)

        # 获取生成的回复
        chatbot_response = response_body.dig('choices', 0, 'message', 'content')
        return chatbot_response || "对不起，我没有生成有效的回答。"
      else
        Rails.logger.error("ZhipuAI API 请求失败: #{response.code} #{response.body}")
        return "对不起，无法生成回答，请稍后重试。"
      end
    rescue => e
      Rails.logger.error("调用 ZhipuAI API 时发生错误: #{e.message}")
      return "对不起，生成回答时发生错误，请稍后重试。"
    end
  end

  # 获取历史对话接口


  private

  def current_user
    user_id = decoded_token['user_id']
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
  private

  def fetch_knowledge_base_content(knowledge_base_id)
    # 验证知识库是否属于当前用户
    knowledge_base = KnowledgeBase.find_by(id: knowledge_base_id, user_id: current_user.id)
    unless knowledge_base
      raise ActiveRecord::RecordNotFound, "知识库不存在或您无权访问"
    end

    knowledge_base.files.pluck(:file_content).join("\n")
  end

  def generate_class_name(user_id, knowledge_base_id)
    "Text_#{user_id}_#{knowledge_base_id}_class"
  end

  def save_chat_history(user_id, knowledge_base_id, sender, message, type = nil)
    ChatHistory.create!(
      user_id: user_id,
      knowledge_base_id: knowledge_base_id,
      sender: sender,
      message: message,
      type: type,
      created_at: Time.now
    )
  end
end
