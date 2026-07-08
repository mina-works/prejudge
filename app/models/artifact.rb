class Artifact < ApplicationRecord
  belongs_to :creator, class_name: "User"

  has_many :artifact_reviewers, dependent: :destroy
  has_many :reviews, dependent: :destroy

  has_one :review_condition, dependent: :destroy

  
  enum status: {
    draft: 0,
    pending_review: 1,
    reviewing: 2,
    revision_required: 3,
    reviewed: 4
  }

  validates :title,presence: true
  validates :review_deadline,presence: true
  validate :review_deadline_cannot_be_past

  # 選択肢生成用：status(enum)を日本語ラベルに変換する
  def self.status_label(status)
    I18n.t(
      "enums.artifact.status.#{status}"
    )
  end

  # 表示用：status(enum)を日本語ラベルに変換する
  def status_label
    self.class.status_label(status)
  end

  # 成果物をレビュー依頼する
  def submit!
    unless submittable?
      errors.add(
        :base,
        I18n.t("errors.artifact.not_submittable")
      )

      raise ActiveRecord::RecordInvalid.new(self)
    end

    pending_review!
  end

  # 成果物を再提出する
  def resubmit!
    self.current_round += 1
    self.status = :pending_review

    save!
  end

  # 成果物が編集可能なステータスか判定する
  def editable?
    draft? || revision_required?
  end

  # 再提出可能なステータスか判定する
  def resubmittable?
    revision_required?
  end

  # レビュー依頼可能か判定する
  def submittable?
    draft?
  end

  # Reviewer・Approverを割り当てる
  def assign_review_members(reviewer_ids, approver_id)
    artifact_reviewers.destroy_all

    reviewer_ids.reject(&:blank?).each do |user_id|
      artifact_reviewers.create!(
        user_id: user_id,
        role: :reviewer
      )
    end

    artifact_reviewers.create!(
      user_id: approver_id,
      role: :approver
    )
  end

  # approverを表示
  def approver
    artifact_reviewers.approver.first&.user
  end

  # reviewerを表示
  def reviewers
    artifact_reviewers.reviewer.includes(:user).map(&:user)
  end

  private

  def review_deadline_cannot_be_past
    return if review_deadline.blank?

    if review_deadline < Time.current
      errors.add(
        :review_deadline,
        I18n.t("errors.artifact.review_deadline_cannot_be_past")
      )
    end
  end
end
