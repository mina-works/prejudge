class ArtifactReviewer < ApplicationRecord
  belongs_to :artifact
  belongs_to :user

  enum role: {
    reviewer: 0,
    approver: 1
  }

  validates :role, presence: true

  # 同じArtifactに同じユーザーを重複登録できない
  validates :user_id,
            uniqueness: {
              scope: :artifact_id
            }
end
