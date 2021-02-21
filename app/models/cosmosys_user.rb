class CosmosysUser < ActiveRecord::Base
  belongs_to :user

  @@cfgenreport = UserCustomField.find_by_name('GenReport')

  def vgen_rpt
    if true then #self.gen_rpt == nil then
      ret = false
      supid = self.user.custom_values.find_by_custom_field_id(@@cfgenreport.id)
      if supid != nil then
        sup = supid.value
        if sup != nil then
          if sup != "0" then
            ret = true
          end
        end
      end
      return ret
    else
      return self.gen_rpt
    end
  end

end
