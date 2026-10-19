require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @artifact = artifacts(:review_create_test_artifact)
  end

  %i[creator reviewer approver].each do |role|
    test "#{role}はステータスに関係なくReview一覧と詳細を閲覧できる" do
      review = @artifact.reviews.create!(user: users(:reviewer), result: :ok, comment: "閲覧対象レビュー")
      log_in_as(users(role))

      Artifact.statuses.each_key do |status|
        @artifact.update!(status: status)

        get artifact_reviews_path(@artifact)

        assert_response :success
        assert_select "a[href=?]", artifact_review_path(@artifact, review), count: 1
        assert_select "p", text: "レビューはまだありません", count: 0

        get artifact_review_path(@artifact, review)

        assert_response :success
        assert_select "p", text: /閲覧対象レビュー/
      end
    end

    test "#{role}は過去ラウンドのReviewも一覧と詳細で閲覧できる" do
      previous_review = @artifact.reviews.create!(user: users(:reviewer), result: :ok, comment: "過去ラウンドのレビュー")
      @artifact.update!(current_round: 2, status: :pending_review)
      current_review = @artifact.reviews.create!(user: users(:reviewer), result: :uneasy)
      log_in_as(users(role))

      get artifact_reviews_path(@artifact)

      assert_response :success
      [previous_review, current_review].each do |review|
        assert_select "a[href=?]", artifact_review_path(@artifact, review), count: 1
      end

      get artifact_review_path(@artifact, previous_review)

      assert_response :success
      assert_select "p", text: /過去ラウンドのレビュー/
    end
  end

  test "無関係なUserはステータスに関係なくReview一覧と詳細を閲覧できない" do
    review = @artifact.reviews.create!(user: users(:reviewer), result: :ok)
    log_in_as(users(:unassigned_user))

    Artifact.statuses.each_key do |status|
      @artifact.update!(status: status)

      [artifact_reviews_path(@artifact), artifact_review_path(@artifact, review)].each do |path|
        get path

        assert_redirected_to artifacts_path
        assert_equal "閲覧許可がありません", flash[:alert]

        follow_redirect!

        assert_response :success
        assert_select "p", text: "閲覧許可がありません"
      end
    end
  end

  test "未ログインではReview一覧と詳細はログイン画面へリダイレクトする" do
    review = @artifact.reviews.create!(user: users(:reviewer), result: :ok)

    [artifact_reviews_path(@artifact), artifact_review_path(@artifact, review)].each do |path|
      get path

      assert_redirected_to new_session_path
      assert_equal I18n.t("flash.session.login_required"), flash[:alert]
    end
  end

  test "Reviewが0件の一覧画面には未登録メッセージを表示する" do
    log_in_as(users(:creator))
    assert_empty @artifact.reviews

    get artifact_reviews_path(@artifact)

    assert_response :success
    assert_select "p", text: "レビューはまだありません", count: 1
  end

  test "別のArtifactに属するReviewのIDを指定しても詳細を取得できない" do
    other_review = reviews(:reviewer_review)
    log_in_as(users(:creator))

    get artifact_review_path(@artifact, other_review)

    assert_response :not_found
  end

  %i[reviewer approver].each do |role|
    %i[pending_review reviewing].each do |status|
      test "#{role}は#{status}のReview作成画面を開き自分自身として登録できる" do
        user = users(role)
        log_in_as(user)
        @artifact.update!(status: status)

        get new_artifact_review_path(@artifact)

        assert_response :success
        assert_select "form[action=?]", artifact_reviews_path(@artifact), count: 1

        assert_difference("Review.count", 1) do
          post artifact_reviews_path(@artifact), params: {
            review: { result: "ok", comment: "問題ありません", user_id: users(:creator).id }
          }
        end

        review = @artifact.reviews.find_by!(user: user, round: @artifact.current_round)
        assert_redirected_to artifact_review_path(@artifact, review)
        assert_equal I18n.t("flash.review.created"), flash[:notice]
        assert_predicate @artifact.reload, :reviewing?
      end
    end

    test "#{role}でもレビュー不可の状態ではnewとcreateを実行できない" do
      log_in_as(users(role))

      %i[draft revision_required reviewed].each do |status|
        @artifact.update!(status: status)

        assert_review_creation_denied
      end
    end

    test "#{role}は現在ラウンドでレビュー済みならnewとcreateを実行できない" do
      user = users(role)
      @artifact.reviews.create!(user: user, result: :ok)
      log_in_as(user)

      assert_review_creation_denied
    end

    test "#{role}は過去ラウンドでレビュー済みでも現在ラウンドのReviewを作成できる" do
      user = users(role)
      previous_review = @artifact.reviews.create!(user: user, result: :ok)
      @artifact.update!(current_round: 2, status: :pending_review)
      log_in_as(user)

      get new_artifact_review_path(@artifact)

      assert_response :success

      assert_difference("Review.count", 1) do
        post artifact_reviews_path(@artifact), params: { review: { result: "ok" } }
      end

      review = @artifact.reviews.find_by!(user: user, round: 2)
      assert_redirected_to artifact_review_path(@artifact, review)
      assert_equal 1, previous_review.reload.round
    end
  end

  %i[creator unassigned_user].each do |role|
    test "#{role}はURLを直接指定してもnewとcreateを実行できない" do
      log_in_as(users(role))

      assert_review_creation_denied
    end
  end

  test "未ログインではnewとcreateを実行できない" do
    get new_artifact_review_path(@artifact)

    assert_redirected_to new_session_path
    assert_equal I18n.t("flash.session.login_required"), flash[:alert]

    assert_no_difference(["Review.count", "ReviewIssue.count"]) do
      post artifact_reviews_path(@artifact), params: { review: { result: "ok" } }
    end

    assert_redirected_to new_session_path
    assert_equal I18n.t("flash.session.login_required"), flash[:alert]
    assert_predicate @artifact.reload, :pending_review?
  end

  private

  def assert_review_creation_denied
    original_status = @artifact.reload.status
    original_round = @artifact.current_round

    get new_artifact_review_path(@artifact)

    assert_redirected_to artifact_path(@artifact)
    assert_equal I18n.t("flash.review.not_authorized"), flash[:alert]

    assert_no_difference(["Review.count", "ReviewIssue.count"]) do
      post artifact_reviews_path(@artifact), params: {
        review: { result: "uneasy", issue_types: [ReviewIssue.issue_types.keys.first] }
      }
    end

    assert_redirected_to artifact_path(@artifact)
    assert_equal I18n.t("flash.review.not_authorized"), flash[:alert]
    assert_equal original_status, @artifact.reload.status
    assert_equal original_round, @artifact.current_round
  end
end
