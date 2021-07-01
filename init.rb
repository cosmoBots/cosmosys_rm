Redmine::Plugin.register :cosmosys do
  name 'Cosmosys plugin'
  author 'Txinto Vaz'
  description 'This is a plugin for Redmine, which converts it into a CosmoSys instance'
  version '0.0.1'
  url 'http://cosmobots.eu'
  author_url 'http://cosmobots.eu'

  requires_redmine_plugin :wiki_graphviz_plugin #, :version_or_higher => '0.7.3'
  requires_redmine_plugin :computed_custom_field #, :version_or_higher => '0.7.3'
  requires_redmine_plugin :additionals #, :version_or_higher => '0.7.3'

  permission :csys_menu, :cosmosys => :menu
  permission :csys_tree, :cosmosys => :tree
  permission :csys_treeview, :cosmosys => :treeview
  permission :csys_show, :cosmosys => :show
  permission :csys_up, :cosmosys => :up
  permission :csys_down, :cosmosys => :down  
  permission :csys_report, :cosmosys => :report
  
  permission :csys_iss_index, :cosmosys_issues => :index

  menu :project_menu, :cosmosys, {:controller => 'cosmosys', :action => 'menu' }, :caption => 'cosmoSys', :after => :activity, :param => :id
  menu :project_menu, :cosmosys_treeview, {:controller => 'cosmosys', :action => 'treeview' }, :caption => 'cSysTreeView', :after => :issues, :param => :id
  menu :project_menu, :cosmosys_show, {:controller => 'cosmosys', :action => 'show' }, :caption => 'cSysShow', :after => :issues, :param => :id
  menu :project_menu, :cosmosys_issues_index, {:controller => 'cosmosys_issues', :action => 'index' }, :caption => 'cSysIssues', :after => :issues, :param => :id

  settings :default => {
    'repo_local_path' => "/home/redmine/repos/issues_%project_id%",
    'repo_server_sync' => :false,
    'repo_server_path'  => 'http://gitlab/issues/issue_%project_id%.git',
    'repo_template_id'  => 'template',
    'repo_redmine_path' => "/home/redmine/repos_redmine/issue_%project_id%.git",
    'repo_redmine_sync' => :true,
    'relative_uploadfile_path' => "uploading/IssUpload.ods",
    'relative_downloadfile_path' => "downloading/IssDownload.ods",
    'relative_reporting_path' => "reporting",
    'relative_img_path' => "reporting/doc/img"
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
