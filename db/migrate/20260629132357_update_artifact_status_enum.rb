class UpdateArtifactStatusEnum < ActiveRecord::Migration[7.1]
  def up
    Artifact.where(status: 3).update_all(status: 4)
    Artifact.where(status: 2).update_all(status: 3)
    Artifact.where(status: 1).update_all(status: 2)
  end

  def down
    Artifact.where(status: 4).update_all(status: 3)
    Artifact.where(status: 3).update_all(status: 2)
    Artifact.where(status: 2).update_all(status: 1)
  end
end
