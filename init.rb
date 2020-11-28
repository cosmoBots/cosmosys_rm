Redmine::Plugin.register :cosmosys do
  name 'Cosmosys plugin'
  author 'Txinto Vaz'
  description 'This is a plugin for Redmine, which converts it into a CosmoSys instance'
  version '0.0.1'
  url 'http://cosmobots.eu'
  author_url 'http://cosmobots.eu'

  permission :csys_menu, :cosmosys => :menu
  permission :csys_tree, :cosmosys => :tree
  permission :csys_treeview, :cosmosys => :treeview
  permission :csys_show, :cosmosys => :show
  permission :csys_up, :cosmosys => :up
  permission :csys_down, :cosmosys => :down  

  menu :project_menu, :cosmosys, {:controller => 'cosmosys', :action => 'menu' }, :caption => 'cosmoSys', :after => :activity, :param => :id
  #menu :project_menu, :cosmosys_tree, {:controller => 'cosmosys', :action => 'tree' }, :caption => 'cSysTree', :after => :issues, :param => :id
  menu :project_menu, :cosmosys_treeview, {:controller => 'cosmosys', :action => 'treeview' }, :caption => 'cSysTreeView', :after => :issues, :param => :id
  menu :project_menu, :cosmosys_show, {:controller => 'cosmosys', :action => 'show' }, :caption => 'cSysShow', :after => :issues, :param => :id

  require 'cosmosys'
  # Patches to the Redmine core.
  require 'tracker_patch'
  require 'user_patch'
  require 'project_patch'
  require 'version_patch'
  require 'issue_patch'
end
