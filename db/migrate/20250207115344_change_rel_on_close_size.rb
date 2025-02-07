class ChangeRelOnCloseSize < ActiveRecord::Migration[5.2]
  def up
    change_column :cosmosys_issues, :relations_on_close, :text
  end
  def down
    # This might cause trouble if you have strings longer
    # than 255 characters.
    change_column :cosmosys_issues, :relations_on_close, :string
  end
end
