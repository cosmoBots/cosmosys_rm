class AddCsReportMetadata < ActiveRecord::Migration[5.2]
  def up

		cfProjectMetadata = ProjectCustomField.create!(:name => 'csReportMetadata',
      :field_format => 'text',
      :searchable => false,
			:description => "YAML description of the issue metadata shown in the Reports",
      :min_length => '', :max_length => '', :regexp => '',
      :full_width_layout => "1", :text_formatting => "full",
      :default_value => '',
			:is_required => true,
			:is_for_all => true)

    Project.all.each{|p|
      p.reload
      thiscv = p.custom_field_values.select{|a| a.custom_field_id == cfProjectMetadata.id }.first
      if (thiscv.value != cfProjectMetadata.default_value) then
        thiscv.value = cfProjectMetadata.default_value
        p.save
      end
    }
  end

  def down
		tmp = ProjectCustomField.find_by_name('csReportMetadata')
		if (tmp != nil) then
			tmp.destroy
		end
  end

end
