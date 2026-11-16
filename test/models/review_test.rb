require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  setup do
    # テストごとにCreator・Reviewer・Approverを用意する
    @creator = users(:creator)
    @reviewer = users(:reviewer)
    @approver = users(:approver)

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
      approver_id: @approver.id,
      review_condition_attributes: {
        purpose: "レビュー目的",
        target: :job_seekers,
        tone: :friendly
      }
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

  { ok: :reviewed, uneasy: :revision_required, ng: :revision_required }.each do |result, final_status|
    test "Approverが先に#{result}を提出してもReviewer全員の提出で初めて#{final_status}になる" do
      second_reviewer = users(:unassigned_user)
      @artifact.artifact_reviewers.create!(user: second_reviewer, role: :reviewer)
      @artifact.reviews.build(user: @approver, result: result).save_with_review_issues!([])
      assert_predicate @artifact.reload, :reviewing?

      @artifact.reviews.build(user: @reviewer, result: :ok).save_with_review_issues!([])
      assert_predicate @artifact.reload, :reviewing?

      @artifact.reviews.build(user: second_reviewer, result: :ok).save_with_review_issues!([])
      assert_equal final_status.to_s, @artifact.reload.status
    end
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

  test "最後の提出でReviewIssueの保存に失敗するとReviewと最終状態への遷移をロールバックする" do
    submitted_review = @artifact.reviews.build(user: @reviewer, result: :uneasy)
    submitted_review.save_with_review_issues!(%w[tone_mismatch])
    assert_predicate @artifact.reload, :reviewing?

    final_review = @artifact.reviews.build(user: @approver, result: :ok)

    assert_no_difference(["Review.count", "ReviewIssue.count"]) do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        final_review.save_with_review_issues!(%w[wrong_atmosphere])
      end

      assert_instance_of ReviewIssue, error.record
      assert_same final_review, error.record.review
      assert_includes error.record.errors[:base], I18n.t("errors.review_issue.review_is_ok")
    end

    # after_createによる更新はメモリ上に残るが、DBには保存されない
    assert_predicate @artifact, :reviewed?
    assert_predicate @artifact.reload, :reviewing?
    assert_equal [submitted_review.id], @artifact.current_round_reviews.ids
    assert_equal ["tone_mismatch"], submitted_review.reload.review_issues.pluck(:issue_type)

    @artifact.reviews.build(user: @approver, result: :ok).save_with_review_issues!([])
    assert_predicate @artifact.reload, :reviewed?
  end

  test "レビューできない状態のエラーを内容に合った日本語で表示する" do
    @artifact.status = :draft
    review = @artifact.reviews.build(
      user: @reviewer,
      result: :ok
    )

    assert_not review.valid?
    assert_includes(
      review.errors.full_messages,
      "成果物はレビュー待ちまたはレビュー中の場合のみレビューできます"
    )
  end
end
