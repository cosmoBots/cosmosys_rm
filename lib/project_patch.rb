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
    end

  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    def prefix
      self.cosmosys_project.prefix
    end
  end    
end
# Add module to Project
Project.send(:include, ProjectPatch)

