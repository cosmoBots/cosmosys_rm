Redmine::Plugin.register :cosmosys do
  name 'Cosmosys plugin'
  author 'Txinto Vaz'
  description 'This is a plugin for Redmine, which converts it into a CosmoSys instance'
  version '0.0.2'
  url 'http://cosmobots.eu'
  author_url 'http://cosmobots.eu'

  requires_redmine_plugin :wiki_graphviz_plugin, :version_or_higher => '0.8.0'
  requires_redmine_plugin :computed_custom_field , :version_or_higher => '1.0.7'
  requires_redmine_plugin :additionals , :version_or_higher => '2.0.24'

  permission :csys_menu, :cosmosys => :menu
  permission :csys_tree, :cosmosys => :tree
  permission :csys_treeview, :cosmosys => :treeview
  permission :csys_show, :cosmosys => :show
  permission :csys_up, :cosmosys => :up
  permission :csys_down, :cosmosys => :down  
  
  permission :csys_iss_index, :cosmosys_issues => :index

  menu :project_menu, :cosmosys, {:controller => 'cosmosys', :action => 'menu' }, :caption => 'cosmoSys', :after => :activity, :param => :id
  menu :project_menu, :cosmosys_treeview, {:controller => 'cosmosys', :action => 'treeview' }, :caption => 'cSysTreeView', :after => :issues, :param => :id
  menu :project_menu, :cosmosys_show, {:controller => 'cosmosys', :action => 'show' }, :caption => 'cSysShow', :after => :issues, :param => :id
  menu :project_menu, :cosmosys_issues_index, {:controller => 'cosmosys_issues', :action => 'index' }, :caption => 'cSysIssues', :after => :issues, :param => :id

  settings :default => {
  }, :partial => 'settings/cosmosys_settings'


  require 'cosmosys'
  # Patches to the Redmine core.
  require 'application_helper_patch'
  require 'queries_helper_patch'
  require 'tracker_patch'
  require 'user_patch'
  require 'project_patch'
  require 'version_patch'
  require 'issue_patch'
end
