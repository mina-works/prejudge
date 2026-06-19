class Artifact < ApplicationRecord
  belongs_to :creator, class_name: "User"

  has_many :artifact_reviewers, dependent: :destroy
  has_many :reviews, dependent: :destroy

  has_one :review_condition, dependent: :destroy

  
  enum status: {
    draft: 0,
    reviewing: 1,
    revision_required: 2,
    reviewed: 3
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

  private

  def review_deadline_cannot_be_past
    return if review_deadline.blank?

    if review_deadline < Time.current
      errors.add(
        :review_deadline,
        "は現在より後の日時を指定してください"
      )
    end
  end
end
