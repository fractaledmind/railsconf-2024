class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :screen_name, null: false, index: { unique: true }
      t.string :password_digest, null: false
      t.text :about
      t.datetime :last_seen_at
      t.integer :posts_count, default: 0

      t.timestamps
    end
  end
end
