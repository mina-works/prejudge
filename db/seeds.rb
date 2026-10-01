# 開発環境でのログイン・動作確認用ユーザー
#
# seedを再実行した場合でも同じメールアドレスのUserを再利用し、
# seedに定義した属性へ更新する。

reviewer1 = User.find_or_initialize_by(email: "reviewer1@example.com")
reviewer1.assign_attributes(
  name: "Reviewer1",
  password: "password"
)
reviewer1.save!

reviewer2 = User.find_or_initialize_by(email: "reviewer2@example.com")
reviewer2.assign_attributes(
  name: "Reviewer2",
  password: "password"
)
reviewer2.save!

reviewer3 = User.find_or_initialize_by(email: "reviewer3@example.com")
reviewer3.assign_attributes(
  name: "Reviewer3",
  password: "password"
)
reviewer3.save!

approver = User.find_or_initialize_by(email: "approver@example.com")
approver.assign_attributes(
  name: "Approver",
  password: "password"
)
approver.save!

creator = User.find_or_initialize_by(email: "creator@example.com")
creator.assign_attributes(
  name: "Creator",
  password: "password"
)
creator.save!

# Artifact・ReviewCondition・ArtifactReviewerの
# 開発環境用データを作成する
def seed_artifact(
  creator:,
  title:,
  description:,
  review_deadline:,
  reviewers:,
  approver:,
  purpose:,
  target:,
  tone:,
  submit: false,
  file_path: nil
)
  # 同じseedを再実行しても同一Artifactを再利用する
  artifact = Artifact.find_or_initialize_by(
    creator: creator,
    title: title
  )

  artifact.assign_attributes(
    description: description,
    review_deadline: review_deadline,
    status: :draft,
    reviewer_ids: reviewers.map(&:id),
    approver_id: approver.id
  )

  # ReviewConditionがまだなければ作る
  artifact.build_review_condition unless artifact.review_condition

  artifact.review_condition.assign_attributes(
    purpose: purpose,
    target: target,
    tone: tone
  )

  # Artifact本体・ReviewCondition・ArtifactReviewerを保存する
  artifact.save_with_review_members!

  if submit
    # pending_reviewにするArtifactにはファイルを添付する
    artifact.file.purge if artifact.file.attached?

    artifact.file.attach(
      io: File.open(file_path),
      filename: File.basename(file_path),
      content_type: "application/pdf"
    )

    # statusを直接変更せず、実際の提出処理を通す
    artifact.submit!
  else
    # draft用Artifactはファイルなしの状態に戻す
    artifact.file.purge if artifact.file.attached?
  end

  artifact
end

sample_file =
  Rails.root.join(
    "db",
    "seeds",
    "files",
    "sample.pdf"
  )

# --------------------------------
# draft
# --------------------------------

seed_artifact(
  creator: creator,
  title: "下書きArtifact",
  description: "編集・削除・提出の動作確認用",
  review_deadline: 3.days.from_now,
  reviewers: [reviewer1, reviewer2],
  approver: approver,
  purpose: "Webサイト掲載前の内容確認",
  target: :students,
  tone: :friendly
)

# --------------------------------
# pending_review 1
# --------------------------------

seed_artifact(
  creator: creator,
  title: "レビュー待ちArtifact",
  description: "Reviewer・Approverの動作確認用",
  review_deadline: 7.days.from_now,
  reviewers: [reviewer1, reviewer2],
  approver: approver,
  purpose: "学生向けコンテンツのレビュー",
  target: :students,
  tone: :friendly,
  submit: true,
  file_path: sample_file
)

# --------------------------------
# pending_review 2
# --------------------------------

seed_artifact(
  creator: creator,
  title: "レビュー待ちArtifact（別案件）",
  description: "担当者と期限順の確認用",
  review_deadline: 14.days.from_now,
  reviewers: [reviewer1, reviewer3],
  approver: approver,
  purpose: "企業向けコンテンツのレビュー",
  target: :companies,
  tone: :professional,
  submit: true,
  file_path: sample_file
)