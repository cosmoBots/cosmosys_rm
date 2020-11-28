class CosmosysVersion < ActiveRecord::Base
  belongs_to :version
  belongs_to :cosmosys_version_type
end
