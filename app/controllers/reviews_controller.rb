class ReviewsController < ApplicationController
  def new
    @review = Review.new
  end

  def create
    permitted_review = params.require(:review).permit(
      :artifact_id,
      :user_id,
      :result,
      :comment,
      issue_types: []
    )

    issue_types = permitted_review.delete(:issue_types)

    @review = Review.new(permitted_review)

    begin
      Review.transaction do
        @review.save!

        @review.create_review_issues(
          issue_types
        )
      end

      # redirect_to root_path
      redirect_to new_review_path

    rescue ActiveRecord::RecordInvalid => e
      p e.message
      render :new, status: :unprocessable_entity
    end
  end

end
