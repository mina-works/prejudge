require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  setup do
    # テストごとにCreator・Reviewer・Approverを用意する
    @creator = User.create!(
      name: "Creator",
      email: "creator@example.com"
    )

    @reviewer = User.create!(
      name: "Reviewer",
      email: "reviewer@example.com"
    )

    @approver = User.create!(
      name: "Approver",
      email: "approver@example.com"
    )

    # Artifact本体とレビュー担当者を、
    # 実際のアプリと同じ保存処理を使って作成する
    @artifact = Artifact.new(
      title: "テスト用成果物",
      description: "Review作成テスト用",
      creator: @creator,
      status: :pending_review,
      current_round: 1,
      review_deadline: 1.week.from_now,
      reviewer_ids: [@reviewer.id],
      approver_id: @approver.id
    )

    @artifact.save_with_review_members!
  end

  test "Reviewと選択されたReviewIssueを保存できる" do
    review = @artifact.reviews.build(
      user: @reviewer,
      result: :uneasy
    )

    assert_difference("Review.count", 1) do
      assert_difference("ReviewIssue.count", 2) do
        review.save_with_review_issues!(
          %w[wrong_atmosphere tone_mismatch]
        )
      end
    end

    # before_validationによって現在のラウンドが保存される
    assert_equal 1, review.round

    # 選択した違和感項目が保存されていることを確認する
    assert_equal(
      %w[wrong_atmosphere tone_mismatch].sort,
      review.review_issues.pluck(:issue_type).sort
    )
  end

  test "最初のReviewが作成されるとArtifactがreviewingになる" do
    review = @artifact.reviews.build(
      user: @reviewer,
      result: :ok
    )

    review.save_with_review_issues!([])

    # after_createでArtifactの状態が更新されるため、
    # DBから再読み込みして確認する
    assert_predicate @artifact.reload, :reviewing?
  end

  test "ReviewerとApproverのReviewが完了しApproverがokならreviewedになる" do
    reviewer_review = @artifact.reviews.build(
      user: @reviewer,
      result: :ok
    )

    reviewer_review.save_with_review_issues!([])

    # Reviewerだけが完了した時点では、まだreviewing
    assert_predicate @artifact.reload, :reviewing?

    approver_review = @artifact.reviews.build(
      user: @approver,
      result: :ok
    )

    approver_review.save_with_review_issues!([])

    # Reviewer全員とApproverのReviewが完了し、
    # Approverがokなのでreviewedになる
    assert_predicate @artifact.reload, :reviewed?
  end

  test "Approverがuneasyならrevision_requiredになる" do
    reviewer_review = @artifact.reviews.build(
      user: @reviewer,
      result: :ok
    )

    reviewer_review.save_with_review_issues!([])

    approver_review = @artifact.reviews.build(
      user: @approver,
      result: :uneasy
    )

    approver_review.save_with_review_issues!(
      %w[direction_issue]
    )

    # Approverがok以外を選択したため差し戻しになる
    assert_predicate @artifact.reload, :revision_required?
  end

  test "Approverが先にReviewしてもReviewer完了まではreviewingのままになる" do
    approver_review = @artifact.reviews.build(
      user: @approver,
      result: :ok
    )

    approver_review.save_with_review_issues!([])

    # Approverが完了していてもReviewerが未完了なので、
    # 最終状態には遷移しない
    assert_predicate @artifact.reload, :reviewing?

    reviewer_review = @artifact.reviews.build(
      user: @reviewer,
      result: :ok
    )

    reviewer_review.save_with_review_issues!([])

    # Reviewerも完了した時点でreviewedになる
    assert_predicate @artifact.reload, :reviewed?
  end

  test "ReviewIssueの保存に失敗した場合はReviewと状態遷移をロールバックする" do
    review = @artifact.reviews.build(
      user: @reviewer,
      result: :ok
    )

    # okのReviewはReviewIssueを持てないため、
    # ReviewIssueのバリデーションエラーになる
    assert_no_difference(["Review.count", "ReviewIssue.count"]) do
      assert_raises(ActiveRecord::RecordInvalid) do
        review.save_with_review_issues!(
          %w[wrong_atmosphere]
        )
      end
    end

    # Review作成後のコールバックで一度状態更新処理が呼ばれても、
    # 同じトランザクション内なのでDB上の変更は元に戻る
    assert_predicate @artifact.reload, :pending_review?
  end
end