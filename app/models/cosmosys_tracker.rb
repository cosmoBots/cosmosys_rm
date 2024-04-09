class CosmosysTracker < ActiveRecord::Base
  belongs_to :tracker

  before_create :init_attr

  def paint_pref
    tn = self.tracker.name
    if tn == "csInfo" or tn == "csRefDoc" then
      return {
        :relation_color => {
          'blocks' => 'blue',
          'precedes' => 'green',
          'relates' => 'grey',
          'copied_to' => 'orange'
        },
        :shall_draw_relation => {
          'blocks' => true,
          'precedes' => true,
          'relates' => true,
          'copied_to' => true
        },
        :issue_color => {
          'normal' => 'black',
          'invalid' => 'red',
          'own' => 'blue',
        },
        :issue_shape => 'note',
        :chapter_shape => 'note',
        :hierankdir => 'TB',
        :deprankdir => 'LR'
      }
    else
      return {
        :relation_color => {
          'blocks' => 'blue',
          'precedes' => 'green',
          'relates' => 'grey',
          'copied_to' => 'orange'
        },
        :shall_draw_relation => {
          'blocks' => true,
          'precedes' => true,
          'relates' => true,
          'copied_to' => true
        },
        :issue_color => {
          'normal' => 'black',
          'invalid' => 'red',
          'own' => 'blue',
        },
        :issue_shape => 'record',
        :chapter_shape => 'note',
        :hierankdir => 'TB',
        :deprankdir => 'LR'
      }
    end
  end

  def childrentype(i)
    i.project.trackers.map{|t| t.name}
  end

  def nodetype(i)
    return i.tracker.name
  end


  def init_attr

  end
end
