class ArtifactsController < ApplicationController

  before_action :set_artifact,
                only: [:show, :edit, :update, :submit, :resubmit]
  
  before_action :ensure_editable,
  only: [:edit, :update]

  before_action :ensure_resubmittable,
  only: [:resubmit]

  before_action :ensure_submittable,
  only: [:submit]

  def index
    @artifacts = Artifact.all
  end

  def show
    @reviews_by_round =
      @artifact.reviews.group_by(&:round)
  end

  def new
    @artifact = Artifact.new
    @users = User.all
  end

  def create
    artifact_attributes = artifact_params.except(
      :reviewer_ids,
      :approver_id
    )

    reviewer_ids = artifact_params[:reviewer_ids]
    approver_id  = artifact_params[:approver_id]

    @artifact = Artifact.new(artifact_attributes)

    Artifact.transaction do
      @artifact.save!

      @artifact.assign_review_members(
        reviewer_ids,
        approver_id
      )
    end

    flash[:notice] = t("flash.artifact.created")
    redirect_to @artifact

  rescue ActiveRecord::RecordInvalid => e
    @artifact.errors.add(
      :base,
      e.record.errors.full_messages.join(", ")
    )

    @users = User.all

    render :new,
          status: :unprocessable_entity
  end

  def edit
    @users = User.all
  end

  def update
    artifact_attributes = artifact_params.except(
        :reviewer_ids,
        :approver_id
      )

    reviewer_ids = artifact_params[:reviewer_ids]
    approver_id  = artifact_params[:approver_id]

    # ArtifactとReviewer・Approverを一緒に更新する
    Artifact.transaction do
      @artifact.update!(artifact_attributes)

      @artifact.assign_review_members(
        reviewer_ids,
        approver_id
      )
    end

    flash[:notice] = t("flash.artifact.updated")
    redirect_to @artifact

  rescue ActiveRecord::RecordInvalid => e
    @artifact.errors.add(
      :base,
      e.record.errors.full_messages.join(", ")
    )

    @users = User.all

    render :edit, status: :unprocessable_entity
  end

  def submit
    @artifact.submit!

    redirect_to @artifact,
      notice: t("flash.artifact.submitted")

  rescue ActiveRecord::RecordInvalid => e
    redirect_to @artifact,
      alert: e.record.errors.full_messages.join(", ")
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
      :review_deadline,
      :approver_id,
      reviewer_ids: []
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

  def ensure_submittable
    return if @artifact.submittable?

    redirect_to @artifact,
      alert: t("flash.artifact.not_submittable")
  end
end
