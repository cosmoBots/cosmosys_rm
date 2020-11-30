class CreateCosmosysProjects < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_projects do |t|
      t.string :prefix
      t.integer :id_counter, null: false, default: 0
      t.integer :project_id, foreign_key: true
    end
    add_index :cosmosys_projects, :project_id
  end
end
