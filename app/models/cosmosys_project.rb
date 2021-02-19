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

      # TODO: REMEMBER TO REMOVE VSTART_DATE
      treedata[:targets][v.id.to_s][:start_date] = v.csys.vstart_date
      # TODO: REMEMBER TO REMOVE THE WORKING DAYS WHEN YOU WILL NOT NEED THEM
      treedata[:targets][v.id.to_s][:working_days] = v.csys.vworking_days
    }
    roots.each { |r|
      thisnode=r
      tree_node = thisnode.csys.to_treeview_json(root_url,true)
      treedata[:issues] << tree_node
    }
    return treedata
  end


  def show_graphs_pr(root_url)
    # Create a new hierarchy graph
    hg = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "9.5,30", :strict => true )
    hcl = hg.add_graph(:clusterD, :label => 'Hierarchy', :labeljust => 'l', :labelloc=>'t', :margin=> '5') 

    # Create a new hierarchy graph
    dg = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "9.5,30", :strict => true )
    dcl = dg.add_graph(:clusterD, :label => 'Dependences', :labeljust => 'l', :labelloc=>'t', :margin=> '5') 

    self.project.issues.each{|n|
      colorstr = 'black'
      if n.children.size > 0 then
        shapestr = "note"
        labelstr = n.identifier+"\n----\n"+n.csys.class.word_wrap(n.subject, line_width: 12)
        fontnamestr = 'times italic'            
      else
        shapestr = 'Mrecord'
        labelstr = "{"+n.identifier+"|"+n.csys.class.word_wrap(n.subject, line_width: 12) + "}"      
        fontnamestr = 'times'
      end
      hn_node = hcl.add_nodes( n.id.to_s, :label => labelstr, :fontname => fontnamestr, 
        :style => 'filled', :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
        :URL => root_url + "/issues/" + n.id.to_s)
      n.children.each{|c|
        hcl.add_edges(hn_node, c.id.to_s)
      }
      if (n.relations.size>0) then
        dn_node = dcl.add_nodes( n.id.to_s, :label => labelstr, :fontname => fontnamestr,   
          :style => 'filled', :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
          :URL => root_url + "/issues/" + n.id.to_s)
        n.relations_from.each {|r|
          colorstr = CosmosysIssue.get_relation_color(r)
          dcl.add_edges(dn_node, r.issue_to_id.to_s, :color => colorstr)
        }
      end
    }

    result="{{graphviz_link()\n" + hg.to_s + "\n}}"
    result+=" {{graphviz_link()\n" + dg.to_s + "\n}}"

    return result
  end



  private

  def init_attr
    self.prefix = self.project.identifier
  end

end
