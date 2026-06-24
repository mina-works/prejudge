class ArtifactsController < ApplicationController

  before_action :set_artifact,
                only: [:show, :resubmit]

  def index
    @artifacts = Artifact.all
  end

  def show
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

  def resubmit
    @artifact.resubmit!

    redirect_to @artifact,
      notice: t("flash.artifact.resubmitted")

  rescue ActiveRecord::RecordInvalid => e
    redirect_to @artifact,
      alert: e.record.errors.full_messages.join(", ")
  end

  private

  def set_artifact
    @artifact = Artifact.find(params[:id])
  end

  def artifact_params
    params.require(:artifact).permit(
      :title,
      :description,
      :creator_id,
      :review_deadline
    )
  end
end
