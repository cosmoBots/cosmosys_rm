require_dependency 'version'

# Patches Redmine's Versions dynamically.
module VersionPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class 
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      
      has_one :cosmosys_version

    end

  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    def csys
      if self.cosmosys_version == nil then
        CosmosysVersion.create!(version: self)
      end        
      self.cosmosys_version
    end    
    def cosmosys_version_type
      self.csys.cosmosys_version_type
    end    
    def start_date
      self.csys.start_date
    end
  end    
end
# Add module to Version
Version.send(:include, VersionPatch)

