require_dependency 'issue'

# Patches Redmine's Issues dynamically.
module IssuePatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class 
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      
      has_one :cosmosys_issue

    end

  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    def reenumerate_children(updatecf = false)
      # chs = self.children.where.not(cosmosys_issue_id: nil)
      chs = []
      self.children.each{|c|
        csys = CosmosysIssue.find_by_issue_id(c)
        if (csys != nil) then
          chs += [csys]
        end
      }
      chs2 = chs.sort_by{|obj| obj.chapter_order}
      i = 1
      chs2.each{|ch|
        if (ch.chapter_order != i) then
          ch.chapter_order = i
          if (updatecf) then
            puts("-----------")
            ch.update_cschapter
          end     
          ch.save
        end
        puts("+++++++++")
        i += 1
      }
      return i
    end
    
    def reenumerate_group(updatecf = false)
      if (self.parent) then
        next_chapter = self.parent.reenumerate_children(updatecf)
      else
        next_chapter = self.project.reenumerate_children(updatecf)
      end
      return next_chapter
    end
    
    def csys
      if self.cosmosys_issue == nil then
        self.reload
        chapter = self.reenumerate_group
        CosmosysIssue.create!(issue:self,chapter_order:chapter)
      end      
      self.cosmosys_issue
    end
    
    def chapter_order
      self.csys.chapter_order
    end
    def chapter_str
      self.csys.chapter_str
    end

  end    
end
# Add module to Issue
Issue.send(:include, IssuePatch)

