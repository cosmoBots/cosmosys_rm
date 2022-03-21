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
      after_save :csys_save_post_process

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
    def sortable_chapter_str
      self.csys.sortable_chapter_str
    end

    def propagate(dest,c1)
      is_changed = false
      if (self.subject != dest.subject) then
        is_changed = true
        puts "subject"
        dest.subject = self.subject
      end
      if (self.description != dest.description) then
        is_changed = true
        puts "description"
        dest.description = self.description
      end
      c1.each {|cf|
        src_cv = self.custom_values.find_by_custom_field_id(cf.id)
        if (src_cv != nil) then
          dst_cv = dest.custom_values.find_by_custom_field_id(cf.id)
          if (dst_cv == nil) then
            dst_cv = dest.custom_values.new
            dst_cv.custom_field = cf
            dst_cv.value = src_cv.value
            puts "cv1 "
            puts src_cv
            puts dst_cv
            is_changed = true
            dst_cv.save
          else
            if (dst_cv.value != src_cv.value) then
              is_changed = true
              puts "cv2 "
              puts src_cv.value
              puts dst_cv.value					
              dst_cv.value = src_cv.value
              dst_cv.save
            end
          end
        end
      }
      if (is_changed) then
        puts "saving!!"
        dest.save
      end
    end	

    def csys_save_post_process
      # "Constants"
      psandbox = Project.find("sandbox").csys
      # Preparing the C1 and C2 list (CustomField part)
      c1 = []
      c2 = []
      cf = CustomField.find_by_name("rqType")
      c1 << cf 
      c2 << cf
      cf = CustomField.find_by_name("rqLevel")
      c1 << cf 
      c2 << cf
      cf = CustomField.find_by_name("rqVar")
      c1 << cf 
      c2 << cf
      cf = CustomField.find_by_name("rqValue")
      c1 << cf 
      c2 << cf
      cf = CustomField.find_by_name("Verification")
      c1 << cf 
      c2 << cf
      cf = CustomField.find_by_name("Verif_Descr")
      c1 << cf 
      c2 << cf
      cf = CustomField.find_by_name("rqRationale")
      c1 << cf 
      c2 << cf



      p1 = self.project.csys.find_root
      if (p1 == psandbox) then
        self.relations_from.where(relation_type:'copied_to').each{|r|
          # We obtain the other instance in the relation
          idest = r.issue_to
          p2 = idest.project.csys.find_root
          # As a temporary protection, we will only process the ones below the Sandbox tree
          if p2 == psandbox then
            # After selecting the pair, we will propagate
            puts ("From "+self.csys.identifier)
            puts ("To "+idest.csys.identifier)
            puts "Propagating!"
            self.propagate(idest,c1)	    
          end
        }
      end
    end

  end    

end
# Add module to Issue
Issue.send(:include, IssuePatch)

