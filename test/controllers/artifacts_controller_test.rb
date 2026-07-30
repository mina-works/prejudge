require "test_helper"

class ArtifactsControllerTest < ActionDispatch::IntegrationTest
  test "draftのArtifactを削除できる" do
    # 削除可能なdraft状態のArtifactをfixtureから取得する
    artifact = artifacts(:draft_artifact)

    # DELETEリクエストによってArtifactが1件減ることを確認する
    assert_difference("Artifact.count", -1) do
      delete artifact_url(artifact)
    end

    # 削除成功後、Artifact一覧画面へ移動することを確認する
    assert_redirected_to artifacts_url

    # destroyアクションで303 See Otherが返ることを確認する
    assert_response :see_other

    # 削除成功メッセージが設定されたことを確認する
    assert_equal "成果物を削除しました。", flash[:notice]
  end

  test "pending_reviewのArtifactは削除できない" do
    # 削除できないpending_review状態のArtifactをfixtureから取得する
    artifact = artifacts(:one)

    # DELETEリクエストを送ってもArtifact件数が変わらないことを確認する
    assert_no_difference("Artifact.count") do
      delete artifact_url(artifact)
    end

    # 削除に失敗した場合、Artifact詳細画面へ戻ることを確認する
    assert_redirected_to artifact_url(artifact)

    # destroyアクションで303 See Otherが返ることを確認する
    assert_response :see_other

    # エラーメッセージがalertに設定されていることを確認する
    assert_predicate flash[:alert], :present?
  end
end