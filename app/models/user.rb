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

  has_secure_password

  # validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
