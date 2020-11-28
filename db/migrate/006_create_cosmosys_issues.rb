class CreateCosmosysIssues < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_issues do |t|
      t.string :identifier
      t.float :chapter_order
      t.references :issue, foreign_key: true
      t.references :cosmosys_project, foreign_key: true
    end
    #add_index :cosmosys_issues, :issue_id
  end
end
