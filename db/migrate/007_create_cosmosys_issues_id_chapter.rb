class CreateCosmosysIssuesIdChapter < ActiveRecord::Migration[5.2]
	def up

		##### CREATE TABLES

		tracker_ids = []
		Tracker.all.each{|tr|
			tracker_ids << tr.id
		}
		roles_ids = []
		Role.all.each{|tr|
			roles_ids << tr.id
		}
		status_ids = []
		IssueStatus.all.each{|st|
			status_ids << st.id
		}

		csid = IssueCustomField.create!(:name => 'csID', 
				:field_format => 'string', :description => "copy of internal cosmosys ID",
				:is_for_all => true, :searchable => true, :is_filter => true, :tracker_ids => tracker_ids)

		cschapter = IssueCustomField.create!(:name => 'csChapter', 
			:field_format => 'string', :description => "copy of internal cosmosys chapter",
			:is_for_all => true, :searchable => true, :is_filter => true, :tracker_ids => tracker_ids)

		tracker_ids.each{|trid|
			roles_ids.each{|rid|
				status_ids.each{|sid|
					WorkflowPermission.create(:role_id => rid, :tracker_id => trid, :old_status_id => sid, :field_name => csid.id, :rule => "readonly")
					WorkflowPermission.create(:role_id => rid, :tracker_id => trid, :old_status_id => sid, :field_name => cschapter.id, :rule => "readonly")
				}
			}
		}

	end

	def down

		cschapter = IssueCustomField.find_by_name('csChapter')
		csid = IssueCustomField.find_by_name('csID')
=begin
		WorkflowPermission.all.each{|wfp|
			if (csid != nil and wfp.field_name == csid.id) or (cschapter != nil and wfp.field_name == cschapter.id) then
				wfp.destroy
			end
		}
=end
		if (cschapter != nil) then
			cschapter.destroy
		end		

		if (csid != nil) then
			csid.destroy
		end
	end
end
