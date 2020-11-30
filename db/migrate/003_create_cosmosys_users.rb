class CreateCosmosysUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_users do |t|
      t.boolean :gen_rpt, default: false
      t.integer :user_id, foreign_key: true
    end
    add_index :cosmosys_users, :user_id
  end
end
