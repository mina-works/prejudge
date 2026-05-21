class ReviewIssue < ApplicationRecord
  belongs_to :review

  enum issue_type: {
    wrong_atmosphere: 0,
    wrong_target: 1,
    tone_mismatch: 2,
    too_much_or_little_info: 3,
    direction_issue: 4
  }

  # reviewがokの場合はissueを持てない
  validate :review_must_not_be_ok

  private

  def review_must_not_be_ok
    return unless review&.ok?

    errors.add(:base, "ok reviewにはissueを登録できません")
  end
end
