class UserController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:login, :register, :out_login]

  def login
    user = User.find_by(username: params[:username])
    puts "User found: #{user.inspect}" if user

    if user && user.authenticate(params[:password])
      puts "Password matched"
      render json: { status: 'ok', message: '登录成功', data: { userId: user.id, username: user.username, token: generate_token(user.id) } }, status: :ok
    else
      puts "Password did not match"
      render json: { status: 'error', message: '用户名或密码错误' }, status: :unauthorized
    end
  end

  def register
    # 获取前端传来的参数
    username = params[:username]
    password = params[:password]
    confirm_password = params[:confirmPassword]
    auto_login = params[:autoLogin]
    type = params[:type]

    # 验证密码是否一致
    if password != confirm_password
      render json: { error: "Passwords do not match" }, status: :unprocessable_entity
      return
    end

    # 创建新用户
    user = User.new(username: username, password: password, password_confirmation: confirm_password)

    # 保存用户到数据库
    if user.save
      # 如果 auto_login 为 true，可以在这里处理自动登录逻辑
      if auto_login
        # 这里可以生成一个 session 或者 token 来实现自动登录
        # session[:user_id] = user.id
      end

      render json: { message: "User registered successfully", user: user }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def out_login
    # 你可以在这里添加任何你需要在退出登录时执行的逻辑
    # 例如，清除用户的会话或令牌
    render json: { status: 'ok', message: '退出登录成功' }, status: :ok
  end

  private

  def generate_token(user_id)
    payload = { user_id: user_id }
    JWT.encode(payload, Rails.application.secret_key_base)
  end
end