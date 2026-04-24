class Review < ApplicationRecord
  belongs_to :artifact
  belongs_to :user
end
