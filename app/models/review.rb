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

  # review作成時点のartifact.current_roundを保持する
  # 過去review履歴を固定保存するため、初回のみセットする
  before_validation :set_round

  # review履歴保護のため、過去roundのreview編集を禁止する
  validate :prevent_edit_past_review, on: :update

  # reviewerはng（差し戻し）不可
  # 最終的な差し戻し権限はapproverのみが持つ
  validate :reviewer_cannot_select_ng

  # approverのreview結果に応じてartifact.statusを更新する
  # reviewerのreviewはstatusに影響しない
  after_create :update_artifact_status

  private

  def set_round
    self.round ||= artifact&.current_round
  end

  def prevent_edit_past_review
    if round < artifact.current_round
      errors.add(:base, "過去ラウンドのレビューは編集できません")
    end
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

    errors.add(:result, "reviewerはngを選択できません")
  end

  def update_artifact_status
    return unless approver?

    if ok?
      artifact.reviewed!
    
    # approverがuneasy/ngの場合は修正依頼状態にする
    elsif uneasy? || ng?
      artifact.revision_required!
    end
  end

end
