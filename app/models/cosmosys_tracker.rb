class CosmosysTracker < ActiveRecord::Base
  belongs_to :tracker
  
  before_create :init_attr

  @@paint_pref = {
    :relation_color => {
      'blocks' => 'red',
      'precedes' => 'blue',
      'relates' => 'green',
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
    :issue_shape => 'Mrecord',
    :chapter_shape => 'note',
    :hierankdir => 'TB',
    :deprankdir => 'LR',
  }

  def paint_pref
    @@paint_pref
  end

  def init_attr
    
  end  
end
