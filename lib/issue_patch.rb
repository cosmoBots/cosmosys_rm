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
      before_save :csys_save_pre_process

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
        if (self.id != nil) then
          self.reload
        end
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
      notes = "#### Propagation from commander issue ##"+self.id.to_s+" caused by user#"+User.current.id.to_s+"\n"
      j = dest.journals.new
      j.user = User.find_by_login("admin")

      is_changed = false
      if (self.tracker != dest.tracker) then
        if not dest.project.include?(self.tracker) then
          dest.project.trackers << self.tracker;
          notes += "* Adding tracker "+self.tracker.to_s+" to project project#"+dest.project.id.to_s+"\n"
        end
        is_changed = true
        notes += "* Updating tracker from "+dest.tracker.to_s+" to "+self.tracker.to_s+"\n"
        dest.tracker = self.tracker
      end
      if (self.assigned_to != dest.assigned_to) then
        if (self.assigned_to != nil) then
          memberlist = dest.project.members.where(user:self.assigned_to)
          if (memberlist.size<=0) then
            mb = dest.project.members.new;
            r = Role.find_by_name("rqWriter")
            mb.roles << r
            mb.user = self.assigned_to
            notes += "* Adding membership for user#"+self.assigned_to.id.to_s+" with role '"+r.to_s+"' to project project#"+dest.project.id.to_s+"\n"
            mb.save            
          end
        end
        is_changed = true
        destusr = "None"
        if (dest.assigned_to != nil) then
          destusr = "user#"+dest.assigned_to.id.to_s
        end
        srcusr = "None"
        if (self.assigned_to != nil) then
          srcusr = "user#"+self.assigned_to.id.to_s
        end
        notes += "* Updating assignee from user "+destusr+" to user "+srcusr+"\n"
        dest.assigned_to = self.assigned_to
      end
      if (self.subject != dest.subject) then
        is_changed = true
        notes += "* Updating subject from '"+dest.subject+"' to '"+self.subject+"'\n"
        dest.subject = self.subject
      end
      if (self.description != dest.description) then
        is_changed = true
        notes += "* Updating description from '"+dest.description.to_s+"' to '"+self.description.to_s+"'\n"
        dest.description = self.description
      end
      if (self.status != dest.status) then
        is_changed = true
        notes += "* Updating status from '"+dest.status.name+"' to '"+self.status.name+"'\n"
        dest.status = self.status
      end

      self.custom_field_values.each{|cfv|
        cf = cfv.custom_field
        if c1.include?(cf) then
          dcfv_found = false
          dest.custom_field_values.each{|dcfv|
            if dcfv.custom_field == cf then
              dcfv_found = true
              if (cfv.value != dcfv.value) then
                is_changed = true
                notes += "* Updating custom field '"+cf.name+"' from '"+ dcfv.value.to_s+"' to '"+cfv.value.to_s+"'\n"
                dcfv.value = cfv.value     
              end
              break
            end
          }
          if not(dcfv_found) then
            # Create the dcfv
            dcfv = dest.custom_field_values.new
            dcfv.custom_field = cf
            notes += "* Creating new custom field '"+cf.name+"' and assigning value '"+cfv.value.to_s+"'\n"
            is_changed = true
            dcfv.value = cfv.value
          end
        end
      }
=begin
      c1.each {|cf|
        src_cv = self.custom_values.find_by_custom_field_id(cf.id)
        if (src_cv != nil) then
          dst_cv = dest.custom_values.find_by_custom_field_id(cf.id)
          if (dst_cv == nil) then
            dst_cv = dest.custom_values.new
            dst_cv.custom_field = cf
            dst_cv.value = src_cv.value
            notes += "* Creating new custom field '"+cf.name+"' and assigning value '"+dst_cv.value.to_s+"'\n"
            is_changed = true
            dst_cv.save
          else
            if (dst_cv.value != src_cv.value) then
              is_changed = true
              notes += "* Updating custom field '"+cf.name+"' from '"+ dst_cv.value.to_s+"' to '"+src_cv.value.to_s+"'\n"
              dst_cv.value = src_cv.value
              dst_cv.save
            end
          end
        end
      }
=end
      if (is_changed) then
        j.private_notes = true
        j.notes = notes
        saved = dest.save
        if (not saved) then
          notes += "#### ERROR! Propagation could not be perfomed due to following errors:\n"
          dest.errors.each{|e|
            notes += "* "+e.to_s+"\n"
          }
        end
        j.save
      end
    end

    def csys_save_pre_process
      # Let's see if there are other processes to do in the cosmosys classes
      self.csys.save_pre_process
    end

    def csys_save_post_process

      # Let's see if there are copies
      copies = self.relations_from.where(relation_type:'copied_to')
      if copies.size > 0 then
        c1 = self.csys.csys_cfields_to_sync_with_copy
        copies.each{|r|
          # We obtain the other instance in the relation
          idest = r.issue_to
          puts ("From "+self.csys.identifier)
          puts ("To "+idest.csys.identifier)
          puts "Propagating!"
          self.propagate(idest,c1)
        }
      end
    end

  end    

end
# Add module to Issue
Issue.send(:include, IssuePatch)

