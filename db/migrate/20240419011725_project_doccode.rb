class ProjectDoccode < ActiveRecord::Migration[5.2]
  def up
    ##### CREATE TABLES
    cfProjectDocCode = ProjectCustomField.create!(:name => 'csDocCode', 
      :field_format => 'string', :searchable => false,
      :description => "Code for Report Document",
      :is_required => true,
      :is_for_all => true)
      
    Project.all.each{|p|
      cv = p.custom_values.new
      cv.custom_field = cfProjectDocCode
      cv.value = p.csys.code
      cv.save
    }
  end

  def down
    cfProjectDocCode = IssueCustomField.find_by_name('csDocCode')
    if (cfProjectDocCode != nil) then
      cfProjectDocCode.destroy
    end
  end
  
end
