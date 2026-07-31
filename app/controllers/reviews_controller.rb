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
    # Strong Parametersで許可した値を取得する
    permitted_review = review_params

    # Reviewテーブルに存在しないissue_typesを取り出す
    issue_types = permitted_review.delete(:issue_types)

    # Artifactに関連付いたReviewを組み立てる
    @review = @artifact.reviews.build(
      permitted_review
    )

    begin
      # Review本体とReviewIssueの保存はModelに任せる
      @review.save_with_review_issues!(issue_types)

      flash[:notice] = t("flash.review.created")
      redirect_to [@artifact, @review]

    rescue ActiveRecord::RecordInvalid
      
      render :new, status: :unprocessable_entity
    end
  end


  private

  def set_artifact
    @artifact = Artifact.find(
      params[:artifact_id]
    )
  end

  # フォームから送られたReview用の値だけを許可する
  def review_params
    params.require(:review).permit(
      :user_id,
      :result,
      :comment,
      issue_types: []
    )
  end

end
