class ChangeIsCollectedToIntegerInMessages < ActiveRecord::Migration[6.0]
  def change
    change_column :messages, :is_collected, :integer, default: 0, null: false
  end
end
