class AddCosmosIssueSupervisor < ActiveRecord::Migration[5.2]
  def change
    add_reference :cosmosys_issues, :supervisor, index: true
  end
end

