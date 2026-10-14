require "test_helper"

class ArtifactTest < ActiveSupport::TestCase
  test "ReviewerとApproverだけがレビュー担当者である" do
    artifact = artifacts(:review_create_test_artifact)

    %i[reviewer approver].each do |role|
      assert artifact.review_member?(users(role)), role.to_s
    end

    %i[creator unassigned_user].each do |role|
      assert_not artifact.review_member?(users(role)), role.to_s
    end
    assert_not artifact.review_member?(nil)
  end

  test "ReviewerとApproverだけがレビューを作成できる" do
    artifact = artifacts(:review_create_test_artifact)

    %i[reviewer approver].each do |role|
      assert artifact.reviewable_by?(users(role)), role.to_s
    end

    %i[creator unassigned_user].each do |role|
      assert_not artifact.reviewable_by?(users(role)), role.to_s
    end
    assert_not artifact.reviewable_by?(nil)
  end

  test "pending_reviewとreviewingだけがレビュー作成可能な状態である" do
    artifact = artifacts(:review_create_test_artifact)

    Artifact.statuses.each_key do |status|
      artifact.status = status

      %i[reviewer approver].each do |role|
        assert_equal %w[pending_review reviewing].include?(status),
                     artifact.reviewable_by?(users(role)), "#{role}: #{status}"
      end
    end
  end

  test "現在ラウンドでレビュー済みの担当者だけがレビューを作成できない" do
    artifact = artifacts(:review_create_test_artifact)
    artifact.reviews.create!(user: users(:reviewer), result: :ok)

    assert_not artifact.reviewable_by?(users(:reviewer))
    assert artifact.reviewable_by?(users(:approver))

    artifact.reviews.create!(user: users(:approver), result: :uneasy)
    # 状態による拒否と区別して、Approverのレビュー済み判定も確認する。
    artifact.status = :reviewing
    assert_not artifact.reviewable_by?(users(:approver))
  end

  test "過去ラウンドのレビューは現在ラウンドのレビュー作成を妨げない" do
    artifact = artifacts(:review_create_test_artifact)
    artifact.reviews.create!(user: users(:reviewer), result: :ok)
    artifact.reviews.create!(user: users(:approver), result: :uneasy)
    artifact.update!(current_round: 2, status: :pending_review)

    %i[reviewer approver].each do |role|
      assert artifact.reviewable_by?(users(role)), role.to_s
    end
  end

  test "CreatorはArtifactを閲覧できる" do
    artifact = artifacts(:draft_artifact)

    assert artifact.viewable_by?(users(:creator))
  end

  test "ReviewerはArtifactを閲覧できる" do
    artifact = artifacts(:draft_artifact)

    assert artifact.viewable_by?(users(:reviewer))
  end

  test "ApproverはArtifactを閲覧できる" do
    artifact = artifacts(:draft_artifact)

    assert artifact.viewable_by?(users(:approver))
  end

  test "関係のないUserはArtifactを閲覧できない" do
    artifact = artifacts(:draft_artifact)

    assert_not artifact.viewable_by?(users(:unassigned_user))
  end

  test "ReviewConditionがないArtifactはinvalid" do
    artifact = artifacts(:draft_artifact)
    artifact.review_condition = nil

    assert_not artifact.valid?
    assert_includes artifact.errors[:review_condition], I18n.t("errors.messages.blank")
    assert_includes artifact.errors.full_messages, "レビュー条件を入力してください"
  end

  test "draftのArtifactは削除できる" do
    # fixturesからテスト用のArtifactを取得する
    artifact = artifacts(:draft_artifact)

    # destroyによってArtifactの件数が1件減ることを確認する
    assert_difference("Artifact.count", -1) do
      artifact.destroy
    end
  end

  test "pending_reviewのArtifactは削除できない" do
    # pending_review_artifactはfixture上でpending_reviewになっている
    artifact = artifacts(:pending_review_artifact)

    # destroyを実行してもArtifactの件数が変わらないことを確認する
    assert_no_difference("Artifact.count") do
      artifact.destroy
    end

    # destroyが失敗したことを確認する
    assert_not artifact.destroyed?

    # 削除できない理由がerrorsに追加されていることを確認する
    assert_includes(
      artifact.errors[:base],
      I18n.t("errors.artifact.cannot_delete")
    )
  end
end
