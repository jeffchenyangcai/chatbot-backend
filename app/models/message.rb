class Message < ApplicationRecord
  belongs_to :conversation
  #belongs_to :user  # 这会自动寻找 user_id 字段
  #
end
