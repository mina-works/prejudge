require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @reviewer = users(:reviewer)
    @unassigned_user = users(:unassigned_user)
    
    # Reviewerが担当者として登録されているArtifactを取得する
    @artifact = artifacts(:review_create_test_artifact)
  end

  test "Reviewerは自分自身としてReviewを登録できる" do
    log_in_as(@reviewer)

    assert_difference("Review.count", 1) do
      post artifact_reviews_path(@artifact), params: {
        review: {
          result: "ok",
          comment: "問題ありません"
        }
      }
    end

    # Reviewの実行者がログイン中のReviewerであることを確認する
    assert_equal @reviewer, Review.last.user
  end

  test "担当者ではないユーザーはReviewを登録できない" do
    log_in_as(@unassigned_user)

    assert_no_difference("Review.count") do
      post artifact_reviews_path(@artifact), params: {
        review: {
          result: "ok"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
