class Artifact < ApplicationRecord
  belongs_to :creator, class_name: "User"

  has_many :artifact_reviewers, dependent: :destroy
  has_many :reviews, dependent: :destroy

  has_one :review_condition, dependent: :destroy

  
  enum status: {
    draft: 0,
    reviewing: 1,
    revision_required: 2,
    reviewed: 3
  }
end
