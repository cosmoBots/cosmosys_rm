class CosmosysProject < ActiveRecord::Base
  belongs_to :project
  
  before_create :init_attr

  def init_attr
    self.prefix = self.project.identifier
  end

end
