class CreateCosmosysTrackers < ActiveRecord::Migration[5.2]
  def change
    create_table :cosmosys_trackers do |t|
      t.references :tracker, foreign_key: true
      t.string :diag_shape
    end
    #add_index :cosmosys_trackers, :tracker_id
    
		Tracker.all.each{|tr|
      ct = CosmosysTracker.create!(tracker: tr)
		}    
  end
end
