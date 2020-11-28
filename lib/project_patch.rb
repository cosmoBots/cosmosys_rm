require_dependency 'project'

# Patches Redmine's Project dynamically.
module ProjectPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class 
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development

      has_one :cosmosys_project
      
      after_save :init_csys
      
      def init_csys
        cp = CosmosysProject.create!(project: self)
      end           
    end

  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    def csys
      self.cosmosys_project
    end    
    def prefix
      self.csys.prefix
    end
    
    def id_counter 
      self.csys.id_counter
    end
    
  end    
end
# Add module to Project
Project.send(:include, ProjectPatch)

