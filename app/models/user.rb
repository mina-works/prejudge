class User < ApplicationRecord
  # associations
  has_many :artifacts, foreign_key: :creator_id
  has_many :artifact_reviewers
  has_many :reviews, dependent: :nullify

  # validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
