class CosmosysTracker < ActiveRecord::Base
  belongs_to :tracker
  
  before_create :init_attr

  def init_attr
    
  end  
end
