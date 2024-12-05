class Conversation < ApplicationRecord
  belongs_to :user  # 会话属于一个用户
  has_many :messages, dependent: :destroy  # 会话有多条消息

end
