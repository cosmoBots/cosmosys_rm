class CosmosysProject < ActiveRecord::Base
  belongs_to :project
  
  before_create :init_attr

  def new_child(c)
    chs = self.project.issues.where(:parent => nil).sort_by{|obj| obj.csys.chapter_order}
    i = 1
    chs.each{|ch|
      if (ch.csys.chapter_order != i) then
        ch.csys.chapter_order = i
        ch.save
      end
      i += 1
    }
    c.chapter_order = i
  end

  private

  def init_attr
    self.prefix = self.project.identifier
  end

end
