class CosmosysIssue < ActiveRecord::Base
  belongs_to :issue
  belongs_to :cosmosys_project
  
  before_create :init_attr

  def is_root
    self.issue.parent == nil
  end

  def get_descendents
    result = []
    self.issue.children.each{|c|
      result.append(c)
      result += c.get_descendents
    }
    return result
  end

  def chapter_str
    if !self.is_root
      prev_str = self.issue.parent.csys.chapter_str
    else
      prev_str = ''
    end
    return prev_str + self.chapter_order.floor.to_s + '.'
  end


  def create_json(root_url, include_doc_children)
    tree_node = self.issue.attributes.slice("id","tracker_id","subject","description","status_id","fixed_version_id","parent_id","root_id","assigned_to_id","due_date","start_date","done_ratio")
    tree_node[:chapter] = self.chapter_str
    tree_node[:title] = self.issue.subject
    tree_node[:url] = root_url+'/cosmosys/'+self.issue.id.to_s,    
    tree_node[:return_url] = root_url+'/cosmosys/'+self.issue.id.to_s+'/tree.json',    
=begin
    tree_node[:supervisor] = ""
    if @@cfsupervisor != nil then
      cvsupervisor = self.custom_values.find_by_custom_field_id(@@cfsupervisor.id)
      if cvsupervisor != nil then
        tree_node[:supervisor_id] = cvsupervisor.value
        if (cvsupervisor.value != nil) then
          supervisor_id = cvsupervisor.value.to_i
          if (supervisor_id > 0) then  
            tree_node[:supervisor] = User.find(supervisor_id).login
          end
        end
      end
    end
=end
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
        child_node = c.csys.create_json(root_url,include_doc_children)
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

  private

  def init_attr
    p = self.issue.project
    cp = CosmosysProject.find_by_project_id(p.id)
    self.cosmosys_project = cp
    self.identifier = cp.prefix + '-' + format('%04d', cp.id_counter+1)
    cp.id_counter += 1
    cp.save
  end  
end
