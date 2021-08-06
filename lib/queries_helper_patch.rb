require_dependency 'queries_helper'

module QueriesHelperPatch
  # Disabling this column hack because the existence of csID custom value
  def column_content2(column, item)
    #puts(column.to_json)
    value = column.value_object(item)
    if value.is_a?(Array)
      values = value.collect {|v| column_value(column, item, v)}.compact
      safe_join(values, ', ')
    else
      ret = column_value(column, item, value)
      if (column.name.to_s == "id") then
        ret = ret + '|' + item.csys.get_identifier
      end
      ret
    end
  end

end

module QueriesHelper
  prepend QueriesHelperPatch
end


