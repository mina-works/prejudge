class ArtifactReviewer < ApplicationRecord
  belongs_to :artifact
  belongs_to :user

  enum role: {
    reviewer: 0,
    approver: 1
  }

  validates :role, presence: true
end
