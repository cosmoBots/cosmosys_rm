class CreateCosmosysProjects < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_projects do |t|
      t.string :prefix
      t.integer :id_counter, null: false, default: 0
      t.references :project, foreign_key: true
    end
  end
end
