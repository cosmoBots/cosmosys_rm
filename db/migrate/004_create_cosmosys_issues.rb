class CreateCosmosysIssues < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_issues do |t|
      t.string :identifier
      t.float :chapter_order
      t.integer :issue_id, foreign_key: true
      t.integer :cosmosys_project_id, foreign_key: true
      t.integer :wloadpct
    end
    add_index :cosmosys_issues, :issue_id
    add_index :cosmosys_issues, :cosmosys_project_id
  end
end
