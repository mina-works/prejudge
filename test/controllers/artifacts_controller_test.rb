require "test_helper"

class ArtifactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @creator = users(:creator)
    @reviewer = users(:reviewer)
    @approver = users(:approver)
    @artifact = artifacts(:draft_artifact)
    @pending_review_artifact = artifacts(:pending_review_artifact)
    @update_artifact = artifacts(:update_test_artifact)
  end

  ## create
  ### 正常系
  test "ログインUserはArtifactを作成できる" do
    # ログイン中のUserをCreatorとして使う
    log_in_as(@creator)

    assert_difference("Artifact.count", 1) do
      post artifacts_path, params: {
        artifact: {
          title: "New Artifact",
          description: "新しい成果物です",
          review_deadline: 1.week.from_now,
          approver_id: @approver.id,
          reviewer_ids: [@reviewer.id]
        }
      }
    end

    # 作成されたArtifactを取得する
    created_artifact = Artifact.find_by!(title: "New Artifact")

    # 成功系のメッセージが設定される
    assert flash[:notice].present?

    # 作成されたArtifactの詳細ページへリダイレクトされる
    assert_redirected_to artifact_path(created_artifact)

    # ログインUserがCreatorとして保存される
    assert_equal @creator, created_artifact.creator

    # Reviewerが保存されていることを確認する
    assert_equal(
      [@reviewer.id],
      created_artifact.artifact_reviewers
                      .reviewer
                      .pluck(:user_id)
    )

    # Approverが保存されていることを確認する
    assert_equal(
      @approver.id,
      created_artifact.artifact_reviewers
                      .approver
                      .pick(:user_id)
    )

    # 初期statusがdraftになる
    assert_predicate created_artifact, :draft?
  end

  ### バリデーション
  test "titleがないとArtifactを作成できない" do
    # ログイン中のUserをCreatorとして使う
    log_in_as(@creator)

    assert_no_difference("Artifact.count") do
      post artifacts_path, params: {
        artifact: {
          title: "",
          description: "新しい成果物です",
          review_deadline: 1.week.from_now,
          approver_id: @approver.id,
          reviewer_ids: [@reviewer.id]
        }
      }
    end

    # バリデーションエラー時は422を返す
    assert_response :unprocessable_entity
  end

  ### 未ログイン
  test "未ログインではcreateできない" do

    assert_no_difference("Artifact.count") do
      post artifacts_path, params: {
        artifact: {
          title: "New Artifact",
          description: "新しい成果物です",
          review_deadline: 1.week.from_now,
          approver_id: @approver.id,
          reviewer_ids: [@reviewer.id]
        }
      }
    end

    # ログイン画面へ遷移する
    assert_redirected_to new_session_path
  end

  ## edit
  ### 正常系
  test "Creatorは自分のArtifactを編集できる" do
    # Creatorとしてログイン
    log_in_as(@creator)

    # 自分が作成したArtifactの編集画面へアクセスする
    get edit_artifact_path(@artifact)

    # 編集画面が正常に表示されることを確認する
    assert_response :success
  end

  ### 認可
  test "Creator以外はArtifactを編集できない" do
    # Reviewerとしてログイン
    log_in_as(@reviewer)

    get edit_artifact_path(@artifact)

    assert_redirected_to artifact_path(@artifact)
  end

  ## update
  ### 正常系
  test "Creatorは自分のArtifactを更新できる" do
    log_in_as(@creator)

    patch artifact_path(@update_artifact), params: {
      artifact: {
        title: "更新後のタイトル",
        description: @update_artifact.description,
        review_deadline: @update_artifact.review_deadline,
        approver_id: @update_artifact.approver_id,
        reviewer_ids: @update_artifact.reviewer_ids
      }
    }

    assert_redirected_to artifact_path(@update_artifact)

    @update_artifact.reload
    assert_equal "更新後のタイトル", @update_artifact.title
  end

  ### バリデーション
  test "titleがないとArtifactを更新できない" do
    # ArtifactのCreatorとしてログインする
    log_in_as(@creator)

    original_title = @artifact.title

    patch artifact_path(@artifact), params: {
      artifact: {
        title: "",
        description: "新しい成果物です",
        review_deadline: 1.week.from_now,
        approver_id: @approver.id,
        reviewer_ids: [@reviewer.id]
      }
    }

    # バリデーションエラー時は422を返す
    assert_response :unprocessable_entity

    @artifact.reload
    assert_equal original_title, @artifact.title
  end

  ### 認可
  test "Creator以外はArtifactを更新できない" do
    log_in_as(@reviewer)

    original_title = @artifact.title

    patch artifact_path(@artifact), params: {
      artifact: {
        title: "変更されたタイトル",
        description: @artifact.description,
        review_deadline: @artifact.review_deadline,
        approver_id: @artifact.approver_id,
        reviewer_ids: @artifact.reviewer_ids
      }
    }

    assert_redirected_to artifact_path(@artifact)

    @artifact.reload
    assert_equal original_title, @artifact.title
  end

  ### 状態
  test "pending_reviewのArtifactは更新できない" do
    log_in_as(@creator)

    original_title = @pending_review_artifact.title

    patch artifact_path(@pending_review_artifact), params: {
      artifact: {
        title: "不正に変更されたタイトル",
        description: @pending_review_artifact.description,
        review_deadline: @pending_review_artifact.review_deadline,
        approver_id: @pending_review_artifact.approver_id,
        reviewer_ids: @pending_review_artifact.reviewer_ids
      }
    }

    # Artifact詳細画面が表示される
    assert_redirected_to artifact_path(@pending_review_artifact)

    # 状態不適合を知らせるメッセージが設定される
    assert flash[:alert].present?
    
    @pending_review_artifact.reload
    assert_equal original_title, @pending_review_artifact.title
  end

  ## 提出
  ### 正常系
  test "Creatorはファイル添付済みのdraft Artifactを提出できる" do
    # Creatorとしてログインする
    log_in_as(@creator)

    # 提出条件を満たすため、テスト用ファイルを添付する
    @artifact.file.attach(
      io: File.open(
        Rails.root.join("test/fixtures/files/sample.txt")
      ),
      filename: "sample.txt",
      content_type: "text/plain"
    )
    @artifact.reload

    # ファイルが添付されたことを確認する
    assert_predicate @artifact.file, :attached?

    # Artifactを提出する
    patch submit_artifact_path(@artifact)

    # 提出後、Artifact詳細画面へリダイレクトされる
    assert_redirected_to artifact_path(@artifact)

    # 提出成功メッセージが設定される
    assert flash[:notice].present?

    # DBから最新状態を読み直し、pending_reviewになったことを確認する
    assert_predicate @artifact.reload, :pending_review?
  end

  ### バリデーション
  test "ファイルがないとArtifactを提出できない" do
    # ArtifactのCreatorとしてログインする
    log_in_as(@creator)

    # Artifactの状態が変わらないことを確認するため、
    # 提出前のstatusを保持する
    original_status = @artifact.status

    # ファイル未添付のArtifactを提出しようとする
    patch submit_artifact_path(@artifact)

    # 提出失敗後、Artifact詳細画面へリダイレクトされる
    assert_redirected_to artifact_path(@artifact)

    # 提出失敗メッセージが設定される
    assert flash[:alert].present?

    # DBから再読み込みし、statusが変わっていないことを確認する
    assert_equal original_status, @artifact.reload.status
  end

  ## destroy
  ### 正常系
  test "draftのArtifactを削除できる" do
    # ArtifactのCreatorとしてログインする
    log_in_as(@creator)

    # DELETEリクエストによってArtifactが1件減ることを確認する
    assert_difference("Artifact.count", -1) do
      delete artifact_url(@artifact)
    end

    # 削除成功後、Artifact一覧画面へ移動することを確認する
    assert_redirected_to artifacts_url

    # destroyアクションで303 See Otherが返ることを確認する
    assert_response :see_other

    # 削除成功メッセージが設定されたことを確認する
    assert flash[:notice].present?
  end

  ### 状態
  test "pending_reviewのArtifactは削除できない" do
    log_in_as(@creator)

    # DELETEリクエストを送ってもArtifact件数が変わらないことを確認する
    assert_no_difference("Artifact.count") do
      delete artifact_url(@pending_review_artifact)
    end

    # 削除に失敗した場合、Artifact詳細画面へ戻ることを確認する
    assert_redirected_to artifact_url(@pending_review_artifact)

    # destroyアクションで303 See Otherが返ることを確認する
    assert_response :see_other

    # エラーメッセージがalertに設定されていることを確認する
    assert_predicate flash[:alert], :present?
  end
end