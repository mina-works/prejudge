class ReviewCondition < ApplicationRecord
  belongs_to :artifact

  enum target: {
    students: 0,
    job_seekers: 1,
    local_government_staff: 2,
    companies: 3,
    clients: 4,
    residents: 5,
    internal_members: 6
  }

  enum tone: {
    serious: 0,
    friendly: 1,
    warm: 2,
    professional: 3,
    modern: 4,
    casual: 5,
    luxurious: 6
  }

  validates :purpose, :target, :tone, presence: true

  # 選択肢生成用：target(enum)を日本語ラベルに変換する
  def self.target_label(target)
    I18n.t(
      "enums.review_condition.target.#{target}"
    )
  end

  # 表示用：target(enum)を日本語ラベルに変換する
  def target_label
    self.class.target_label(target)
  end

  # 選択肢生成用：tone(enum)を日本語ラベルに変換する
  def self.tone_label(tone)
    I18n.t(
      "enums.review_condition.tone.#{tone}"
    )
  end

  # 表示用：tone(enum)を日本語ラベルに変換する
  def tone_label
    self.class.tone_label(tone)
  end
end
