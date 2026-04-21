class CreateArtifactReviewers < ActiveRecord::Migration[7.1]
  def change
    create_table :artifact_reviewers do |t|
      t.references :artifact, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :role, null: false

      t.timestamps
    end

    add_index :artifact_reviewers, [:artifact_id, :user_id], unique: true
  end
end
