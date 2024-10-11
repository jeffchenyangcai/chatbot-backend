class AddUserToConversations < ActiveRecord::Migration[6.0]
  def change
    # 添加 user_id 列到 conversations 表，并设置为外键
    add_reference :conversations, :user, null: false, foreign_key: true
  end
end
