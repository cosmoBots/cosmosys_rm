require_dependency 'application_helper'

# Patches Redmine's Issues dynamically.  Adds a relationship 
# Issue +belongs_to+ to Deliverable
module ApplicationHelperPatch
  
  def link_to_issue(issue, options={})
    title = nil
    subject = nil
    text = options[:tracker] == false ? "##{issue.csys.get_identifier}" : "#{issue.tracker} ##{issue.csys.get_identifier}"
    reqtitle = issue.subject
    if options[:subject] == false
      title = reqtitle.truncate(60)
    else
      subject = reqtitle
      if truncate_length = options[:truncate]
        subject = subject.truncate(truncate_length)
      end
    end
    only_path = options[:only_path].nil? ? true : options[:only_path]
    s = link_to(text, issue_url(issue, :only_path => only_path),
                :class => issue.css_classes, :title => title)
    s << h(": #{subject}") if subject
    s = h("#{issue.project} - ") + s if options[:project]
    s
  end
end    

# Add module to ApplicationHelper
module ApplicationHelper
  prepend ApplicationHelperPatch
end
