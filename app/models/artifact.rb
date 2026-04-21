class Artifact < ApplicationRecord
  belongs_to :creator, class_name: "User"

  enum status: {
    draft: 0,
    reviewing: 1,
    revision_required: 2,
    reviewed: 3
  }
end
