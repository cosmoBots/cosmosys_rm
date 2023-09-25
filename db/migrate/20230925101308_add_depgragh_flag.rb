class AddDepgraghFlag < ActiveRecord::Migration[5.2]
  def up
    posval = ['Include if has relations', 'Include', 'Not include']
    rqdephgraphsfield = IssueCustomField.create!(:name => 'depGrahInReports', 
      :field_format => 'list', :possible_values => posval, 
      :description => 'Include',
      :is_filter => true, :is_required => true,
      :default_value => posval[0],
      :is_for_all => true, :trackers => Tracker.all)

    Issue.all.each{|i|
      i.reload
      thiscv = i.custom_field_values.select{|a| a.custom_field_id == rqdephgraphsfield.id }.first
      thiscv.value = rqdephgraphsfield.default_value
      i.save
    }
  end

  def down
		tmp = IssueCustomField.find_by_name('depGrahInReports')
		if (tmp != nil) then
			tmp.destroy
		end    
  end
end
