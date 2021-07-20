class CreateCosmosysProjectCode < ActiveRecord::Migration[5.2]
	def up
		##### CREATE TABLES
		cfProjectCode = ProjectCustomField.create!(:name => 'csCode', 
			:field_format => 'string', :searchable => false,
			:description => "Code for item IDs",
			:is_required => true,
			:is_for_all => true)
			
		Project.all.each{|p|
			cv = p.custom_values.new
			cv.custom_field = cfProjectCode
			cv.value = p.identifier
			cv.save
		}

	end

	def down
		cfProjectCode = IssueCustomField.find_by_name('RqPrefix')
		if (cfProjectCode != nil) then
			cfProjectCode.destroy
		end
	end
end
