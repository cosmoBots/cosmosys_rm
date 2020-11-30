class CreateCosmosysVersions < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_versions do |t|
      t.date :start_date
      t.integer :cosmosys_version_type_id, foreign_key: true
      t.integer :version_id, foreign_key: true
    end
    add_index :cosmosys_versions, :cosmosys_version_type_id
    add_index :cosmosys_versions, :version_id
  end
end

