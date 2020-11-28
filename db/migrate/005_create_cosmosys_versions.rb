class CreateCosmosysVersions < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_versions do |t|
      t.date :start_date
      t.references :cosmosys_version_type, foreign_key: true
      t.references :version, foreign_key: true
    end
  end
end
