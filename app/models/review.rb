class Review < ApplicationRecord
  belongs_to :artifact
  belongs_to :user

  # reviewに紐づく違和感選択
  has_many :review_issues, dependent: :destroy


  enum result: {
    ok: 0,
    uneasy: 1,
    ng: 2
  }


  validates :result, presence: true
  validates :user_id,
          uniqueness: {
            scope: [:artifact_id, :round],
            message: :already_reviewed_this_round
          }
  validates :round,
          presence: true,
          numericality: {
            only_integer: true,
            greater_than: 0
          }


  # review作成時点のartifact.current_roundを保持する
  # 過去review履歴を固定保存するため、初回のみセットする
  before_validation :set_round


  # approverのreview結果に応じてartifact.statusを更新する
  # reviewerのreviewはstatusに影響しない
  after_create :update_artifact_status


  # review履歴保護のため、過去roundのreview編集を禁止する
  validate :prevent_edit_past_review, on: :update


  # ReviewerまたはApproverでなければレビューできない
  validate :user_must_be_review_member


  # reviewerはng（差し戻し）不可
  # 最終的な差し戻し権限はapproverのみが持つ
  validate :reviewer_cannot_select_ng


  # Artifactが pending_review か reviewing のときレビューできる
  validate :artifact_must_be_reviewable


  # 選択肢生成用：result(enum)を日本語ラベルに変換する
  def self.result_label(result)
    I18n.t(
      "enums.review.result.#{result}"
    )
  end

  # 表示用：result(enum)を日本語ラベルに変換する
  def result_label
    self.class.result_label(result)
  end


  # ReviewIssue を作る
  def create_review_issues(issue_types)
    issue_types&.each do |issue_type|
      review_issues.create!(
        issue_type: issue_type
      )
    end
  end

  # Review本体とReviewIssueをトランザクション内で保存する
  def save_with_review_issues!(issue_types)
    self.class.transaction do
      save!
      create_review_issues!(issue_types)
    end
  end

  private

  def set_round
    self.round ||= artifact&.current_round
  end

  def prevent_edit_past_review
    # 比較できない場合は終了する
    return if round.blank? || artifact.blank?

    return unless round < artifact.current_round
      errors.add(:base, I18n.t("errors.review.prevent_edit_past_review"))
  end

  # このreviewを行ったuserが、
  # 対象artifactにおけるapproverか判定する
  def approver?
    artifact.artifact_reviewers.exists?(
      user_id: user_id,
      role: :approver
    )
  end

  def reviewer_cannot_select_ng
    return unless ng?
    return if approver?

    errors.add(:result,  I18n.t("errors.review.reviewer_cannot_select_ng"))
  end

  def update_artifact_status
    artifact.update_status_after_review!
  end

  def user_must_be_review_member
    return if artifact.blank? || user.blank?

    assigned = artifact.artifact_reviewers.exists?(user_id: user_id)
    return if assigned

    errors.add(
      :user,
      I18n.t("errors.review.user_must_be_review_member")
    )
  end

  def artifact_must_be_reviewable
    return if artifact.blank?
    return if artifact.pending_review? || artifact.reviewing?

    errors.add(
      :artifact,
      I18n.t("errors.review.artifact_must_be_reviewable")
    )
  end

  # 選択された違和感項目を保存する
  def create_review_issues!(issue_types)
    Array(issue_types).reject(&:blank?).each do |issue_type|
      review_issues.create!(issue_type: issue_type)
    end
  end
end
