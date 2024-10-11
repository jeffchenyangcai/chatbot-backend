class AddUserIdToMessages < ActiveRecord::Migration[6.0]
  def change
    add_column :messages, :user_id, :integer
    add_foreign_key :messages, :users
  end
end
