require_dependency 'user'

# Patches Redmine's Users dynamically.
module UserPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class 
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      
      has_one :cosmosys_user
      
      after_save :init_csys
      
      def init_csys
        cp = CosmosysUser.create!(user: self)
      end
    end

  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    def csys
      self.cosmosys_user
    end    
    def gen_rpt
      self.csys.gen_rpt
    end
  end    
end
# Add module to User
User.send(:include, UserPatch)

