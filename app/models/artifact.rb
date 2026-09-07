class Artifact < ApplicationRecord
  belongs_to :creator, class_name: "User"

  has_many :artifact_reviewers, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :review_members, through: :artifact_reviewers, source: :user

  has_one :review_condition, dependent: :destroy
  has_one_attached :file

  attr_writer :reviewer_ids, :approver_id

  
  enum status: {
    draft: 0,
    pending_review: 1,
    reviewing: 2,
    revision_required: 3,
    reviewed: 4
  }

  # destroyが実行される直前に、削除可能な状態か確認する
  before_destroy :ensure_deletable

  validates :title,presence: true
  validates :review_deadline,presence: true

  validate :review_deadline_cannot_be_past
  validate :approver_must_be_selected
  validate :reviewer_and_approver_must_be_different
  validate :creator_cannot_be_review_member


  # フォームから渡されたReviewer IDを返す。
  # edit画面を最初に表示したときは、DBに保存済みの値を返す。
  def reviewer_ids
    return @reviewer_ids if defined?(@reviewer_ids)

    artifact_reviewers.reviewer.pluck(:user_id)
  end

  # フォームから渡されたApprover IDを返す。
  # edit画面を最初に表示したときは、DBに保存済みの値を返す。
  def approver_id
    return @approver_id if defined?(@approver_id)

    artifact_reviewers.approver.pick(:user_id)
  end

  # Artifact本体とレビュー担当者をまとめて保存する
  def save_with_review_members!
    self.class.transaction do
      save!
      replace_review_members!
    end
  end

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
  # 提出時にはファイル必須
  def submit!
    unless file.attached?
      errors.add(
        :file,
        I18n.t("errors.artifact.file_required")
      )

      raise ActiveRecord::RecordInvalid.new(self)
    end

    unless submittable?
      errors.add(
        :base,
        I18n.t("errors.artifact.not_submittable")
      )

      raise ActiveRecord::RecordInvalid.new(self)
    end

    pending_review!
  end

  # レビュー依頼可能か判定する
  def submittable?
    draft?
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

  # Artifactを削除できる状態か判定する
  def deletable?
    draft?
  end

  # 再提出可能なステータスか判定する
  def resubmittable?
    revision_required?
  end

  # approverを表示
  def approver
    assignment =
      if artifact_reviewers.loaded?
        artifact_reviewers.find(&:approver?)
      else
        artifact_reviewers.approver.first
      end

    assignment&.user
  end

  # reviewerを表示
  def reviewers
    assignments =
      if artifact_reviewers.loaded?
        artifact_reviewers.select(&:reviewer?)
      else
        artifact_reviewers.reviewer.includes(:user)
      end

    assignments.map(&:user)
  end

  # 現在ラウンドのレビューを取得する
  def current_round_reviews
    reviews.where(round: current_round)
  end

  # Reviewer全員が現在ラウンドでレビュー済みか判定する
  def reviewer_reviews_completed?
    assigned_ids = reviewers.map(&:id)

    reviewed_ids = current_round_reviews
                    .where(user_id: assigned_ids)
                    .distinct
                    .pluck(:user_id)

    (assigned_ids - reviewed_ids).empty?
  end

  # 現在ラウンドのApproverのレビューを取得する
  def current_approver_review
    approver_user_id =
      artifact_reviewers.approver.pick(:user_id)

    return if approver_user_id.nil?

    current_round_reviews.find_by(
      user_id: approver_user_id
    )
  end

  # Approverが現在ラウンドでレビュー済みか判定する
  def approver_review_completed?
    current_approver_review.present?
  end

  # 現在ラウンドのレビューが完了したか判定する
  def review_completed?
    reviewer_reviews_completed? &&
    approver_review_completed?
  end

  # レビュー作成後の状態遷移をまとめて行う
  def update_status_after_review!
    start_reviewing!
    update_status_from_reviews!
  end

  # 最初のレビューが作成されたらレビュー中にする
  def start_reviewing!
    reviewing! if pending_review?
  end

  # 現在ラウンドのレビュー結果からステータスを更新する
  def update_status_from_reviews!
    return unless review_completed?

    if current_approver_review.ok?
      reviewed!
    else
      revision_required!
    end
  end

  private

  # Reviewer・Approverを登録し直す
  def replace_review_members!
    artifact_reviewers.destroy_all

    normalized_reviewer_ids.each do |user_id|
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

  # Reviewer IDを保存用に正規化する
  def normalized_reviewer_ids
    Array(reviewer_ids)
      .reject(&:blank?)
      .map(&:to_s)
      .uniq
  end

  def review_deadline_cannot_be_past
    return if review_deadline.blank?

    if review_deadline < Time.current
      errors.add(
        :review_deadline,
        I18n.t("errors.artifact.review_deadline_cannot_be_past")
      )
    end
  end

  def approver_must_be_selected
    return if approver_id.present?

    errors.add(
      :approver_id,
      I18n.t("errors.artifact.approver_required")
    )
  end

  # ReviewerとApproverには、同じユーザーを選択できない
  def reviewer_and_approver_must_be_different
    return if approver_id.blank?
    return unless normalized_reviewer_ids.include?(approver_id.to_s)

    errors.add(
      :base,
      I18n.t("errors.artifact.review_roles_must_be_separate")
    )
  end

  # CreatorはReviewer・Approverになれない
  def creator_cannot_be_review_member
    return if creator.blank?

    creator_id_str = creator_id.to_s

    if normalized_reviewer_ids.include?(creator_id_str)
      errors.add(
        :base,
        I18n.t("errors.artifact.creator_cannot_be_reviewer")
      )
    end

    if approver_id.to_s == creator_id_str
      errors.add(
        :base,
        I18n.t("errors.artifact.creator_cannot_be_approver")
      )
    end
  end

  # 削除できない状態の場合はdestroyを中止する
  def ensure_deletable
    return if deletable?

    errors.add(:base, I18n.t("errors.artifact.cannot_delete"))
    throw(:abort)
  end
end
