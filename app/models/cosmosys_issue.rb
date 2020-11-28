class CosmosysIssue < ActiveRecord::Base
  belongs_to :issue
  belongs_to :cosmosys_project
  
  before_create :init_attr

  def root
    self.issue.parent == nil
  end

  def chapter_str
    if !self.root
      prev_str = self.issue.parent.csys.chapter_str
    else
      prev_str = ''
    end
    return prev_str + self.chapter_order.floor.to_s + '.'
  end

  private

  def notify_parent_node
    if !self.root then
      self.issue.parent.csys.new_child(self)
    else
      self.cosmosys_project.new_child(self)
    end
  end

  def init_attr
    p = self.issue.project
    cp = CosmosysProject.find_by_project_id(p.id)
    self.cosmosys_project = cp
    self.identifier = cp.prefix + '-' + format('%04d', cp.id_counter+1)
    cp.id_counter += 1
    cp.save
  end  
end
