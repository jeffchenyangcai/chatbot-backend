class CreateMessages < ActiveRecord::Migration[6.0]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true  # 消息与会话相关联
      t.references :user, null: false, foreign_key: true  # 消息由用户发送
      t.string :text  # 消息内容

      t.timestamps
    end
  end
end
