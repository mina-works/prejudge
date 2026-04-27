class CreateReviewConditions < ActiveRecord::Migration[7.1]
  def change
    create_table :review_conditions do |t|
      t.references :artifact, null: false, foreign_key: true
      t.text :purpose, null: false
      t.integer :target, null: false
      t.integer :tone, null: false

      t.timestamps
    end
  end
end
