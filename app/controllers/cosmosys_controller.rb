class CosmosysController < ApplicationController
  before_action :find_project, :authorize

  def menu
  end

  def show
  end

  def tree
  end
  
  def find_project
    # @project variable must be set before calling the authorize filter
    if (params[:node_id]) then
      @issue = Issue.find(params[:node_id])
      @project = @issue.project
    else
      if(params[:id]) then
        @project = Project.find(params[:id])
      else
        @project = Project.first
      end
    end
    #print("Project: "+@project.to_s+"\n")
  end  
  
end
