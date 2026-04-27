class CreateReviewIssues < ActiveRecord::Migration[7.1]
  def change
    create_table :review_issues do |t|
      t.references :review, null: false, foreign_key: true
      t.integer :issue_type, null: false

      t.timestamps
    end
  end
end
