class CreateComments < ActiveRecord::Migration[7.2]
  def change
    create_table :comments do |t|
      t.belongs_to :post, null: false, foreign_key: true
      t.belongs_to :user, null: false, foreign_key: true
      t.text :body

      t.timestamps
    end
  end
end
