class CosmosysIssue < ActiveRecord::Base
  belongs_to :issue
  belongs_to :cosmosys_project
  
  before_create :init_attr

  ## Generic utilities

  @@cfsupervisor = IssueCustomField.find_by_name('Supervisor')
  @@cfoldcode = IssueCustomField.find_by_name('OldCode')
  def vsupervisor_id
    if self.supervisor_id == nil then
      ret = nil
      supid = self.issue.custom_values.find_by_custom_field_id(@@cfsupervisor.id)
      if supid != nil then
        sup = supid.value
        if sup != nil then
          ret = sup.to_i
        end
      else
        return ret
      end
    else
      return self.supervisor_id
    end
  end

  def oldcode
    ret = nil
    supid = self.issue.custom_values.find_by_custom_field_id(@@cfoldcode.id)
    if supid != nil then
      ret = supid.value
    end
    return ret
  end

  def is_root
    self.issue.parent == nil
  end

  def get_descendents
    result = []
    self.issue.children.each{|c|
      result.append(c)
      result += c.csys.get_descendents
    }
    return result
  end
  
  ## Calculated attributes

  def chapter_str
    if !self.is_root
      prev_str = self.issue.parent.csys.chapter_str
    else
      prev_str = ''
    end
    return prev_str + self.chapter_order.floor.to_s + '.'
  end
  
  ## TreeView support

  def self.update_node(n,p,ord)
    # n is node, p is parent
    node = Issue.find(n['id'])
    if (node != nil) then
      node.csys.chapter_order = ord
      node.csys.save
      if (p != nil) then
        parent = Issue.find(p)
        node.parent = parent
      else
        node.parent = nil
      end
      node.save
      ch = n['children']
      chord = 1
      if (ch != nil) then
         ch.each { |c| 
          #puts("* llamamos a"+c.to_s)           
          update_node(c,node.id,chord)
          chord += 1
        }
      end
    end
  end

  def to_treeview_json(root_url, include_doc_children)
    tree_node = self.issue.attributes.slice("id","tracker_id","subject","description","status_id","fixed_version_id","parent_id","root_id","assigned_to_id","due_date","start_date","done_ratio")
    tree_node[:chapter] = self.chapter_str
    tree_node[:title] = self.issue.subject
    tree_node[:identifier] = self.identifier
    tree_node[:oldcode] = self.oldcode
    tree_node[:url] = root_url+'/cosmosys/'+self.issue.id.to_s,    
    tree_node[:return_url] = root_url+'/cosmosys/'+self.issue.id.to_s+'/tree.json',    

    tree_node[:supervisor] = ""
    tree_node[:supervisor_id] = self.vsupervisor_id
    if (tree_node[:supervisor_id] != nil) then
      if (tree_node[:supervisor_id] > 0) then  
        tree_node[:supervisor] = User.find(tree_node[:supervisor_id]).login
      end
    end

    tree_node[:assigned_to] = []
    if (self.issue.assigned_to != nil) then
      if self.issue.assigned_to.class == Group then
        tree_node[:assigned_to] = [self.issue.assigned_to.lastname]
        self.issue.assigned_to.users.each{|u|
          tree_node[:assigned_to].append(u.login)
        }
      else
        tree_node[:assigned_to] = [self.issue.assigned_to.login]
      end
    end

    if self.issue.children.size == 0 then
      tree_node[:type] = 'Issue'
    else
      tree_node[:type] = 'Info'
    end

    tree_node[:children] = []

    childrenitems = self.issue.children.sort_by {|obj| obj.csys.chapter_order}
    childrenitems.each{|c|
      if (include_doc_children) then
        child_node = c.csys.to_treeview_json(root_url,include_doc_children)
        tree_node[:children] << child_node
      end
    }
    tree_node[:relations] = []
    self.issue.relations_from.where(:relation_type => 'blocks').each{|rl|
      tree_node[:relations] << rl.attributes.slice("issue_to_id")
    }
    tree_node[:relations_back] = []
    self.issue.relations_to.where(:relation_type => 'blocks').each{|rl|
      tree_node[:relations_back] << rl.attributes.slice("issue_from_id")
    }

    return tree_node
  end
  
  ################## Diagrams support #######################
  
  @@max_graph_levels = 12
  @@max_graph_siblings = 7
  
  def self.word_wrap( text, line_width: 80, break_sequence: "\n")
    text.split("\n").collect! do |line|
      line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1#{break_sequence}").rstrip : line
    end * break_sequence
  end
  
  def self.get_relation_color(r)
    if r.relation_type == 'blocks' then
      colorstr = 'red'
    else
      if r.relation_type == 'precedes' then
        colorstr = 'blue'
      else
        if r.relation_type == 'relates' then
          colorstr = 'green'
        else
          if r.relation_type == 'copied_to' then
            colorstr = 'orange'
          else
            colorstr = 'violet'
          end                
        end                 
      end            
    end
    return colorstr
  end
  
  
  # -----------------------------------

  def to_graphviz_depupn(cl,n_node,upn,isfirst,torecalc,root_url,levels_counter,force_end,colordep)
    if (levels_counter >= @@max_graph_levels)
      stylestr = 'dotted'
    else
      stylestr = 'filled'
    end
    if (upn.children.size>0) then
            shapestr = 'note'
            labelstr =  upn.identifier+"\n----\n"+self.class.word_wrap(upn.subject, line_width: 12)
    else
            shapestr = 'Mrecord'
            labelstr =  "{ "+upn.identifier+"|"+self.class.word_wrap(upn.subject, line_width: 12) + "}"
    end

    if not(force_end) then
      colorstr = 'black'
      upn_node = cl.add_nodes( upn.id.to_s, :label => labelstr,
        :style => stylestr, :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
        :URL => root_url + "/issues/" + upn.id.to_s)
    else
      colorstr = 'blue'
      upn_node = cl.add_nodes( upn.id.to_s, :label => "{ ... }",
        :style => stylestr, :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
        :URL => root_url + "/issues/" + upn.id.to_s)
      
    end
    cl.add_edges(upn_node, n_node, :color => colordep)
    if not(force_end) then
      if (levels_counter < @@max_graph_levels) then
        siblings_counter = 0
        levels_counter += 1
        upn.relations_to.each {|upn2|
          colordep2 = CosmosysIssue.get_relation_color(upn2)
          if (siblings_counter < @@max_graph_siblings) then
            cl,torecalc=self.to_graphviz_depupn(cl,upn_node,upn2.issue_from,isfirst,torecalc,root_url,levels_counter,force_end,colordep2)
          else
            if (siblings_counter <= @@max_graph_siblings) then
              cl,torecalc=self.to_graphviz_depupn(cl,upn_node,upn2.issue_from,isfirst,torecalc,root_url,levels_counter,true,colordep2)
            end
          end
          siblings_counter += 1
        }
      end
    end
    if (isfirst) then
      torecalc[upn.id.to_s.to_sym] = upn.id
    end      
    return cl,torecalc
  end



  def to_graphviz_depdwn(cl,n_node,dwn,isfirst,torecalc,root_url,levels_counter,force_end,colordep)
    if (levels_counter >= @@max_graph_levels) then
      stylestr = 'dotted'
    else
      stylestr = 'filled'
    end
    if (dwn.children.size>0) then
      shapestr = 'note'
      labelstr =  dwn.identifier+"\n----\n"+self.class.word_wrap(dwn.subject, line_width: 12)
    else
      shapestr = 'Mrecord'
      labelstr =  "{ "+dwn.identifier+"|"+self.class.word_wrap(dwn.subject, line_width: 12) + "}"
    end
    if not(force_end) then
      colorstr = 'black'
      dwn_node = cl.add_nodes( dwn.id.to_s, :label => labelstr,
        :style => stylestr, :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
        :URL => root_url + "/issues/" + dwn.id.to_s)
    else
      colorstr = 'blue'
      dwn_node = cl.add_nodes( dwn.id.to_s, :label => "{ ... }",
        :style => stylestr, :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
        :URL => root_url + "/issues/" + dwn.id.to_s)
    end
    cl.add_edges(n_node, dwn_node, :color => colordep)
    if not(force_end) then
      if (levels_counter < @@max_graph_levels) then
        reldown = []
        dwn.relations_from.each {|dwn2|
          reldown += [dwn2.issue_to]
        }
        levels_counter += 1
        siblings_counter = 0
        dwn.relations_from.each {|dwn2|
          colordep2 = CosmosysIssue.get_relation_color(dwn2)
          if not(reldown.include?(dwn2.issue_to.parent)) then
            if (siblings_counter < @@max_graph_siblings) then
              cl,torecalc=self.to_graphviz_depdwn(cl,dwn_node,dwn2.issue_to,isfirst,torecalc,root_url, levels_counter, force_end,colordep2)
            else
              if (siblings_counter <= @@max_graph_siblings) then
                cl,torecalc=self.to_graphviz_depdwn(cl,dwn_node,dwn2.issue_to,isfirst,torecalc,root_url, levels_counter, true,colordep2)
              end
            end
            siblings_counter += 1
          end
        }
      end
    end
    if (isfirst) then
      torecalc[dwn.id.to_s.to_sym] = dwn.id
    end  
    return cl,torecalc
  end

  def to_graphviz_depcluster(cl,isfirst,torecalc,root_url)
    if ((self.issue.children.size > 0)) then
      shapestr = 'Mrecord'
      desc = self.get_descendents
      added_nodes = []
      relnode = []
      self.issue.relations_from.each{|rn|
        relnode += [rn.issue_to]
      }
      desc.each { |e| 
        if (e.relations.size>0) then
          anyrel = false
          e.relations_from.each {|r|
            if not(relnode.include?(r.issue_to)) then
              anyrel = true
            end 
          }
          if anyrel then
            labelstr = "{"+e.identifier+"|"+self.class.word_wrap(e.subject, line_width: 12) + "}"      
            e_node = cl.add_nodes(e.id.to_s, :label => labelstr,  
              :style => 'filled', :color => 'black', :fillcolor => 'grey', :shape => shapestr,
              :URL => root_url + "/issues/" + e.id.to_s)
            e.relations_from.each {|r|
              if (not(desc.include?(r.issue_to))) then
                if (not(added_nodes.include?(r.issue_to))) then
                  added_nodes.append(r.issue_to)
                  ext_node = cl.add_nodes(r.issue_to.id.to_s,
                    :URL => root_url + "/issues/" + r.issue_to.id.to_s)
                end
              end
              colorstr = CosmosysIssue.get_relation_color(r)
              cl.add_edges(e_node, r.issue_to_id.to_s, :color => colorstr)
            }
          end
        end
      }
      if self.issue.relations.size > 0 then
        # here
        dwnrel = []
        self.issue.relations_from.each{|dwn|
          dwnrel += [dwn.issue_to]
        }
        colorstr = 'black'
        n_node = cl.add_nodes( self.issue.id.to_s, :label => self.identifier+"\n----\n"+self.class.word_wrap(self.issue.subject, line_width: 12),
          :style => 'filled', :color => colorstr, :fillcolor => 'green', :shape => 'note',
          :URL => root_url + "/issues/" + self.issue.id.to_s)
        siblings_counter = 0
        self.issue.relations_from.each{|dwn|
          colordep2 = CosmosysIssue.get_relation_color(dwn)
          if not(dwnrel.include?(dwn.issue_to.parent)) then
            if (siblings_counter < @@max_graph_siblings) then
              cl,torecalc=self.to_graphviz_depdwn(cl,n_node,dwn.issue_to,isfirst,torecalc,root_url,1,false,colordep2)
            else
              if (siblings_counter <= @@max_graph_siblings) then
                cl,torecalc=self.to_graphviz_depdwn(cl,n_node,dwn.issue_to,isfirst,torecalc,root_url,1,true,colordep2)
              end
            end
            siblings_counter += 1
          end
        }
        siblings_counter = 0
        self.issue.relations_to.each{|upn|
          colordep2 = CosmosysIssue.get_relation_color(upn)
          if (siblings_counter < @@max_graph_siblings) then
            cl,torecalc=self.to_graphviz_depupn(cl,n_node,upn.issue_from,isfirst,torecalc,root_url,1,false,colordep2)
          else
            if (siblings_counter <= @@max_graph_siblings) then
              cl,torecalc=self.to_graphviz_depupn(cl,n_node,upn.issue_from,isfirst,torecalc,root_url,1,true,colordep2)
            end
          end
          siblings_counter += 1
        }
      end
      return cl,torecalc
    else
      colorstr = 'black'
      n_node = cl.add_nodes( self.issue.id.to_s, :label => "{"+self.identifier+"|"+self.class.word_wrap(self.issue.subject, line_width: 12) + "}",  
        :style => 'filled', :color => colorstr, :fillcolor => 'green', :shape => 'Mrecord',
        :URL => root_url + "/issues/" + self.issue.id.to_s)
      downrel = []
      self.issue.relations_from.each{|dwn|
        downrel += [dwn.issue_to]
      }
      siblings_counter = 0
      self.issue.relations_from.each{|dwn|
        colordep2 = CosmosysIssue.get_relation_color(dwn)
        if not(downrel.include?(dwn.issue_to.parent)) then 
          if (siblings_counter < @@max_graph_siblings) then
            cl,torecalc=self.to_graphviz_depdwn(cl,n_node,dwn.issue_to,isfirst,torecalc,root_url,1,false,colordep2)
          else
            if (siblings_counter <= @@max_graph_siblings) then
              cl,torecalc=self.to_graphviz_depdwn(cl,n_node,dwn.issue_to,isfirst,torecalc,root_url,1,true,colordep2)
            end        
          end        
          siblings_counter += 1
        end
      }
      siblings_counter = 0
      self.issue.relations_to.each{|upn|
        colordep2 = CosmosysIssue.get_relation_color(upn)
        if (siblings_counter < @@max_graph_siblings) then
          cl,torecalc=self.to_graphviz_depupn(cl,n_node,upn.issue_from,isfirst,torecalc,root_url,1,false,colordep2)
        else
          if (siblings_counter <= @@max_graph_siblings) then
            cl,torecalc=self.to_graphviz_depupn(cl,n_node,upn.issue_from,isfirst,torecalc,root_url,1,true,colordep2)
          end        
        end        
        siblings_counter += 1
      }
      return cl,torecalc
    end    
  end

  def to_graphviz_depgraph(isfirst,torecalc,root_url)
    # Create a new graph
    g = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "9.5,30", :strict => true )
    if ((self.issue.children.size > 0)) then
      labelstr = 'Dependences (in subtree)'
      colorstr = 'orange'
      fontnamestr = 'times italic'
    else
      labelstr = 'Dependences'
      colorstr = 'black'
      fontnamestr = 'times'
    end    
    cl = g.add_graph(:clusterD, :fontname => fontnamestr, :label => labelstr, :labeljust => 'l', :labelloc=>'t', :margin=> '5', :color => colorstr)
    # Generate output image
    cl,torecalc = self.to_graphviz_depcluster(cl,isfirst,torecalc,root_url)  
    return g,torecalc
  end


  def to_graphviz_hieupn(cl,n_node,upn,isfirst,torecalc,root_url)
    colorstr = 'black'
    if upn.children.size > 0 then
      shapestr = "note"
      labelstr = upn.identifier+"\n----\n"+self.class.word_wrap(upn.subject, line_width: 12)
      fontnamestr = 'times italic'            
    else
      shapestr = 'Mrecord'
      labelstr = "{"+upn.identifier+"|"+self.class.word_wrap(upn.subject, line_width: 12) + "}"      
      fontnamestr = 'times'
    end
    upn_node = cl.add_nodes( upn.id.to_s, :label => labelstr, :fontname => fontnamestr,
      :style => 'filled', :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
      :URL => root_url + "/issues/" + upn.id.to_s)
    cl.add_edges(upn_node, n_node)
    if (upn.parent != nil) then
      cl,torecalc=self.to_graphviz_hieupn(cl,upn_node,upn.parent,isfirst,torecalc,root_url)
    end
    if (isfirst) then
      torecalc[upn.id.to_s.to_sym] = upn.id
    end  
    return cl,torecalc
  end

  def to_graphviz_hiedwn(cl,n_node,dwn,isfirst,torecalc,root_url)
    colorstr = 'black'
    if dwn.children.size > 0 then
      shapestr = "note"
      labelstr = dwn.identifier+"\n----\n"+self.class.word_wrap(dwn.subject, line_width: 12)
      fontnamestr = 'times italic'            
    else
      shapestr = 'Mrecord'
      labelstr = "{"+dwn.identifier+"|"+self.class.word_wrap(dwn.subject, line_width: 12) + "}"      
      fontnamestr = 'times'
    end
    dwn_node = cl.add_nodes( dwn.id.to_s, :label => labelstr, :fontname => fontnamestr, 
      :style => 'filled', :color => colorstr, :fillcolor => 'grey', :shape => shapestr,
      :URL => root_url + "/issues/" + dwn.id.to_s)
    cl.add_edges(n_node, dwn_node)
    dwn.children.each {|dwn2|
      cl,torecalc=self.to_graphviz_hiedwn(cl,dwn_node,dwn2,isfirst,torecalc,root_url)
    }
    if (isfirst) then
      torecalc[dwn.id.to_s.to_sym] = dwn.id
    end      
    return cl,torecalc
  end


  def to_graphviz_hiecluster(cl,isfirst,torecalc,root_url)
    colorstr = 'black'
    if self.issue.children.size > 0 then
      shapestr = "note"
      labelstr = self.identifier+"\n----\n"+self.class.word_wrap(self.issue.subject, line_width: 12)
      fontnamestr = 'times italic'            
    else
      shapestr = 'Mrecord'
      labelstr = "{"+self.identifier+"|"+self.class.word_wrap(self.issue.subject, line_width: 12) + "}"      
      fontnamestr = 'times'
    end

    n_node = cl.add_nodes( self.issue.id.to_s, :label => labelstr, :fontname => fontnamestr, 
      :style => 'filled', :color => colorstr, :fillcolor => 'green', :shape => shapestr,
      :URL => root_url + "/issues/" + self.issue.id.to_s)
    self.issue.children.each{|dwn|
      cl,torecalc=self.to_graphviz_hiedwn(cl,n_node,dwn,isfirst,torecalc,root_url)
    }
    if (self.issue.parent != nil) then
      cl,torecalc=self.to_graphviz_hieupn(cl,n_node,self.issue.parent,isfirst,torecalc,root_url)
    end
    return cl,torecalc
  end

  def to_graphviz_hiegraph(isfirst,torecalc,root_url)
    # Create a new graph
    g = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "9.5,30", :strict => true )
    cl = g.add_graph(:clusterD, :label => 'Hierarchy', :labeljust => 'l', :labelloc=>'t', :margin=> '5')
    cl,torecalc = self.to_graphviz_hiecluster(cl,isfirst,torecalc,root_url)
    return g,torecalc
  end

  def to_graphviz_graph_str(isfirst,torecalc,root_url)
    g,torecalc = self.to_graphviz_depgraph(isfirst,torecalc,root_url)
    result="{{graphviz_link()\n" + g.to_s + "\n}}"
    g2,torecalc = self.to_graphviz_hiegraph(isfirst,torecalc,root_url)
    result+=" {{graphviz_link()\n" + g2.to_s + "\n}}"
    return result,torecalc
  end

  def show_graphs(root_url)
    strdiag,torecalc = self.to_graphviz_graph_str(true,{},root_url)
    return strdiag
  end
  
  
  

  private

  def init_attr
    p = self.issue.project
    puts self.issue
    puts p
    cp = p.csys
    self.cosmosys_project = cp
    self.identifier = cp.prefix + '-' + format('%04d', cp.id_counter+1)
    cp.id_counter += 1
    cp.save
  end  
end
