class CreateCosmosysVersions < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_versions do |t|
      t.date :start_date
      t.references :cosmosys_version_type, foreign_key: true
      t.references :version, foreign_key: true
    end
    #add_index :cosmosys_versions, :version_id
    #add_index :cosmosys_version_types, :version_type_id
		Version.all.each{|v|
      cv = CosmosysVersion.create!(version: v)
		} 
  end
end
