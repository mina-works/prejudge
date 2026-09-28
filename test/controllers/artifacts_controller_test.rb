require "test_helper"

class ArtifactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @creator = users(:creator)
    @reviewer = users(:reviewer)
    @approver = users(:approver)
    @artifact = artifacts(:draft_artifact)
    @pending_review_artifact = artifacts(:pending_review_artifact)
    @revision_required_artifact = artifacts(:revision_required_artifact)
    @update_artifact = artifacts(:update_test_artifact)
  end

  ## index
  test "Reviewer一覧には担当するレビュー対応中のArtifactだけを表示する" do
    statuses = {
      draft: false,
      pending_review: true,
      reviewing: true,
      revision_required: false,
      reviewed: false
    }

    artifacts = statuses.to_h do |status, _visible|
      artifact = create_artifact(
        title: "Reviewer #{status}",
        status: status,
        reviewer: @reviewer,
        approver: @approver
      )

      [status, artifact]
    end

    unrelated = create_artifact(
      title: "Reviewer unrelated",
      status: :pending_review,
      creator: users(:unassigned_user),
      reviewer: @creator,
      approver: @approver
    )

    log_in_as(@reviewer)
    get artifacts_path

    assert_response :success

    assert_select "#reviewer-artifacts" do
      statuses.each do |status, visible|
        assert_select "a[href=?]", artifact_path(artifacts.fetch(status)),
                      count: visible ? 1 : 0
      end

      assert_select "a[href=?]", artifact_path(unrelated), count: 0
    end
  end

  test "Approver一覧には担当するレビュー完了前のArtifactだけを表示する" do
    statuses = {
      draft: false,
      pending_review: true,
      reviewing: true,
      revision_required: true,
      reviewed: false
    }

    artifacts = statuses.to_h do |status, _visible|
      artifact = create_artifact(
        title: "Approver #{status}",
        status: status,
        reviewer: @reviewer,
        approver: @approver
      )

      [status, artifact]
    end

    unrelated = create_artifact(
      title: "Approver unrelated",
      status: :pending_review,
      creator: users(:unassigned_user),
      reviewer: @reviewer,
      approver: @creator
    )

    log_in_as(@approver)
    get artifacts_path

    assert_response :success

    assert_select "#approver-artifacts" do
      statuses.each do |status, visible|
        assert_select "a[href=?]", artifact_path(artifacts.fetch(status)),
                      count: visible ? 1 : 0
      end

      assert_select "a[href=?]", artifact_path(unrelated), count: 0
    end
  end

  test "Creator一覧には自分が作成した未完了Artifactだけを表示する" do
    pending_artifact = create_artifact(
      title: "Creator pending",
      status: :pending_review
    )
    reviewed_artifact = create_artifact(
      title: "Creator reviewed",
      status: :reviewed
    )
    unrelated = create_artifact(
      title: "Creator unrelated",
      status: :pending_review,
      creator: users(:unassigned_user),
      reviewer: @creator,
      approver: @approver
    )

    log_in_as(@creator)
    get artifacts_path

    assert_response :success

    assert_select "#creator-artifacts" do
      assert_select "a[href=?]", artifact_path(pending_artifact), count: 1
      assert_select "a[href=?]", artifact_path(reviewed_artifact), count: 0
      assert_select "a[href=?]", artifact_path(unrelated), count: 0
    end
  end

  test "各一覧はレビュー期限順かつ同期限では作成日時順に表示する" do
    current_user = User.create!(
      name: "Index Order User",
      email: "index-order@example.com",
      password: "password",
      password_confirmation: "password"
    )
    same_deadline = 5.days.from_now.change(usec: 0)

    create_artifact(
      title: "Creator order third",
      status: :pending_review,
      creator: current_user,
      deadline: 1.week.from_now,
      created_at: 3.days.ago
    )
    create_artifact(
      title: "Creator order second",
      status: :pending_review,
      creator: current_user,
      deadline: same_deadline,
      created_at: 1.day.ago
    )
    create_artifact(
      title: "Creator order first",
      status: :pending_review,
      creator: current_user,
      deadline: same_deadline,
      created_at: 2.days.ago
    )
    create_artifact(
      title: "Reviewer order third",
      status: :pending_review,
      reviewer: current_user,
      deadline: 1.week.from_now,
      created_at: 3.days.ago
    )
    create_artifact(
      title: "Reviewer order second",
      status: :pending_review,
      reviewer: current_user,
      deadline: same_deadline,
      created_at: 1.day.ago
    )
    create_artifact(
      title: "Reviewer order first",
      status: :pending_review,
      reviewer: current_user,
      deadline: same_deadline,
      created_at: 2.days.ago
    )
    create_artifact(
      title: "Approver order third",
      status: :pending_review,
      approver: current_user,
      deadline: 1.week.from_now,
      created_at: 3.days.ago
    )
    create_artifact(
      title: "Approver order second",
      status: :pending_review,
      approver: current_user,
      deadline: same_deadline,
      created_at: 1.day.ago
    )
    create_artifact(
      title: "Approver order first",
      status: :pending_review,
      approver: current_user,
      deadline: same_deadline,
      created_at: 2.days.ago
    )

    log_in_as(current_user)
    get artifacts_path

    assert_equal [
      "Reviewer order first",
      "Reviewer order second",
      "Reviewer order third"
    ], css_select("#reviewer-artifacts tbody a").map { |link| link.text.strip }

    assert_equal [
      "Approver order first",
      "Approver order second",
      "Approver order third"
    ], css_select("#approver-artifacts tbody a").map { |link| link.text.strip }

    assert_equal [
      "Creator order first",
      "Creator order second",
      "Creator order third"
    ], css_select("#creator-artifacts tbody a").map { |link| link.text.strip }
  end

  test "対象Artifactが0件でもindexを表示できる" do
    user = User.create!(
      name: "Empty Index User",
      email: "empty-index@example.com",
      password: "password",
      password_confirmation: "password"
    )

    log_in_as(user)
    get artifacts_path

    assert_response :success
    assert_select "#reviewer-artifacts tbody tr", count: 0
    assert_select "#approver-artifacts tbody tr", count: 0
    assert_select "#creator-artifacts tbody tr", count: 0
    assert_select "p", text: I18n.t("artifacts.index.empty"), count: 3
  end

  ## create
  ### 正常系
  test "ログインUserはArtifactを作成できる" do
    # ログイン中のUserをCreatorとして使う
    log_in_as(@creator)

    assert_difference(["Artifact.count", "ReviewCondition.count"], 1) do
      post artifacts_path, params: {
        artifact: valid_artifact_params(
          title: "New Artifact",
          description: "新しい成果物です"
        )
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

    assert_equal "採用ページの改善", created_artifact.review_condition.purpose
    assert_predicate created_artifact.review_condition, :job_seekers?
    assert_predicate created_artifact.review_condition, :friendly?

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
        artifact: valid_artifact_params(title: "")
      }
    end

    # バリデーションエラー時は422を返す
    assert_response :unprocessable_entity
  end

  test "ReviewConditionが不正な場合はArtifactもReviewConditionも作成できない" do
    log_in_as(@creator)

    params = valid_artifact_params
    params[:review_condition_attributes][:purpose] = ""

    assert_no_difference(["Artifact.count", "ReviewCondition.count"]) do
      post artifacts_path, params: { artifact: params }
    end

    assert_response :unprocessable_entity
    assert_select "h1", text: I18n.t("artifacts.new.title")
    assert_no_match(/Review condition/i, response.body)
  end

  ### 未ログイン
  test "未ログインではcreateできない" do

    assert_no_difference("Artifact.count") do
      post artifacts_path, params: {
        artifact: valid_artifact_params(title: "New Artifact")
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

    review_condition = @update_artifact.review_condition

    assert_no_difference("ReviewCondition.count") do
      patch artifact_path(@update_artifact), params: {
        artifact: update_params(
          @update_artifact,
          title: "更新後のタイトル",
          review_condition_attributes: {
            id: review_condition.id,
            purpose: "更新後の目的",
            target: :companies,
            tone: :professional
          }
        )
      }
    end

    assert_redirected_to artifact_path(@update_artifact)
    assert_equal I18n.t("flash.artifact.updated"), flash[:notice]

    @update_artifact.reload
    assert_equal "更新後のタイトル", @update_artifact.title
    assert_equal review_condition.id, @update_artifact.review_condition.id
    assert_equal "更新後の目的", @update_artifact.review_condition.purpose
    assert_predicate @update_artifact.review_condition, :companies?
    assert_predicate @update_artifact.review_condition, :professional?
  end

  test "Creatorはrevision_requiredのArtifactとReviewConditionを更新できる" do
    log_in_as(@creator)

    patch artifact_path(@revision_required_artifact), params: {
      artifact: update_params(
        @revision_required_artifact,
        title: "再提出前の更新",
        review_condition_attributes: {
          id: @revision_required_artifact.review_condition.id,
          purpose: "再提出時の目的",
          target: :clients,
          tone: :warm
        }
      )
    }

    assert_redirected_to artifact_path(@revision_required_artifact)

    @revision_required_artifact.reload
    assert_equal "再提出前の更新", @revision_required_artifact.title
    assert_equal "再提出時の目的", @revision_required_artifact.review_condition.purpose
  end

  ### バリデーション
  test "titleがないとArtifactを更新できない" do
    # ArtifactのCreatorとしてログインする
    log_in_as(@creator)

    original_title = @artifact.title

    patch artifact_path(@artifact), params: {
      artifact: update_params(@artifact, title: "")
    }

    # バリデーションエラー時は422を返す
    assert_response :unprocessable_entity

    @artifact.reload
    assert_equal original_title, @artifact.title
  end

  test "ReviewConditionが不正な場合はArtifactもReviewConditionも更新されない" do
    log_in_as(@creator)

    original_title = @update_artifact.title
    original_purpose = @update_artifact.review_condition.purpose

    patch artifact_path(@update_artifact), params: {
      artifact: update_params(
        @update_artifact,
        title: "保存されないタイトル",
        review_condition_attributes: {
          id: @update_artifact.review_condition.id,
          purpose: "",
          target: :companies,
          tone: :professional
        }
      )
    }

    assert_response :unprocessable_entity
    assert_select "h1", text: I18n.t("artifacts.edit.title")

    @update_artifact.reload
    assert_equal original_title, @update_artifact.title
    assert_equal original_purpose, @update_artifact.review_condition.purpose
  end

  ### 認可
  test "Creator以外はArtifactを更新できない" do
    log_in_as(@reviewer)

    original_title = @artifact.title
    original_purpose = @artifact.review_condition.purpose

    patch artifact_path(@artifact), params: {
      artifact: update_params(
        @artifact,
        title: "変更されたタイトル",
        review_condition_attributes: {
          id: @artifact.review_condition.id,
          purpose: "変更された目的",
          target: :companies,
          tone: :professional
        }
      )
    }

    assert_redirected_to artifact_path(@artifact)

    @artifact.reload
    assert_equal original_title, @artifact.title
    assert_equal original_purpose, @artifact.review_condition.purpose
  end

  ### 状態
  test "編集不可状態のArtifactとReviewConditionは更新できない" do
    log_in_as(@creator)

    %i[pending_review reviewing reviewed].each do |status|
      @pending_review_artifact.update_column(:status, Artifact.statuses.fetch(status))
      original_title = @pending_review_artifact.title
      original_purpose = @pending_review_artifact.review_condition.purpose

      patch artifact_path(@pending_review_artifact), params: {
        artifact: update_params(
          @pending_review_artifact,
          title: "不正に変更されたタイトル",
          review_condition_attributes: {
            id: @pending_review_artifact.review_condition.id,
            purpose: "不正に変更された目的",
            target: :companies,
            tone: :professional
          }
        )
      }

      assert_redirected_to artifact_path(@pending_review_artifact)
      assert_equal I18n.t("flash.artifact.not_editable"), flash[:alert]

      @pending_review_artifact.reload
      assert_equal original_title, @pending_review_artifact.title
      assert_equal original_purpose, @pending_review_artifact.review_condition.purpose
    end
  end

  ## 提出
  ### 正常系
  test "Creatorはファイル添付済みのdraft Artifactを提出できる" do
    # Creatorとしてログインする
    log_in_as(@creator)

    # 提出条件を満たすため、テスト用ファイルを添付する
    attach_file(@artifact)
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

  test "ReviewConditionが不正な場合はファイルがあっても提出できない" do
    log_in_as(@creator)
    attach_file(@artifact)
    @artifact.review_condition.update_column(:purpose, "")

    original_status = @artifact.status

    patch submit_artifact_path(@artifact)

    assert_redirected_to artifact_path(@artifact)
    assert_predicate flash[:alert], :present?
    assert_includes flash[:alert], "目的"
    assert_no_match(/Review condition/i, flash[:alert])
    assert_equal original_status, @artifact.reload.status
  end

  ### 認可
  test "Creator以外はdraftのArtifactを提出できない" do
    log_in_as(@reviewer)

    # 認可以外の提出条件を満たすため、テスト用ファイルを添付する
    attach_file(@artifact)

    original_status = @artifact.status

    patch submit_artifact_path(@artifact)

    assert_redirected_to artifact_path(@artifact)
    assert_equal I18n.t("flash.artifact.not_authorized"), flash[:alert]
    assert_equal original_status, @artifact.reload.status
  end

  ### 状態
  test "draft以外のArtifactは提出できない" do
    log_in_as(@creator)

    %i[pending_review reviewing revision_required reviewed].each do |status|
      @pending_review_artifact.update_column(:status, Artifact.statuses.fetch(status))

      patch submit_artifact_path(@pending_review_artifact)

      assert_redirected_to artifact_path(@pending_review_artifact)
      assert_equal I18n.t("flash.artifact.not_submittable"), flash[:alert]
      assert_equal status.to_s, @pending_review_artifact.reload.status
    end
  end

  ## 再提出
  ### 正常系
  test "Creatorはrevision_requiredのArtifactを再提出できる" do
    log_in_as(@creator)
    attach_file(@revision_required_artifact)

    original_round = @revision_required_artifact.current_round

    patch resubmit_artifact_path(@revision_required_artifact)

    assert_redirected_to artifact_path(@revision_required_artifact)
    assert_predicate flash[:notice], :present?

    @revision_required_artifact.reload
    assert_predicate @revision_required_artifact, :pending_review?
    assert_equal original_round + 1, @revision_required_artifact.current_round
  end

  ### バリデーション
  test "ファイルがないとArtifactを再提出できない" do
    log_in_as(@creator)

    original_status = @revision_required_artifact.status
    original_round = @revision_required_artifact.current_round

    patch resubmit_artifact_path(@revision_required_artifact)

    assert_redirected_to artifact_path(@revision_required_artifact)
    assert_predicate flash[:alert], :present?

    @revision_required_artifact.reload
    assert_equal original_status, @revision_required_artifact.status
    assert_equal original_round, @revision_required_artifact.current_round
  end

  test "ReviewConditionが不正な場合はファイルがあっても再提出できない" do
    log_in_as(@creator)
    attach_file(@revision_required_artifact)
    @revision_required_artifact.review_condition.update_column(:tone, 99)

    original_status = @revision_required_artifact.status
    original_round = @revision_required_artifact.current_round

    patch resubmit_artifact_path(@revision_required_artifact)

    assert_redirected_to artifact_path(@revision_required_artifact)
    assert_predicate flash[:alert], :present?
    assert_includes flash[:alert], "トーン"
    assert_no_match(/Review condition/i, flash[:alert])

    @revision_required_artifact.reload
    assert_equal original_status, @revision_required_artifact.status
    assert_equal original_round, @revision_required_artifact.current_round
  end

  ### 認可
  test "Creator以外はrevision_requiredのArtifactを再提出できない" do
    log_in_as(@reviewer)

    original_status = @revision_required_artifact.status
    original_round = @revision_required_artifact.current_round

    patch resubmit_artifact_path(@revision_required_artifact)

    assert_redirected_to artifact_path(@revision_required_artifact)
    assert_equal I18n.t("flash.artifact.not_authorized"), flash[:alert]

    @revision_required_artifact.reload
    assert_equal original_status, @revision_required_artifact.status
    assert_equal original_round, @revision_required_artifact.current_round
  end

  ### 状態
  test "revision_required以外のArtifactは再提出できない" do
    log_in_as(@creator)

    %i[draft pending_review reviewing reviewed].each do |status|
      @artifact.update_columns(
        status: Artifact.statuses.fetch(status),
        current_round: 1
      )

      patch resubmit_artifact_path(@artifact)

      assert_redirected_to artifact_path(@artifact)
      assert_equal I18n.t("flash.artifact.not_resubmittable"), flash[:alert]

      @artifact.reload
      assert_equal status.to_s, @artifact.status
      assert_equal 1, @artifact.current_round
    end
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

  ### 認可
  test "Creator以外はdraftのArtifactを削除できない" do
    log_in_as(@reviewer)

    assert_no_difference("Artifact.count") do
      delete artifact_url(@artifact)
    end

    assert_redirected_to artifact_url(@artifact)
    assert_equal I18n.t("flash.artifact.not_authorized"), flash[:alert]
    assert Artifact.exists?(@artifact.id)
  end

  private

  def valid_artifact_params(title: "New Artifact", description: "新しい成果物です")
    {
      title: title,
      description: description,
      review_deadline: 1.week.from_now,
      approver_id: @approver.id,
      reviewer_ids: [@reviewer.id],
      review_condition_attributes: {
        purpose: "採用ページの改善",
        target: :job_seekers,
        tone: :friendly
      }
    }
  end

  def update_params(
    artifact,
    title: artifact.title,
    review_condition_attributes: {
      id: artifact.review_condition.id,
      purpose: artifact.review_condition.purpose,
      target: artifact.review_condition.target,
      tone: artifact.review_condition.tone
    }
  )
    {
      title: title,
      description: artifact.description,
      review_deadline: artifact.review_deadline,
      approver_id: artifact.approver_id,
      reviewer_ids: artifact.reviewer_ids,
      review_condition_attributes: review_condition_attributes
    }
  end

  def attach_file(artifact)
    file_fixture("sample.txt").open do |file|
      artifact.file.attach(
        io: file,
        filename: "sample.txt",
        content_type: "text/plain"
      )
    end
  end

  def create_artifact(
    title:,
    status:,
    creator: @creator,
    reviewer: @reviewer,
    approver: @approver,
    deadline: 1.week.from_now,
    created_at: Time.current
  )
    artifact = Artifact.new(
      title: title,
      creator: creator,
      status: status,
      review_deadline: deadline,
      created_at: created_at,
      reviewer_ids: [reviewer.id],
      approver_id: approver.id,
      review_condition_attributes: {
        purpose: "レビュー目的",
        target: :job_seekers,
        tone: :friendly
      }
    )
    artifact.save_with_review_members!
    artifact
  end
end
