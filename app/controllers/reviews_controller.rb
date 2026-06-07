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

      redirect_to review_path(@review)

    rescue ActiveRecord::RecordInvalid => e
      @review.errors.add(
        :base,
        e.record.errors.full_messages.join(", ")
      )
      
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @review = Review.find(params[:id])
  end

end
