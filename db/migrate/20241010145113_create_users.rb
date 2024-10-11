class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :username, null: false  # 用户名
      t.string :password_digest, null: false  # 用于存储加密后的密码

      t.timestamps
    end
    add_index :users, :username, unique: true  # 确保用户名唯一
  end
end
