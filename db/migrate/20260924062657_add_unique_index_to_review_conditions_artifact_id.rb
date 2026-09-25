class AddUniqueIndexToReviewConditionsArtifactId < ActiveRecord::Migration[7.1]
  def change
    # 既存の通常indexを削除する
    remove_index :review_conditions, :artifact_id

    # 1つのArtifactに複数のReviewConditionが登録されないようにする
    add_index :review_conditions, :artifact_id, unique: true
  end
end