class Review < ApplicationRecord
  belongs_to :artifact
  belongs_to :user

  enum result: {
    ok: 0,
    uneasy: 1,
    ng: 2
  }

  before_validation :set_round
  validate :prevent_edit_past_review, on: :update

  private

  def set_round
    self.round ||= artifact&.current_round
  end

  def prevent_edit_past_review
    if round < artifact.current_round
      errors.add(:base, "過去ラウンドのレビューは編集できません")
    end
  end
end
