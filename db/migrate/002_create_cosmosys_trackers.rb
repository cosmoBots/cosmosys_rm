class CreateCosmosysTrackers < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_trackers do |t|
      t.references :tracker, foreign_key: true
      t.string :diag_shape, default: 'Mrecord'
    end
    #add_index :cosmosys_trackers, :tracker_id
  end
end
