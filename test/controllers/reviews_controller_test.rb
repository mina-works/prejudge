require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @artifact = artifacts(:review_create_test_artifact)
  end

  test "Creatorはステータスに関係なくReview一覧と詳細を閲覧できる" do
    review = @artifact.reviews.create!(user: users(:reviewer), result: :ok, comment: "閲覧対象レビュー")
    log_in_as(users(:creator))

    Artifact.statuses.each_key do |status|
      @artifact.update!(status: status)

      get artifact_reviews_path(@artifact)

      assert_response :success
      assert_select "a[href=?]", artifact_review_path(@artifact, review), count: 1
      assert_select "p", text: I18n.t("reviews.index.empty"), count: 0

      get artifact_review_path(@artifact, review)

      assert_response :success
      assert_select "p", text: /閲覧対象レビュー/
    end
  end

  %i[reviewer approver].each do |role|
    test "#{role}はdraftのReview一覧と詳細を閲覧できない" do
      review = @artifact.reviews.create!(user: users(:reviewer), result: :ok, comment: "閲覧対象レビュー")
      @artifact.update!(status: :draft)
      log_in_as(users(role))

      [artifact_reviews_path(@artifact), artifact_review_path(@artifact, review)].each do |path|
        get path

        assert_redirected_to artifacts_path
        assert_equal I18n.t("flash.artifact.ensure_viewable"), flash[:alert]

        follow_redirect!

        assert_response :success
        assert_select "p", text: "閲覧許可がありません"
        assert_select "a[href=?]", artifact_review_path(@artifact, review), count: 0
        assert_select "p", text: /閲覧対象レビュー/, count: 0
      end
    end

    test "#{role}は現在ラウンドで自分のReviewを提出すると他のReviewを閲覧できる" do
      other_role = role == :reviewer ? :approver : :reviewer
      review = @artifact.reviews.build(user: users(other_role), result: :uneasy, comment: "提出済みのコメント")
      review.save_with_review_issues!(%w[direction_issue])
      log_in_as(users(role))

      get artifact_reviews_path(@artifact)

      assert_response :success
      assert_select "p", text: I18n.t("reviews.index.empty")
      assert_select "a[href=?]", artifact_review_path(@artifact, review), count: 0
      assert_not_includes response.body, review.comment

      get artifact_review_path(@artifact, review)

      assert_response :not_found
      assert_not_includes response.body, review.comment

      assert_review_summary

      post artifact_reviews_path(@artifact), params: {
        review: { result: "ok", comment: "自分のコメント" }
      }

      own_review = @artifact.reviews.find_by!(user: users(role))
      assert_redirected_to artifact_review_path(@artifact, own_review)
      follow_redirect!
      assert_response :success

      get artifact_reviews_path(@artifact)

      assert_response :success
      assert_select "section h2", text: "第1回", count: 1
      assert_select "tbody tr", count: 2
      assert_select "tbody tr", text: /#{review.user.name}\s*#{review.result_label}\s*#{review.comment}/ do
        assert_select "a[href=?]", artifact_review_path(@artifact, review), text: review.user.name
      end
      assert_select "a[href=?]", artifact_review_path(@artifact, own_review), text: own_review.user.name

      get artifact_review_path(@artifact, review)

      assert_response :success
      assert_select "p", text: /#{review.comment}/
      assert_select "p", text: ReviewIssue.issue_type_label(:direction_issue)

      assert_review_summary(["第1回", "2", "1", "1", "0"])
    end
  end

  test "Creatorは全員の提出を待たずにReviewの内容と集計を閲覧できる" do
    review = @artifact.reviews.create!(user: users(:approver), result: :ng, comment: "差し戻しのコメント")
    assert_predicate @artifact.reload, :reviewing?
    log_in_as(users(:creator))

    get artifact_reviews_path(@artifact)

    assert_response :success
    assert_select "tbody tr", text: /#{review.user.name}\s*#{review.result_label}\s*#{review.comment}/

    get artifact_review_path(@artifact, review)

    assert_response :success
    assert_select "p", text: /#{review.comment}/

    assert_review_summary(["第1回", "1", "0", "0", "1"])
  end

  %i[reviewer approver].each do |role|
    test "再提出後の#{role}には過去ラウンドのReviewだけが公開される" do
      previous_review = @artifact.reviews.create!(user: users(:reviewer), result: :ok, comment: "過去ラウンドのレビュー")
      previous_approver_review = @artifact.reviews.create!(user: users(:approver), result: :uneasy)
      @artifact.file.attach(fixture_file_upload("sample.txt", "text/plain"))
      log_in_as(users(:creator))
      patch resubmit_artifact_path(@artifact)
      assert_redirected_to artifact_path(@artifact)
      assert_equal 2, @artifact.reload.current_round

      other_role = role == :reviewer ? :approver : :reviewer
      current_review = @artifact.reviews.create!(user: users(other_role), result: :uneasy, comment: "現在ラウンドのレビュー")
      log_in_as(users(role))

      get artifact_reviews_path(@artifact)

      assert_response :success
      assert_select "section h2", text: "第1回", count: 1
      assert_select "section h2", text: "第2回", count: 0
      [previous_review, previous_approver_review].each do |review|
        assert_select "a[href=?]", artifact_review_path(@artifact, review), count: 1
      end
      assert_select "a[href=?]", artifact_review_path(@artifact, current_review), count: 0
      assert_not_includes response.body, current_review.comment

      get artifact_review_path(@artifact, previous_review)

      assert_response :success
      assert_select "p", text: /過去ラウンドのレビュー/

      get artifact_review_path(@artifact, current_review)

      assert_response :not_found
      assert_review_summary(["第1回", "2", "1", "1", "0"])

      post artifact_reviews_path(@artifact), params: { review: { result: "ok" } }
      assert_response :redirect

      get artifact_reviews_path(@artifact)

      assert_response :success
      assert_equal ["第1回", "第2回"], css_select("section h2").map(&:text)
      assert_select "a[href=?]", artifact_review_path(@artifact, current_review), count: 1
      assert_review_summary(["第1回", "2", "1", "1", "0"], ["第2回", "2", "1", "1", "0"])
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
    assert_select "p", text: I18n.t("reviews.index.empty"), count: 1
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

        expected_redirect = status == :draft ? artifacts_path : artifact_path(@artifact)
        assert_review_creation_denied(expected_redirect: expected_redirect)
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

      expected_redirect = role == :unassigned_user ? artifacts_path : artifact_path(@artifact)
      assert_review_creation_denied(expected_redirect: expected_redirect)
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

  def assert_review_summary(*expected_rows)
    get artifact_path(@artifact)

    assert_response :success
    assert_equal expected_rows, css_select("table tbody tr").map { |row| row.css("td").map { |cell| cell.text.strip } }
  end

  def assert_review_creation_denied(expected_redirect: artifact_path(@artifact))
    original_status = @artifact.reload.status
    original_round = @artifact.current_round

    assert_no_difference(["Review.count", "ReviewIssue.count"]) do
      get new_artifact_review_path(@artifact)
    end

    assert_redirected_to expected_redirect
    assert_equal I18n.t("flash.review.not_authorized"), flash[:alert]
    assert_equal original_status, @artifact.reload.status
    assert_equal original_round, @artifact.current_round

    assert_no_difference(["Review.count", "ReviewIssue.count"]) do
      post artifact_reviews_path(@artifact), params: {
        review: { result: "uneasy", issue_types: [ReviewIssue.issue_types.keys.first] }
      }
    end

    assert_redirected_to expected_redirect
    assert_equal I18n.t("flash.review.not_authorized"), flash[:alert]
    assert_equal original_status, @artifact.reload.status
    assert_equal original_round, @artifact.current_round
  end
end
