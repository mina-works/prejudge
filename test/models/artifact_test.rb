require "test_helper"

class ArtifactTest < ActiveSupport::TestCase
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
