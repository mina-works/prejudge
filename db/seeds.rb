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