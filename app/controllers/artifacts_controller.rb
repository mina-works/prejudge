class ArtifactsController < ApplicationController

  before_action :set_artifact,
                only: %i[
                  show
                  edit
                  update
                  submit
                  resubmit
                  destroy
                ]
  
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
    @artifact = Artifact.new(artifact_params)
    @artifact.save_with_review_members!

    flash[:notice] = t("flash.artifact.created")
    redirect_to @artifact

  rescue ActiveRecord::RecordInvalid => e
    # Artifact以外の関連モデルで発生したエラーだけを追加する
    unless e.record.equal?(@artifact)
      e.record.errors.full_messages.each do |message|
        @artifact.errors.add(:base, message)
      end
    end

    @users = User.all

    render :new,
          status: :unprocessable_entity
  end

  def edit
    @users = User.all
  end

  def update
    # DBへ保存せず、フォームの入力値を@artifactへ代入する
    @artifact.assign_attributes(artifact_params)

    # Artifact本体とReviewer・Approverをまとめて保存する
    @artifact.save_with_review_members!

    flash[:notice] = t("flash.artifact.updated")
    redirect_to @artifact

  rescue ActiveRecord::RecordInvalid => e
    # ArtifactReviewerなど、Artifact以外で発生したエラーだけを
    # Artifactのエラーとしてフォームに表示する
    unless e.record.equal?(@artifact)
      e.record.errors.full_messages.each do |message|
        @artifact.errors.add(:base, message)
      end
    end

    @users = User.all

    render :edit, status: :unprocessable_entity
  end

  def destroy
    if @artifact.destroy
      redirect_to artifacts_path,
                  notice: "成果物を削除しました。",
                  status: :see_other
    else
      redirect_to @artifact,
                  alert: @artifact.errors.full_messages.to_sentence,
                  status: :see_other
    end
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
