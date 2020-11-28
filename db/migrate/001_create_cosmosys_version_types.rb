class CreateCosmosysVersionTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_version_types do |t|
      t.string :name
    end 
		CosmosysVersionType.create!(name:"Milestone")
		CosmosysVersionType.create!(name:"Release")
		CosmosysVersionType.create!(name:"Deliverable")
  end
end
