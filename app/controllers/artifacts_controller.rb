class ArtifactsController < ApplicationController
  def index
    @artifacts = Artifact.all
  end

  def show
    @artifact = Artifact.find(params[:id])
  end

  def create
  end
end
