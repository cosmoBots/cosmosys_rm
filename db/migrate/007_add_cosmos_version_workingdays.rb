class AddCosmosVersionWorkingdays < ActiveRecord::Migration[5.2]
  def change
    add_column :cosmosys_versions, :working_days, :integer
  end
end

