module Cosmosys
  module Hooks
    class ApiIssueShowHook < Redmine::Hook::ViewListener
      render_on :api_issue_show_hook, :partial => 'issues/show_rest_api_patch'
    end
  end
end
