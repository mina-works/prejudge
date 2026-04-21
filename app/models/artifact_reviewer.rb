class ArtifactReviewer < ApplicationRecord
  belongs_to :artifact
  belongs_to :user
end
