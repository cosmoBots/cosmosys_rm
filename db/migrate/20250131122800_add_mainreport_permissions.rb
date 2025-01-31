class AddMainreportPermissions < ActiveRecord::Migration[5.2]
  def up
    Role.all.each {|r|
      rps = r.permissions; rps.append(:csys_show)
    }
  end
end
