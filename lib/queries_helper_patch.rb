require_dependency 'queries_helper'

module QueriesHelperPatch
  def column_content(column, item)
    #puts(column.to_json)
    value = column.value_object(item)
    if value.is_a?(Array)
      values = value.collect {|v| column_value(column, item, v)}.compact
      safe_join(values, ', ')
    else
      ret = column_value(column, item, value)
      puts(column.name)
      puts(ret)
      if (column.name.to_s == "id") then
        ret = ret + '|' + item.identifier
        puts("Tendría que habrer añadido algo")
      end
      ret
    end
  end

end

module QueriesHelper
  prepend QueriesHelperPatch
end


