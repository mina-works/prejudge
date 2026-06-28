class ReviewsController < ApplicationController

  before_action :set_artifact,
                only: [:index, :show, :new, :create]

  def index
    @reviews = @artifact.reviews
  end

  def show
    @review = @artifact.reviews.find(
      params[:id]
    )
  end
  
  def new
    @review = @artifact.reviews.build
  end

  def create
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

      flash[:notice] = t("flash.review.created")
      redirect_to [@artifact, @review]

    rescue ActiveRecord::RecordInvalid => e
      @review.errors.add(
        :base,
        e.record.errors.full_messages.join(", ")
      )
      
      render :new, status: :unprocessable_entity
    end
  end


  private

  def set_artifact
    @artifact = Artifact.find(
      params[:artifact_id]
    )
  end

end
