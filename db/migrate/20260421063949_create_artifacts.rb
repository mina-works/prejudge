class CreateArtifacts < ActiveRecord::Migration[7.1]
  def change
    create_table :artifacts do |t|
      t.string :title
      t.text :description
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.integer :current_round, null: false, default: 1
      t.datetime :review_deadline

      t.timestamps
    end
  end
end
