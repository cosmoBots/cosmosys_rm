require_dependency 'tracker'

# Patches Redmine's Tracker dynamically.

module TrackerPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class 
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      
      has_one :cosmosys_tracker
      
      after_save :init_csys
      
      def init_csys
        cp = CosmosysTracker.create!(tracker: self)
      end
    end

  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    def csys
      self.cosmosys_tracker
    end    
  end    
end
# Add module to Tracker
Tracker.send(:include, TrackerPatch)

