module Cosmosys
  module Hooks
    class ModelIssueHook < Redmine::Hook::ViewListener

      render_on :view_projects_show_left, :partial => "cosmosys/project_overview" 
      render_on :view_issues_show_description_bottom, :partial => "cosmosys/issues" 

    end
  end
end