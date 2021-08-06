class AddCsidToCosmosysIssue < ActiveRecord::Migration[5.2]
  def up
    add_column :cosmosys_issues, :csid_id, :integer, foreign_key: { to_table: :custom_values}
    add_index :cosmosys_issues, :csid_id
  end
  def down
    remove_index :cosmosys_issues, :csid_id
    remove_column :cosmosys_issues, :csid_id
  end
end
