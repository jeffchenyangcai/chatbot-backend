class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.string :user
      t.string :text
      t.references :conversation, null: false, foreign_key: true

      t.timestamps
    end
  end
end
