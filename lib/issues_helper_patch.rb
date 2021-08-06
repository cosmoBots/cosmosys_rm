require_dependency 'issues_helper'

module IssuesHelperPatch
  def issue_heading(issue)
    h("#{issue.tracker} ##{issue.id} | #{issue.csys.get_identifier}")
  end
end

module IssuesHelper
  prepend IssuesHelperPatch
end


