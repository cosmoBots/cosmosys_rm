class CosmosysIssue < ActiveRecord::Base
  belongs_to :issue
  belongs_to :cosmosys_project
  belongs_to :csid, :class_name => "CustomValue"

  before_create :init_attr

  ## Generic utilities

  @@cfwloadpct = IssueCustomField.find_by_name('csWload')
  @@cfoldcode = IssueCustomField.find_by_name('csOldCode')
  @@cfid = IssueCustomField.find_by_name('csID')
  @@cfchapter = IssueCustomField.find_by_name('csChapter')
  @@chapterdigits = 3

  ########## DEFERRED ATTRIBUTES TO CUSTOMFIELDS ########
  def vwloadpct
    if self.wloadpct == nil then
      ret = nil
      wload = self.issue.custom_values.find_by_custom_field_id(@@cfwloadpct.id)
      if wload != nil then
        wloadval = wload.value
        if wloadval != nil then
          ret = wloadval
        end
      end
      return ret
    else
      return self.wloadpct
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

  ########## TREE UTILITIES ###########

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

  def get_descendents_in_project
    result = []
    self.issue.children.each{|c|
      if c.project == self.issue.project then
        result.append(c)
        result += c.csys.get_descendents
      end
    }
    return result
  end

  ## Calculated (READONLY) attributes

  def chapter_str
    if !self.is_root
      prev_str = self.issue.parent.csys.chapter_str
    else
      prev_str = ''
    end
    return prev_str + self.chapter_order.floor.to_s + '.'
  end

  def sortable_chapter_str
    if !self.is_root
      prev_str = self.issue.parent.csys.sortable_chapter_str
    else
      prev_str = ''
    end
    return prev_str + self.chapter_order.floor.to_s.rjust(@@chapterdigits, "0") + '.'
  end

  def is_valid?
    true
  end

  def is_chapter?
    tn = self.issue.tracker.name
    self.issue.children.size > 0 || tn == "csInfo" || tn == "csRefDoc"
  end

  def shall_show_dependences?
    true
  end

  def shall_show_id
    tn = self.issue.tracker.name
    return (tn != "csInfo" && tn != "csRefDoc")
  end

  ################## TreeView support #######################

  def self.update_node(n,p,ord)
    # n is node, p is parent
    node = Issue.find(n['id'])
    if (node != nil) then
      if (ord != node.csys.chapter_order) then
        node.csys.chapter_order = ord
        node.csys.save
        #node.csys.update_cschapter
      end
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
      #node.csys.update_cschapter
    end
  end

  def ordered_subtree
    ret = [self]
    childrenitems = self.issue.children.sort_by {|obj| obj.csys.chapter_order}
    childrenitems.each{|c|
      ret += c.csys.ordered_subtree
    }
    return ret
  end

  def to_treeview_json(root_url, include_doc_children)
    tree_node = self.issue.attributes.slice("id","tracker_id","subject","description","status_id","fixed_version_id","parent_id","root_id","assigned_to_id","due_date","start_date","done_ratio")
    tree_node[:chapter] = self.chapter_str
    tree_node[:title] = self.issue.subject
    tree_node[:identifier] = self.get_identifier
    tree_node[:oldcode] = self.oldcode
    tree_node[:url] = root_url+'/cosmosys/'+self.issue.id.to_s,
    tree_node[:return_url] = root_url+'/cosmosys/'+self.issue.id.to_s+'/tree.json',
    tree_node[:wloadpct] = self.vwloadpct
    tree_node[:valid] = self.is_valid?

    self.issue.custom_field_values.each{ |cf|
      if cf.value_present? then
        tree_node[cf.custom_field.name] = cf.value
      else
        tree_node[cf.custom_field.name] = ""
      end
    }

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
      if self.issue.tracker.name == "csInfo" then
        tree_node[:type] = 'Info'
      else
        tree_node[:type] = 'Issue'
      end
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
    tree_node[:blocks] = {}
    self.issue.relations_from.where(:relation_type => 'blocks').each{|rl|
      tree_node[:relations] << rl.attributes.slice("issue_to_id")
      tree_node[:blocks][rl.issue_to.csys.identifier] = rl.issue_to_id
    }
    tree_node[:relations_back] = []
    tree_node[:blocks_back] = {}
    self.issue.relations_to.where(:relation_type => 'blocks').each{|rl|
      tree_node[:relations_back] << rl.attributes.slice("issue_from_id")
      tree_node[:blocks_back][rl.issue_from.csys.identifier] = rl.issue_from_id
    }

    return tree_node
  end

  ################## Diagrams support #######################


  def self.word_wrap( text, line_width: 80, break_sequence: "\n")
    text.split("\n").collect! do |line|
      line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1#{break_sequence}").rstrip : line
    end * break_sequence
  end

  def self.get_relation_color(r,t)
    return t.csys.paint_pref[:relation_color][r.relation_type]
  end

  def self.get_relation_dir(r,t)
    return t.csys.paint_pref[:relation_dir][r.relation_type]
  end

  def self.shall_draw_relation(r,t)
    return t.csys.paint_pref[:shall_draw_relation][r.relation_type]
  end

  def shall_draw
    return true
  end

  def self.get_childrentype(i,t)
    return t.csys.childrentype(i)
  end

  def self.get_nodetype(i,t)
    return t.csys.nodetype(i)
  end

  def inner_get_fill_color
    i = self.issue
    colorstr = 'pink'
    if i.status.is_closed then
      colorstr = 'lightgrey'
    else
      expired = false
      if i.due_date then
        if i.due_date < Date.today then
          expired = true
        end
      end
      if not(expired) then
        if i.done_ratio > 0 then
          colorstr = 'lightblue'
        else
          colorstr = 'white'
        end
      else
        if i.done_ratio > 0 then
          colorstr = 'orange'
        else
          colorstr = 'lightcoral'
        end
      end
    end
    return colorstr
  end

  def get_fill_color
    inner_get_fill_color
  end

  def get_deprankdir
    i = self.issue
    return i.tracker.csys.paint_pref[:deprankdir]
  end
  def get_hierankdir
    i = self.issue
    return i.tracker.csys.paint_pref[:hierankdir]
  end


  def get_border_color
    i = self.issue
    iscolor = i.tracker.csys.paint_pref[:issue_color]
    if self.is_valid? then
      if i.assigned_to == User.current then
        colorstr = iscolor['own']
      else
        colorstr = iscolor['normal']
      end
    else
      colorstr = iscolor['invalid']
    end
    return colorstr
  end

  def inner_get_label_noid(baseproj,boundary_node=false)
    # self.get_identifier+"\n----\n"+self.class.word_wrap(self.issue.subject, line_width: 12)
    # If the project is not the same, the subject must be marked as "External"
    prependstr = ""
    if (baseproj != self.issue.project) then
      prependstr = "+"
    end
    self.class.word_wrap(prependstr + self.chapter_str + self.issue.subject, line_width: 12)
  end

  def inner_get_label_issue(baseproj,boundary_node=false)
    prependstr = ""
    if (baseproj != self.issue.project) then
      prependstr = "+"
    end
    "{"+self.get_identifier+"|"+self.class.word_wrap(prependstr+self.issue.subject, line_width: 12) + "}"
  end

  def get_label_noid(baseproj,boundary_node=false)
    inner_get_label_noid(baseproj,boundary_node)
  end
  def get_label_issue(baseproj,boundary_node=false)
    inner_get_label_issue(baseproj,boundary_node)
  end

  def get_title
    if self.shall_show_id
      self.get_identifier+":"+self.class.word_wrap(self.issue.subject, line_width: 12)
    else
      self.issue.subject
    end
  end
  # -----------------------------------

  def to_graphviz_depupn(cl,n_node,upn,isfirst,torecalc,root_url,levels_counter,force_end,colordep, max_graph_siblings, max_graph_levels, dirdep)
    if upn.csys.shall_draw then
      if (levels_counter >= max_graph_levels)
        stylestr = 'dotted'
      else
        stylestr = 'filled'
      end
      if (not(upn.csys.shall_show_id)) then
        shapestr =  upn.tracker.csys.paint_pref[:chapter_shape]
        labelstr = upn.csys.get_label_noid(self.issue.project)
        fontnamestr = "times italic"
      else
        shapestr =  upn.tracker.csys.paint_pref[:issue_shape]
        labelstr = upn.csys.get_label_issue(self.issue.project)
        fontnamestr = "times"
      end

      if not(force_end) then
        colorstr = upn.csys.get_border_color
        fillstr = upn.csys.get_fill_color
        upn_node = cl.add_nodes( upn.id.to_s, :label => labelstr, :fontname => fontnamestr,
          :style => stylestr, :color => colorstr, :fillcolor => fillstr, :shape => shapestr,
          :URL => root_url + "/issues/" + upn.id.to_s,:fontsize => 10, :margin => 0.03, :width => 0, :height => 0, :penwidth => 0.5, :tooltip => upn.description)
      else
        colorstr = upn.csys.get_border_color
        upn_node = cl.add_nodes( upn.id.to_s, :label => "{ ... }", :fontname => fontnamestr,
          :style => stylestr, :color => colorstr, :fillcolor => fillstr, :shape => shapestr,
          :URL => root_url + "/issues/" + upn.id.to_s,:fontsize => 10, :margin => 0.03, :width => 0, :height => 0, :penwidth => 0.5, :tooltip => upn.description)

      end
      cl.add_edges(upn_node, n_node, :color => colordep,:arrowsize => 0.5, :dir => dirdep)
      if upn.project == self.issue.project then
        if not(force_end) then
          if (levels_counter < max_graph_levels) then
            relup = []
            upn.relations_from.each {|upn2|
              if (CosmosysIssue.shall_draw_relation(upn2,upn.tracker)) then
                relup += [upn2.issue_from]
              end
            }
            siblings_counter = 0
            levels_counter += 1
            upn.relations_to.each {|upn2|
              if (CosmosysIssue.shall_draw_relation(upn2,upn.tracker)) then
                colordep2 = CosmosysIssue.get_relation_color(upn2,upn.tracker)
                depdir2 = CosmosysIssue.get_relation_dir(upn2,upn.tracker)
                if not(relup.include?(upn2.issue_from.parent)) then
                  if (siblings_counter < max_graph_siblings) then
                    cl,torecalc=self.to_graphviz_depupn(cl,upn_node,upn2.issue_from,isfirst,torecalc,root_url,levels_counter,force_end,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                  else
                    if (siblings_counter <= max_graph_siblings) then
                      cl,torecalc=self.to_graphviz_depupn(cl,upn_node,upn2.issue_from,isfirst,torecalc,root_url,levels_counter,true,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                    end
                  end
                  siblings_counter += 1
                end
              end
            }
          end
        end
      end
      if (isfirst) then
        torecalc[upn.id.to_s.to_sym] = upn.id
      end
    end
    return cl,torecalc
  end



  def to_graphviz_depdwn(cl,n_node,dwn,isfirst,torecalc,root_url,levels_counter,force_end,colordep,max_graph_siblings,max_graph_levels, dirdep)
    if dwn.csys.shall_draw then
      if (levels_counter >= max_graph_levels) then
        stylestr = 'dotted'
      else
        stylestr = 'filled'
      end
      if (not(dwn.csys.shall_show_id)) then
        shapestr = dwn.tracker.csys.paint_pref[:chapter_shape]
        labelstr = dwn.csys.get_label_noid(self.issue.project)
        fontnamestr = 'times italic'
      else
        shapestr = dwn.tracker.csys.paint_pref[:issue_shape]
        labelstr = dwn.csys.get_label_issue(self.issue.project)
        fontnamestr = 'times'
      end
      if not(force_end) then
        colorstr = dwn.csys.get_border_color
        fillstr = dwn.csys.get_fill_color
        dwn_node = cl.add_nodes( dwn.id.to_s, :label => labelstr, :fontname => fontnamestr,
          :style => stylestr, :color => colorstr, :fillcolor => fillstr, :shape => shapestr,
          :URL => root_url + "/issues/" + dwn.id.to_s,:fontsize => 10, :margin => 0.03, :width => 0, :height => 0, :penwidth => 0.5, :tooltip => dwn.description)
      else
        colorstr = dwn.csys.get_border_color
        dwn_node = cl.add_nodes( dwn.id.to_s, :label => "{ ... }", :fontname => fontnamestr,
          :style => stylestr, :color => colorstr, :fillcolor => fillstr, :shape => shapestr,
          :URL => root_url + "/issues/" + dwn.id.to_s,:fontsize => 10, :margin => 0.03, :width => 0, :height => 0, :penwidth => 0.5, :tooltip => dwn.description)
      end
      cl.add_edges(n_node, dwn_node, :color => colordep,:arrowsize => 0.5, :dir => dirdep)
      if dwn.project == self.issue.project then
        if not(force_end) then
          if (levels_counter < max_graph_levels) then
            reldown = []
            dwn.relations_from.each {|dwn2|
              if (CosmosysIssue.shall_draw_relation(dwn2,dwn.tracker)) then
                reldown += [dwn2.issue_to]
              end
            }
            levels_counter += 1
            siblings_counter = 0
            dwn.relations_from.each {|dwn2|
              #if dwn2.issue_to.project == self.issue.project then
                if (CosmosysIssue.shall_draw_relation(dwn2,dwn.tracker)) then
                  colordep2 = CosmosysIssue.get_relation_color(dwn2,dwn.tracker)
                  depdir2 = CosmosysIssue.get_relation_dir(dwn2,dwn.tracker)
                  if not(reldown.include?(dwn2.issue_to.parent)) then
                    if (siblings_counter < max_graph_siblings) then
                      cl,torecalc=self.to_graphviz_depdwn(cl,dwn_node,dwn2.issue_to,isfirst,torecalc,root_url, levels_counter, force_end,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                    else
                      if (siblings_counter <= max_graph_siblings) then
                        cl,torecalc=self.to_graphviz_depdwn(cl,dwn_node,dwn2.issue_to,isfirst,torecalc,root_url, levels_counter, true,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                      end
                    end
                    siblings_counter += 1
                  end
                end
              #end
            }
          end
        end
      end
      if (isfirst) then
        torecalc[dwn.id.to_s.to_sym] = dwn.id
      end
    end
    return cl,torecalc
  end

  def to_graphviz_depcluster(cl,isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    if self.shall_draw then
      if ((self.issue.children.size > 0)) then
        desc = self.get_descendents_in_project
        added_nodes = []
        relnode = []
        self.issue.relations_from.each{|rn|
          if (CosmosysIssue.shall_draw_relation(rn,self.issue.tracker)) then
            relnode += [rn.issue_to]
          end
        }
        # Increment one level to show the boundaries
        descbound = []

          desc.each { |e|
            if (e.relations.size>0) then
              e.relations_from.each {|r|
                if (CosmosysIssue.shall_draw_relation(r,e.tracker)) then
                  if not(desc.include?(r.issue_to)) then
                    descbound += [r.issue_to]
                  end
                end
              }
              e.relations_to.each {|r|
                if (CosmosysIssue.shall_draw_relation(r,e.tracker)) then
                  if not(desc.include?(r.issue_from)) then
                    descbound += [r.issue_from]
                  end
                end
              }
            end
          }

        (desc+descbound).each { |e|
          if e.csys.shall_draw then
            anyrel = false
            fillstr = e.csys.get_fill_color
            boundary_node = descbound.include?(e)
            if (e.relations.size>0) then
              e.relations_from.each {|r|
                if r.issue_to != e then
                  if r.issue_to.csys.shall_draw then
                    if (CosmosysIssue.shall_draw_relation(r,e.tracker)) then
                      if (desc+descbound).include?(r.issue_to) then
                        colorstr = CosmosysIssue.get_relation_color(r,e.tracker)
                        depstr = CosmosysIssue.get_relation_dir(r,e.tracker)
                        cl.add_edges(e.id.to_s, r.issue_to_id.to_s, :color => colorstr, :arrowsize => 0.5, :dir => depstr)
                        anyrel = true
                      end
                    end
                  end
                end
              }
              e.relations_to.each {|r|
                if r.issue_from != e then
                  if r.issue_from.csys.shall_draw then
                    if (CosmosysIssue.shall_draw_relation(r,e.tracker)) then
                      if (desc+descbound).include?(r.issue_from) then
                        colorstr = CosmosysIssue.get_relation_color(r,e.tracker)
                        depstr = CosmosysIssue.get_relation_dir(r,e.tracker)
                        cl.add_edges(r.issue_from_id.to_s, e.id.to_s, :color => colorstr, :arrowsize => 0.5, :dir => depstr)
                        anyrel = true
                      end
                    end
                  end
                end
              }
              if anyrel then
                if not(e.csys.shall_show_id) then
                  shapestr =  e.tracker.csys.paint_pref[:chapter_shape]
                  labelstr = e.csys.get_label_noid(self.issue.project,boundary_node)
                  fontnamestr = 'times italic'
                else
                  shapestr =  e.tracker.csys.paint_pref[:issue_shape]
                  labelstr = e.csys.get_label_issue(self.issue.project,boundary_node)
                  fontnamestr = 'times'
                end
              end
              # See https://github.com/cosmoBots/cosmosys_rm/compare/main...estpo#diff-45e496d0fd1820bc4c83e4ef9f44d1da005bfd18c2a5a2fad1ecd01ac9ee43df
              e_node = cl.add_nodes(e.id.to_s, :label => labelstr, :fontname => fontnamestr,
                :style => 'filled', :color => 'black', :fillcolor => fillstr, :shape => shapestr,
                :URL => root_url + "/issues/" + e.id.to_s,:fontsize => 10, :margin => 0.03, :width => 0, :height => 0, :penwidth => 0.5, :tooltip => e.description)
            end
          end
        }
        if self.issue.relations.size > 0 then
          # here
          dwnrel = []
          self.issue.relations_from.each{|dwn|
            if (CosmosysIssue.shall_draw_relation(dwn,self.issue.tracker)) then
              dwnrel += [dwn.issue_to]
            end
          }
          colorstr = self.get_border_color
          fillstr = self.get_fill_color
          if not(self.shall_show_id)
            shapestr = self.issue.tracker.csys.paint_pref[:chapter_shape]
            labelstr = self.get_label_noid(self.issue.project)
            fontnamestr = 'times italic'
          else
            shapestr = self.issue.tracker.csys.paint_pref[:issue_shape]
            labelstr = self.get_label_issue(self.issue.project)
            fontnamestr = 'times'
          end
          n_node = cl.add_nodes( self.issue.id.to_s, :label => labelstr, :fontname => fontnamestr,
            :style => 'filled', :color => colorstr, :fillcolor => fillstr, :shape => shapestr, :penwidth => 1.5,
            :URL => root_url + "/issues/" + self.issue.id.to_s,:fontsize => 10, :margin => 0.03, :width => 0, :height => 0, :tooltip => self.issue.description)
          siblings_counter = 0
          self.issue.relations_from.each{|dwn|
            #if dwn.issue_to.project == self.issue.project then
              if (CosmosysIssue.shall_draw_relation(dwn,self.issue.tracker)) then
                colordep2 = CosmosysIssue.get_relation_color(dwn,self.issue.tracker)
                depdir2 = CosmosysIssue.get_relation_dir(dwn,self.issue.tracker)
                if not(dwnrel.include?(dwn.issue_to.parent)) then
                  if (siblings_counter < max_graph_siblings) then
                    cl,torecalc=self.to_graphviz_depdwn(cl,n_node,dwn.issue_to,isfirst,torecalc,root_url,1,false,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                  else
                    if (siblings_counter <= max_graph_siblings) then
                      cl,torecalc=self.to_graphviz_depdwn(cl,n_node,dwn.issue_to,isfirst,torecalc,root_url,1,true,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                    end
                  end
                  siblings_counter += 1
                end
              end
            #end
          }
          siblings_counter = 0
          self.issue.relations_to.each{|upn|
            #if upn.issue_from.project == self.issue.project then
              if (CosmosysIssue.shall_draw_relation(upn,self.issue.tracker)) then
                colordep2 = CosmosysIssue.get_relation_color(upn,self.issue.tracker)
                depdir2 = CosmosysIssue.get_relation_dir(upn,self.issue.tracker)
                if (siblings_counter < max_graph_siblings) then
                  cl,torecalc=self.to_graphviz_depupn(cl,n_node,upn.issue_from,isfirst,torecalc,root_url,1,false,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                else
                  if (siblings_counter <= max_graph_siblings) then
                    cl,torecalc=self.to_graphviz_depupn(cl,n_node,upn.issue_from,isfirst,torecalc,root_url,1,true,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                  end
                end
                siblings_counter += 1
              end
            #end
          }
        end
        return cl,torecalc
      else
        if not(self.shall_show_id) then
          shapestr =  self.issue.tracker.csys.paint_pref[:chapter_shape]
          labelstr = self.get_label_noid(self.issue.project)
          fontnamestr = 'times italic'
        else
          shapestr =  self.issue.tracker.csys.paint_pref[:issue_shape]
          labelstr = self.get_label_issue(self.issue.project)
          fontnamestr = 'times'
        end
        colorstr = self.get_border_color
        fillstr = self.get_fill_color
        n_node = cl.add_nodes( self.issue.id.to_s, :label => labelstr, :fontname => fontnamestr,
          :style => 'filled', :color => colorstr, :fillcolor => fillstr, :shape => shapestr, :penwidth => 1.5,
          :URL => root_url + "/issues/" + self.issue.id.to_s,:fontsize => 10, :margin => 0.03, :width => 0, :height => 0, :tooltip => self.issue.description)
        downrel = []
        self.issue.relations_from.each{|dwn|
          if (CosmosysIssue.shall_draw_relation(dwn,self.issue.tracker)) then
            downrel += [dwn.issue_to]
          end
        }
        siblings_counter = 0
        self.issue.relations_from.each{|dwn|
          #if dwn.issue_to.project == self.issue.project then
            if (CosmosysIssue.shall_draw_relation(dwn,self.issue.tracker)) then
              colordep2 = CosmosysIssue.get_relation_color(dwn,self.issue.tracker)
              depdir2 = CosmosysIssue.get_relation_dir(dwn,self.issue.tracker)
              if not(downrel.include?(dwn.issue_to.parent)) then
                if (siblings_counter < max_graph_siblings) then
                  cl,torecalc=self.to_graphviz_depdwn(cl,n_node,dwn.issue_to,isfirst,torecalc,root_url,1,false,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                else
                  if (siblings_counter <= max_graph_siblings) then
                    cl,torecalc=self.to_graphviz_depdwn(cl,n_node,dwn.issue_to,isfirst,torecalc,root_url,1,true,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                  end
                end
                siblings_counter += 1
              end
            end
          #end
        }
        siblings_counter = 0
        self.issue.relations_to.each{|upn|
          #if upn.issue_from.project == self.issue.project then
            if (CosmosysIssue.shall_draw_relation(upn,self.issue.tracker)) then
              colordep2 = CosmosysIssue.get_relation_color(upn,self.issue.tracker)
              depdir2 = CosmosysIssue.get_relation_dir(upn,self.issue.tracker)
              if (siblings_counter < max_graph_siblings) then
                cl,torecalc=self.to_graphviz_depupn(cl,n_node,upn.issue_from,isfirst,torecalc,root_url,1,false,colordep2,max_graph_siblings,max_graph_levels, depdir2)
              else
                if (siblings_counter <= max_graph_siblings) then
                  cl,torecalc=self.to_graphviz_depupn(cl,n_node,upn.issue_from,isfirst,torecalc,root_url,1,true,colordep2,max_graph_siblings,max_graph_levels, depdir2)
                end
              end
              siblings_counter += 1
            end
          #end
        }
      end
    end
    return cl,torecalc
  end

  def to_graphviz_depgraph(isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    # Create a new graph
    g = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "3000,3000", :strict => true, :rankdir => self.get_deprankdir)
    if (self.issue.children.size > 0) then
      labelstr = 'Dependences (in subtree)'
      colorstr = 'orange'
      fontnamestr = 'times italic'
    else
      labelstr = 'Dependences'
      colorstr = 'black'
      fontnamestr = 'times'
    end
    cl = g.add_graph(:clusterD, :fontname => fontnamestr, :label => labelstr, :labeljust => 'l', :labelloc=>'t', :margin=> '5', :color => colorstr, :fontsize => 10)
    # Generate output image
    cl,torecalc = self.to_graphviz_depcluster(cl,isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    return g,torecalc
  end


  def to_graphviz_hieupn(cl,upn,isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    ucl = nil
    if upn.csys.shall_draw then
      if upn.project == self.issue.project then
        if (upn.parent != nil) then
          cl,torecalc,ucl=self.to_graphviz_hieupn(cl,upn.parent,isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
        end
      end
      colorstr = upn.csys.get_border_color
      shapestr = upn.tracker.csys.paint_pref[:chapter_shape]
      labelstr = upn.csys.get_label_noid(self.issue.project)
      fontnamestr = 'times italic'
      fillstr = upn.csys.get_fill_color
      if ucl == nil then
        ucl = cl
      end
      upcl = ucl.add_graph(("cluster"+upn.id.to_s).to_sym, :label => labelstr, :fontname => fontnamestr, :penwidth => 1,
      :URL => root_url + "/issues/" + upn.id.to_s,:fontsize => 10, :margin => 4, :tooltip => upn.description,
      :labeljust => 'l', :labelloc=>'t')
      if (isfirst) then
        torecalc[upn.id.to_s.to_sym] = upn.id
      end
    end
    return cl,torecalc,upcl
  end

  def to_graphviz_hiedwn(cl,n_node,dwn,isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    if dwn.csys.shall_draw then
      colorstr = dwn.csys.get_border_color
      if (dwn.children.size == 0) then
        if not(dwn.csys.shall_show_id) then
          shapestr =  dwn.tracker.csys.paint_pref[:chapter_shape]
          labelstr = dwn.csys.get_label_noid(self.issue.project)
          fontnamestr = 'times italic'
        else
          shapestr = dwn.tracker.csys.paint_pref[:issue_shape]
          labelstr = dwn.csys.get_label_issue(self.issue.project)
          fontnamestr = 'times'
        end

        fillstr = dwn.csys.get_fill_color
        dwn_node = cl.add_nodes( dwn.id.to_s, :label => labelstr, :fontname => fontnamestr,
          :style => 'filled', :color => colorstr, :fillcolor => fillstr, :shape => shapestr,
          :URL => root_url + "/issues/" + dwn.id.to_s,:fontsize => 10, :margin => 0.03, :width => 0, :height => 0, :penwidth => 0.5, :tooltip => dwn.description)
      else
        labelstr = dwn.csys.get_label_noid(self.issue.project)
        fontnamestr = 'times italic'
        scl = cl.add_graph(("cluster"+dwn.id.to_s).to_sym, :label => labelstr, :fontname => fontnamestr, :penwidth => 1,
        :URL => root_url + "/issues/" + dwn.id.to_s,:fontsize => 10, :margin => 4, :tooltip => dwn.description,
        :labeljust => 'l', :labelloc=>'t')
        if dwn.project == self.issue.project then
          dwn.children.each {|dwn2|
            scl,torecalc=self.to_graphviz_hiedwn(scl,dwn_node,dwn2,isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
          }
        end
      end
      if (isfirst) then
        torecalc[dwn.id.to_s.to_sym] = dwn.id
      end
    end
    return cl,torecalc
  end


  def to_graphviz_hiecluster(cl,isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    if self.shall_draw then
      ucl = nil
      if (self.issue.parent != nil) then
        cl,torecalc,ucl=self.to_graphviz_hieupn(cl,self.issue.parent,isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
      end
      if ucl == nil then
        ucl = cl
      end
      colorstr = self.get_border_color
      if (self.issue.children.size == 0) then
        if not(self.shall_show_id) then
          shapestr =  self.issue.tracker.csys.paint_pref[:chapter_shape]
          labelstr = self.get_label_noid(self.issue.project)
          fontnamestr = 'times italic'
        else
          shapestr =  self.issue.tracker.csys.paint_pref[:issue_shape]
          labelstr = self.get_label_issue(self.issue.project)
          fontnamestr = 'times'
        end
        fillstr = self.get_fill_color
        n_node = ucl.add_nodes( self.issue.id.to_s, :label => labelstr, :fontname => fontnamestr,
        :style => 'filled', :color => colorstr, :fillcolor => fillstr, :shape => shapestr, :penwidth => 1,
        :URL => root_url + "/issues/" + self.issue.id.to_s,:fontsize => 10, :margin => 0.03, :width => 0, :height => 0, :tooltip => self.issue.description)

      else
        labelstr = self.get_label_noid(self.issue.project)
        fontnamestr = 'times italic'
        scl = ucl.add_graph(("cluster"+self.issue.id.to_s).to_sym, :label => labelstr, :fontname => fontnamestr, :penwidth => 1,
        :URL => root_url + "/issues/" + self.issue.id.to_s,:fontsize => 10, :margin => 4, :tooltip => self.issue.description,
        :labeljust => 'l', :labelloc=>'t',:rankdir => "TD")
        self.issue.children.each{|dwn|
          scl,torecalc=self.to_graphviz_hiedwn(scl,n_node,dwn,isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
        }
      end
    end
    return cl,torecalc
  end

  def to_graphviz_hiegraph(isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    # Create a new graph
    g = GraphViz.new( :G, :type => :digraph,:margin => 0, :ratio => 'compress', :size => "3000,3000", :strict => true, :rankdir => "DT", :layout => :fdp)
    cl = g.add_graph(:clusterH, :label => 'Hierarchy', :labeljust => 'l', :labelloc=>'t', :margin=> '1', :fontsize => 10)
    cl,torecalc = self.to_graphviz_hiecluster(cl,isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    return g,torecalc
  end

  def to_graphviz_graph_str(isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    g,torecalc = self.to_graphviz_depgraph(isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    result="{{graphviz_link()\n" + g.to_s + "\n}}"
    g2,torecalc = self.to_graphviz_hiegraph(isfirst,torecalc,root_url,max_graph_siblings,max_graph_levels)
    result+=" {{graphviz_link()\n" + g2.to_s + "\n}}"
    return result,torecalc
  end

  def show_graphs(root_url,max_graph_siblings,max_graph_levels)
    strdiag,torecalc = self.to_graphviz_graph_str(true,{},root_url,max_graph_siblings,max_graph_levels)
    return strdiag
  end

  def show_depgraph(root_url,max_graph_siblings,max_graph_levels)
    g,torecalc = self.to_graphviz_depgraph(true,{},root_url,max_graph_siblings,max_graph_levels)
    result = "{{graphviz_link()\n" + g.to_s + "\n}}"
    return result
  end

  def show_hiegraph(root_url,max_graph_siblings,max_graph_levels)
    g2,torecalc = self.to_graphviz_hiegraph(true,{},root_url,max_graph_siblings,max_graph_levels)
    result = "{{graphviz_link()\n" + g2.to_s + "\n}}"
    return result
  end

  def update_chapter_subtree(ord)
    if (ord != self.chapter_order) then
      self.chapter_order = ord
      #self.update_cschapter
      self.save
    end
    ch = self.issue.children.sort_by {|obj| obj.csys.chapter_order}
    chord = 1
    if (ch != nil) then
      ch.each { |c|
        c.csys.update_chapter_subtree(chord)
        chord += 1
      }
    end
  end

  def update_cschapter
    if self.issue.id != nil
      self.issue.reload
    end
    cvchap = self.issue.custom_field_values.select{|a| a.custom_field_id == @@cfchapter.id }.first
    sortchap = self.sortable_chapter_str
    if cvchap.value != sortchap then
      cvchap.value = sortchap
      self.issue.save
    end
  end


  def update_cschapter_no_bd
    cvchap = self.issue.custom_field_values.select{|a| a.custom_field_id == @@cfchapter.id }.first
    sortchap = self.sortable_chapter_str
    if cvchap.value != sortchap then
      cvchap.value = sortchap
    end
  end

  def get_identifier
    if self.csid == nil then
      cvid = self.issue.custom_values.find_by_custom_field_id(@@cfid.id)
      if cvid == nil then
        cvid = self.issue.custom_values.new
        cvid.custom_field_id = @@cfid.id
      end
      cvid.value = self.identifier
      self.csid = cvid
      cvid.save
      self.save
    end
    return self.identifier
  end

  def csys_cfields_to_sync_with_copy
    ret = []
    cf = IssueCustomField.find_by_name("depGrahInReports")
    ret << cf

    return ret
  end

  def save_post_process
  end

  def save_pre_process
  end

  private

  def init_attr
    p = self.issue.project
    if p.id != nil then
      p.reload
    end
    puts self.issue
    puts p
    cp = p.csys
    if cp.id != nil then
      cp.reload
    end
    self.cosmosys_project = cp
    self.identifier = cp.code + '-' + format('%04d', cp.id_counter+1)
    cp.id_counter += 1
    cp.save
    cvid = self.issue.custom_values.find_by_custom_field_id(@@cfid.id)
    if cvid != nil then
      cvid.value = self.identifier
      self.csid = cvid
      cvid.save
    end
  end
end
