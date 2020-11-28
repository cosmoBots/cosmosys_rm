Redmine::Plugin.register :cosmosys do
  name 'Cosmosys plugin'
  author 'Txinto Vaz'
  description 'This is a plugin for Redmine, which converts it into a CosmoSys instance'
  version '0.0.1'
  url 'http://cosmobots.eu'
  author_url 'http://cosmobots.eu'

  require 'cosmosys'
  # Patches to the Redmine core.
  require 'tracker_patch'
  require 'user_patch'
  require 'project_patch'
  require 'version_patch'
  require 'issue_patch'
end
