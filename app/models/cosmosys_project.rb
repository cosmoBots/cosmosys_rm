class CosmosysProject < ActiveRecord::Base
  belongs_to :project
  
  before_create :init_attr

  def self.word_wrap( text, line_width: 80, break_sequence: "\n")
    text.split("\n").collect! do |line|
      line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1#{break_sequence}").rstrip : line
    end * break_sequence
  end

  def get_descendents
    result = []
    self.project.children.each{|c|
      result.append(c)
      result += c.get_descendents
    }
    return result
  end

  def get_project_root_issues(include_subprojects)
    roots = self.project.issues.where(:parent => nil)
	  if (include_subprojects) then
	    self.project.children.each{ |p|
			roots += p.csys.get_project_root_issues(include_subprojects)
		}
	  end
	  return roots
  end

  def show_as_json(node_id,root_url)
	return self.show_as_json_inner(node_id, root_url, true)
  end

  def show_as_json_inner(node_id,root_url,include_subprojects)
    require 'json'

    if (node_id != nil) then
      thisnode = Issue.find(node_id)
      roots = [thisnode]
    else    
      roots = self.get_project_root_issues(include_subprojects)
    end

    treedata = {}
    treedata[:project] = self.project.attributes.slice("id","name","identifier")
    treedata[:project][:url] = root_url
    treedata[:project][:return_url] = root_url+'/cosmosys/'+self.project.id.to_s+'/tree.json'
    treedata[:targets] = {}
    treedata[:statuses] = {}
    treedata[:trackers] = {}
    treedata[:members] = {}
    treedata[:issues] = []

    IssueStatus.all.each { |st| 
      treedata[:statuses][st.id.to_s] = st.name
    }

    Tracker.all.each { |tr| 
      treedata[:trackers][tr.id.to_s] = tr.name
    }

    self.project.memberships.all.each { |mb| 
      if mb.principal.class == Group then
        treedata[:members][mb.principal.lastname.to_s] = {}
        treedata[:members][mb.principal.lastname.to_s][:firstname] = mb.principal.lastname
        treedata[:members][mb.principal.lastname.to_s][:lastname] = "group" 
        treedata[:members][mb.principal.lastname.to_s][:class] = mb.principal.class.name
		    treedata[:members][mb.principal.lastname.to_s][:gen_report] = false
      else
        treedata[:members][mb.user.login.to_s] = mb.user.attributes.slice("firstname","lastname")
        treedata[:members][mb.user.login.to_s][:class] = mb.user.class.name
        treedata[:members][mb.user.login.to_s][:gen_report] = mb.user.csys.gen_rpt
      end
    }

    self.project.versions.each { |v| 
      treedata[:targets][v.id.to_s] = {}
      treedata[:targets][v.id.to_s][:name] = v.name
      treedata[:targets][v.id.to_s][:due_date] = v.due_date
      treedata[:targets][v.id.to_s][:status] = v.status
      treedata[:targets][v.id.to_s][:start_date] = v.csys.start_date
      #TODO: treedata[:targets][v.id.to_s][:working_days] = v.csys.working_days
    }
    roots.each { |r|
      thisnode=r
      tree_node = thisnode.csys.to_treeview_json(root_url,true)
      treedata[:issues] << tree_node
    }
    return treedata
  end


  private

  def init_attr
    self.prefix = self.project.identifier
  end

end
