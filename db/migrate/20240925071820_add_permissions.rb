class AddPermissions < ActiveRecord::Migration[5.2]
  def up
		Role.all.each{|tr|
			changed = false

=begin
  permission :csys_iss_dep_gv, :cosmosys_issues => :dep_gv
  permission :csys_iss_hie_gv, :cosmosys_issues => :hie_gv
  permission :csys_dep_gv, :cosmosys => :dep_gv
  permission :csys_hie_gv, :cosmosys => :hie_gv
=end

			if tr.permissions.include?(:view_issues) then
				tr.permissions += [
					:csys_iss_dep_gv,
					:csys_iss_hie_gv,
					:csys_dep_gv,
					:csys_hie_gv
				]
				changed = true
			end
			if changed then
				tr.save
			end
		}
  end

  def down

  end
end
