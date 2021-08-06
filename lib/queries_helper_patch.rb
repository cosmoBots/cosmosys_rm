require_dependency 'queries_helper'

module QueriesHelperPatch
  @@chapid_str = "cf_"+IssueCustomField.find_by_name("csChapter").id.to_s
  def column_content(column, item)
    if (column.name.to_s == @@chapid_str) then
      ret = item.csys.chapter_str
      ret
    else
      #puts(column.to_json)
      value = column.value_object(item)
      if value.is_a?(Array)
        values = value.collect {|v| column_value(column, item, v)}.compact
        safe_join(values, ', ')
      else
        ret = column_value(column, item, value)
        # Disabling this column hack because the existence of csID custom value
        #if (column.name.to_s == "id") then
        #  ret = ret + '|' + item.csys.get_identifier
        #end         
        ret
      end
    end
  end

end

module QueriesHelper
  prepend QueriesHelperPatch
end


