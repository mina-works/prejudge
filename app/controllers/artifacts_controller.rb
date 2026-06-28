class ArtifactsController < ApplicationController

  before_action :set_artifact,
                only: [:show, :edit, :update, :resubmit]
  
  before_action :ensure_editable,
  only: [:edit, :update]

  before_action :ensure_resubmittable,
  only: [:resubmit]

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

  def edit
  end

  def update
    if @artifact.update(artifact_params)
      redirect_to @artifact,
        notice: t("flash.artifact.updated")
    else
      render :edit,
        status: :unprocessable_entity
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

  def ensure_editable
    return if @artifact.editable?

    redirect_to @artifact,
      alert: t("flash.artifact.not_editable")
  end

  def ensure_resubmittable
    return if @artifact.resubmittable?

    redirect_to @artifact,
      alert: t("flash.artifact.not_resubmittable")
  end
end
