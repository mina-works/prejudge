class ReviewsController < ApplicationController
  def new
    @review = Review.new

    # @review.review_issues.build
  end

  def create
    @review = Review.new(review_params)

    if @review.save
      # redirect_to root_path
      redirect_to new_review_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def review_params
    params.require(:review).permit(
      :artifact_id,
      :user_id,
      :result,
      :comment,
      # review_issues_attributes: [:issue_type]
    )
  end
end
