class ArtifactsController < ApplicationController
  def index
    @artifacts = Artifact.all
  end

  def show
    @artifact = Artifact.find(params[:id])

    @reviews_by_round =
      @artifact.reviews.group_by(&:round)
  end

  def create
  end
end
