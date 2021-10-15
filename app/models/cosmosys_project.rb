class CosmosysProject < ActiveRecord::Base
  belongs_to :project
  
  before_create :init_attr

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

  def show_as_json(issue_id,root_url)
	return self.show_as_json_inner(issue_id, root_url, true)
  end

  def versions_list(p,td)
      p.versions.each { |v| 
      if v.project == p then
        td[:targets][v.id.to_s] = {}
        td[:targets][v.id.to_s][:name] = v.name
        td[:targets][v.id.to_s][:due_date] = v.due_date
        td[:targets][v.id.to_s][:status] = v.status
      end
    }
  end
  def versions_tree(p,td)
    versions_list(p,td)
    p.children.each{|pc|
      versions_tree(pc,td)
    }
  end

  def ordered_subtree
    ret = []
    childrenitems = self.get_project_root_issues(false).sort_by {|obj| obj.csys.chapter_order}
    childrenitems.each{|c|
      ret += c.csys.ordered_subtree
    }
    return ret
  end

  def show_as_json_inner(issue_id,root_url,include_subprojects)
    require 'json'

    if (issue_id != nil) then
      thisnode = Issue.find(issue_id)
      roots = [thisnode]
    else    
      roots = self.get_project_root_issues(include_subprojects)
    end

    treedata = {}
    treedata[:project] = self.project.attributes.slice("id","name","identifier")
    treedata[:project][:url] = root_url
    treedata[:project][:return_url] = root_url+'/cosmosys/'+self.project.id.to_s+'/tree.json'
    treedata[:project][:code] = self.code
    treedata[:project][:description] = self.project.description
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
      else
        treedata[:members][mb.user.login.to_s] = mb.user.attributes.slice("firstname","lastname")
        treedata[:members][mb.user.login.to_s][:class] = mb.user.class.name
      end
    }

    versions_list(self.project,treedata)
    
    roots.each { |r|
      thisnode=r
      tree_node = thisnode.csys.to_treeview_json(root_url,true)
      treedata[:issues] << tree_node
    }
    return treedata
  end

  def show_depgraphs_pr(dg)
    return " {{graphviz_link()\n" + dg.to_s + "\n}}"
  end
  def show_hiegraphs_pr(hg)
    return "{{graphviz_link()\n" + hg.to_s + "\n}}"   
  end
  def calculate_graphs(root_url)
    # Create a new hierarchy graph
    hg = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "40,30", :strict => true )
    hcl = hg.add_graph(:clusterD, :label => 'Hierarchy', :labeljust => 'l', :labelloc=>'t', :margin=> '5') 

    # Create a new hierarchy graph
    dg = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "40,30", :strict => true )
    dcl = dg.add_graph(:clusterD, :label => 'Dependences', :labeljust => 'l', :labelloc=>'t', :margin=> '5') 

    self.project.issues.each{|n|
      colorstr = n.csys.get_border_color
      if n.csys.is_chapter? then
        shapestr =  n.tracker.csys.paint_pref[:chapter_shape]
        labelstr = n.csys.get_label_chapter
        fontnamestr = 'times italic'            
      else
        shapestr =  n.tracker.csys.paint_pref[:issue_shape]
        labelstr = n.csys.get_label_issue
        fontnamestr = 'times'
      end
      fillstr = n.csys.get_fill_color
      hn_node = hcl.add_nodes( n.id.to_s, :label => labelstr, :fontname => fontnamestr, 
        :style => 'filled', :color => colorstr, :fillcolor => fillstr, :shape => shapestr,
        :URL => root_url + "/issues/" + n.id.to_s)
      n.children.each{|c|
        hcl.add_edges(hn_node, c.id.to_s)
      }
      if (n.relations.size>0) then
        dn_node = dcl.add_nodes( n.id.to_s, :label => labelstr, :fontname => fontnamestr,   
          :style => 'filled', :color => colorstr, :fillcolor => fillstr, :shape => shapestr,
          :URL => root_url + "/issues/" + n.id.to_s)
        n.relations_from.each {|r|
          colorstr = CosmosysIssue.get_relation_color(r,n.tracker)
          dcl.add_edges(dn_node, r.issue_to_id.to_s, :color => colorstr)
        }
      end
    }
    return dg,hg
  end
  
  def show_graphs_pr(dg,hg)

    result = "{{graphviz_link()\n" + hg.to_s + "\n}}"
    result += " {{graphviz_link()\n" + dg.to_s + "\n}}"

    return result
  end

  @@cfcscode = ProjectCustomField.find_by_name('csCode')

  def code
    ret = nil
    supid = self.project.custom_values.find_by_custom_field_id(@@cfcscode.id)
    if supid != nil then
      ret = supid.value
    end
    return ret
  end

  def find_root
    if self.project.parent == nil then
      return self
    else
      return self.project.parent.csys.find_root
    end
  end

  def all_subprojects
    ret = []
    self.project.children.each {|c|
      ret += [c.csys] + c.csys.all_subprojects
    }
    return ret
  end

  def find_issue_by_identifier(ident,full_tree = false)
    ret = nil
    self.project.issues.each {|i|
      # It is very important not to create new identifiers when searching!!!
      # check if cosmosys_issue attribute exists before checking the identifier
      if ret == nil then
        if i.cosmosys_issue != nil then
          if i.cosmosys_issue.get_identifier == ident then
            ret = i
          end
        end
      end
    }
    if ret == nil and full_tree then
      proot = self.find_root
      #puts("root project",proot.project.identifier)
      projectlist = [proot]+proot.all_subprojects
      #puts("Complete projectlist",projectlist)
      projectlist -= [self]
      #puts("Reduced projectlist",projectlist)
      projectlist.each {|p|
        if ret == nil then
          #puts("Looking for the ident ",ident,"at project",p.project.identifier)
          ret = p.find_issue_by_identifier(ident)
        end
      }
    end
    return ret
  end

  def update_cschapters
    ch = self.project.issues.each{|i|
      i.csys.update_cschapter
    }
  end

  private
  
  def init_attr
    
  end  

end
