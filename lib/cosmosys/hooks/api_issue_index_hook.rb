module Cosmosys
  module Hooks
    class ApiIssueIndexHook < Redmine::Hook::ViewListener
      render_on :api_issue_index_hook, :partial => 'issues/index_rest_api_patch'
    end
  end
end
