class CosmosysController < ApplicationController
  before_action :find_project, :authorize

  def menu
  end

  def show
  end
  
  def up
    puts "empiezo " + @issue.csys.chapter_order.to_s
    @issue.csys.chapter_order -= 1.1
    puts "sigo " + @issue.csys.chapter_order.to_s
    @issue.csys.save
    @issue.reenumerate_group
    puts "acabo " + @issue.csys.chapter_order.to_s
    redirect_to :action => 'show', :method => :get, :id => @project.id 
  end
  
  def down
    puts "empiezo " + @issue.csys.chapter_order.to_s
    @issue.csys.chapter_order += 1.1
    puts "sigo " + @issue.csys.chapter_order.to_s
    @issue.csys.save
    @issue.reenumerate_group
    puts "acabo " + @issue.csys.chapter_order.to_s
    redirect_to :action => 'show', :method => :get, :id => @project.id 
  end
  
  def tree
    tree_inner
  end
  
  def tree_inner
    require 'json'

    splitted_url = request.fullpath.split('/cosmosys')
    root_url = request.base_url+splitted_url[0]

    if request.get? then
      print("GET!!!!!")
      if (params[:node_id]) then
        print("NODO!!!\n")
        treedata = @project.csys.show_as_json(params[:node_id],root_url)
      else
        print("PROYECTO!!!\n")
        treedata = @project.csys.show_as_json(nil,root_url)
      end

      respond_to do |format|
        format.html {
          @to_json = treedata.to_json
        }
        format.json { 
          require 'json'
          ActiveSupport.escape_html_entities_in_json = false
          render json: treedata
          ActiveSupport.escape_html_entities_in_json = true        
        }
      end
    else
      print("POST!!!!!")
      structure = params[:structure]
      json_params_wrapper = JSON.parse(request.body.read())
      structure = json_params_wrapper['structure']
      #print ("structure: \n\n")
      #print structure
      rootnode = structure[0]
      structure.each { |n|
        Cosmosys.update_node(n,nil,"",1)
      }
      redirect_to :action => 'tree', :method => :get, :id => @project.id 
    end
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
