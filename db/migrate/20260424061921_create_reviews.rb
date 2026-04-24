class CreateReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :reviews do |t|
      t.references :artifact, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :result, null: false
      t.integer :round, null: false
      t.text :comment

      t.timestamps
    end

    add_index :reviews, [:artifact_id, :user_id, :round], unique: true
  end
end
