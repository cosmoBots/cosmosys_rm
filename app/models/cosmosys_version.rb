class CosmosysVersion < ActiveRecord::Base
  belongs_to :version
  belongs_to :cosmosys_version_type

  ## TODO solve this custom_field dependency
  @@cfvstartdate = VersionCustomField.find_by_name('Start date')
  def vstart_date
    if self.start_date == nil then
      self.version.custom_values.find_by_custom_field_id(@@cfvstartdate.id).value
    else
      return self.start_date
    end
  end

  @@cfvwd = VersionCustomField.find_by_name('Working days')
  def vworking_days
    if self.working_days == nil then
      self.version.custom_values.find_by_custom_field_id(@@cfvwd.id).value
    else
      return self.working_days
    end
  end
end

