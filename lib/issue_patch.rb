require_dependency 'issue'

# Patches Redmine's Issues dynamically.
module IssuePatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class 
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      #before_save :check_identifier
      #before_validation :check_identifier
      #after_save :check_chapter
      
      has_one :cosmosys_issue
      
      after_save :init_csys
      
      def init_csys
        cp = CosmosysIssue.create!(issue:self)
      end        
    end

  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    def identifier
      self.cosmosys_issue.identifier
    end
  end    
end
# Add module to Issue
Issue.send(:include, IssuePatch)

