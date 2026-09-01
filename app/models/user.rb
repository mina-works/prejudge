class User < ApplicationRecord
  # 現在利用可能なUserだけを取得する
  scope :active, -> { where(active: true) }
  
  # 作成した成果物があるUserは削除しない
  has_many :artifacts, 
            foreign_key: :creator_id,
            dependent: :restrict_with_error

  # 担当履歴を保護するため削除しない
  has_many :artifact_reviewers,
            dependent: :restrict_with_error

  # レビュー履歴を保護するため削除しない
  has_many :reviews,
            dependent: :restrict_with_error

   # Reviewerとしての担当情報を取得する
  has_many :reviewer_assignments,
           -> { reviewer },
           class_name: "ArtifactReviewer"

  # Reviewerとして担当しているArtifactを取得する
  has_many :reviewer_artifacts,
           through: :reviewer_assignments,
           source: :artifact

  # Approverとしての担当情報を取得する
  has_many :approver_assignments,
          -> { approver },
          class_name: "ArtifactReviewer"

  # Approverとして担当しているArtifactを取得する
  has_many :approver_artifacts,
          through: :approver_assignments,
          source: :artifact

  has_secure_password

  # validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
