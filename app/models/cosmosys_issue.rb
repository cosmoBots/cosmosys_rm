class CosmosysIssue < ActiveRecord::Base
  belongs_to :issue
  belongs_to :cosmosys_project
  
  before_create :init_attr

  def init_attr
    p = self.issue.project
    cp = CosmosysProject.find_by_project_id(p.id)
    self.cosmosys_project = cp
    self.identifier = cp.prefix + '-' + format('%04d', cp.id_counter+1)
    cp.id_counter += 1
    cp.save
  end  
end
