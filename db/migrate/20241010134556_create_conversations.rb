class CreateConversations < ActiveRecord::Migration[6.0]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true  # 会话与用户相关联

      t.timestamps
    end
  end
end
