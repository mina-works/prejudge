require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.new(
      name: "テストユーザー",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "パスワードを設定してUserを保存できる" do
    assert @user.save
  end

  test "正しいパスワードで認証できる" do
    @user.save!

    authenticated_user =
      @user.authenticate("password123")

    assert_equal @user, authenticated_user
  end

  test "間違ったパスワードでは認証できない" do
    @user.save!

    authenticated_user =
      @user.authenticate("wrong_password")

    assert_not authenticated_user
  end

  test "password_confirmationが一致しない場合は保存できない" do
    @user.password_confirmation = "different_password"

    assert_not @user.save

    assert @user.errors[:password_confirmation].present?
  end

  test "Reviewerとしての担当とArtifactを取得できる" do
    reviewer = users(:reviewer)
    assignment = artifact_reviewers(:role_reviewer)

    assert_includes reviewer.reviewer_assignments, assignment
    assert_includes reviewer.reviewer_artifacts, assignment.artifact
    assert_not_includes reviewer.approver_assignments, assignment
  end

  test "Approverとしての担当とArtifactを取得できる" do
    approver = users(:approver)
    assignment = artifact_reviewers(:role_approver)

    assert_includes approver.approver_assignments, assignment
    assert_includes approver.approver_artifacts, assignment.artifact
    assert_not_includes approver.reviewer_assignments, assignment
  end

  test "既存のartifact_reviewersはUserの削除を制限する" do
    association = User.reflect_on_association(:artifact_reviewers)

    assert_equal :restrict_with_error, association.options[:dependent]
  end
end
