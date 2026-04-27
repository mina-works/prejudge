class ReviewIssue < ApplicationRecord
  belongs_to :review

  enum issue_type: {
    wrong_atmosphere: 0,
    wrong_target: 1,
    tone_mismatch: 2,
    too_much_or_little_info: 3,
    direction_issue: 4
  }
end
