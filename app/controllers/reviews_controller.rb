class ReviewsController < ApplicationController
  def index
    @reviews = Review.all
  end

  def show
    @artifact = Artifact.find(
      params[:artifact_id]
    )

    @review = @artifact.reviews.find(
      params[:id]
    )
  end
  
  def new
    @artifact = Artifact.find(
      params[:artifact_id]
    )
    
    @review = @artifact.reviews.build
  end

  def create
    @artifact = Artifact.find(
      params[:artifact_id]
    )
    permitted_review = params.require(:review).permit(
      :user_id,
      :result,
      :comment,
      issue_types: []
    )

    issue_types = permitted_review.delete(:issue_types)

    @review = @artifact.reviews.build(
      permitted_review
    )

    begin
      Review.transaction do
        @review.save!

        @review.create_review_issues(
          issue_types
        )
      end

      redirect_to artifact_review_path(
        @artifact,
        @review
      )

    rescue ActiveRecord::RecordInvalid => e
      @review.errors.add(
        :base,
        e.record.errors.full_messages.join(", ")
      )
      
      render :new, status: :unprocessable_entity
    end
  end

end
