class AddCsrefdoc < ActiveRecord::Migration[5.2]
  def up
    # Creating the status None
    st = IssueStatus.find_by_name("csNone")

    # Creating the csRefDoc tracker
    t = Tracker.new
    t.name = "csRefDoc"
    t.description = "Entries to add reference documentation to the database, and to serve as a chapter"
    t.is_in_chlog = false
    t.is_in_roadmap = false
    t.fields_bits = 247
    t.default_status = st
    cfs = []
		cf = IssueCustomField.find_by_name("csOldCode")
		cfs << cf.id
		cf = IssueCustomField.find_by_name("csID")
		cfs << cf.id
		cf = IssueCustomField.find_by_name("csChapter")
		cfs << cf.id
    t.custom_field_ids += cfs
    t.save

  end

  def down
  end
end
