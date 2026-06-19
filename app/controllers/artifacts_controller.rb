class ArtifactsController < ApplicationController
  def index
    @artifacts = Artifact.all
  end

  def show
    @artifact = Artifact.find(params[:id])

    @reviews_by_round =
      @artifact.reviews.group_by(&:round)
  end

  def new
    @artifact = Artifact.new
  end

  def create
    @artifact = Artifact.new(artifact_params)

    if @artifact.save
      redirect_to @artifact
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def artifact_params
    params.require(:artifact).permit(
      :title,
      :description,
      :creator_id,
      :review_deadline
    )
  end
end
