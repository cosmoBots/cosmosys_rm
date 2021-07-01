class CreateCosmosysVersions < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_versions do |t|
      t.integer :version_id, foreign_key: true
    end
    add_index :cosmosys_versions, :version_id
  end
end

