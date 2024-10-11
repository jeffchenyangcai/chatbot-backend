class User < ApplicationRecord
  has_many :conversations, dependent: :destroy  # 每个用户可以有多个会话
end
