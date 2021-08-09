class CosmosysController < ApplicationController
  before_action :find_this_project
  before_action :authorize, :except => [:find_this_project, :treeview,:treeview_commit]

  @@tmpdir = './tmp/csys_plugin/'

  def menu
  end

  def show
  end
  
  def up
    @issue.csys.chapter_order -= 1.1
    @issue.csys.save
    @issue.csys.update_cschapter
    @issue.reenumerate_group
    redirect_to :action => 'show', :method => :get, :id => @project.id 
  end
  
  def down
    @issue.csys.chapter_order += 1.1
    @issue.csys.save
    @issue.csys.update_cschapter
    @issue.reenumerate_group
    redirect_to :action => 'show', :method => :get, :id => @project.id 
  end
  
  def create_tree(current_issue, root_url, is_project, thisproject)
    if (is_project) then
      output = ""
      output += ("\project: " + thisproject.name)
      issue_url = root_url + '/projects/' + thisproject.identifier
      output += ("\nissue_url: " + issue_url.to_s)
      issue_new_url = root_url + '/projects/' + thisproject.identifier + '/issues/new'
      output += ("\nissue_new_url: " + issue_new_url.to_s)
      cfprefixvalue = thisproject.code

      tree_node = {
        'title':  cfprefixvalue + ". " + thisproject.identifier  + ": " + thisproject.name,
        'subtitle': thisproject.description,
        'expanded': true,
        'id': thisproject.id.to_s,
        'return_url': root_url+'/cosmosys/'+thisproject.id.to_s+'/treeview.json',
        'issue_show_url': issue_url,
        'issue_new_url': issue_new_url,
        'issue_edit_url': issue_url+"/edit",
        'children': []
      }
    else
      output = ""
      output += ("\nissue: " + current_issue.subject)
      issue_url = root_url + '/issues/' + current_issue.id.to_s
      output += ("\nissue_url: " + issue_url.to_s)
      issue_new_url = root_url + '/projects/' + thisproject.identifier + '/issues/new?issue[parent_issue_id]=' + current_issue.id.to_s + '&issue[tracker_id]=' + "Feature"
      output += ("\nissue_new_url: " + issue_new_url.to_s)
      cftitlevalue = current_issue.subject
      cfchapterstring = current_issue.chapter_str
      tree_node = {'title':  cfchapterstring + " " + current_issue.csys.get_identifier  + ": " + cftitlevalue,
        'subtitle': current_issue.description,
        'expanded': true,
        'id': current_issue.id.to_s,
        'return_url': root_url+'/cosmosys/'+thisproject.id.to_s+'/treeview.json?issue_id='+current_issue.id.to_s,
        'issue_show_url': issue_url,
        'issue_new_url': issue_new_url,
        'issue_edit_url': issue_url+"/edit",
        'children': []
      }
    end

    #print tree_node
    #print "children: " + tree_node[:children].to_s + "++++\n"
    if (is_project) then
      childrenitems = thisproject.issues.where(:parent => nil).sort_by {|obj| obj.csys.chapter_order}
    else
      childrenitems = current_issue.children.sort_by {|obj| obj.csys.chapter_order}
    end
    childrenitems.each{|c|
      child_node = create_tree(c,root_url,false,thisproject)
      tree_node[:children] << child_node
    }
    if (is_project) then
      thisproject.csys.update_cschapters
    end
    return tree_node
  end
  
  
  def treeview
    require 'json'

    is_project = false
=begin
    unless User.current.allowed_to?(:csys_treeview, @project)
      raise ::Unauthorized
    end
=end
    if request.get? then
      print("GET!!!!!")
      treedata = []      
      if (@issue) then
        print("NODO!!!\n")
        thisnodeid = params[:issue_id]
      else
        print("PROYECTO!!!\n")
        puts(params[:id])
        puts(params[:issue_id])
        res = @project.issues.where(:parent => nil).limit(1)
        if res.size > 0 then
          thisnodeid = res.first.id
        else
          thisnodeid = nil
        end
        is_project = true
      end
      if (thisnodeid != nil) then
        thisnode=Issue.find(thisnodeid)
      end
      splitted_url = request.fullpath.split('/cosmosys')
      print("\nsplitted_url: ",splitted_url)
      root_url = splitted_url[0]
      print("\nroot_url: ",root_url)
      print("\nbase_url: ",request.base_url)
      print("\nurl: ",request.url)
      print("\noriginal: ",request.original_url)
      print("\nhost: ",request.host)
      print("\nhost wp: ",request.host_with_port)
      print("\nfiltered_path: ",request.filtered_path)
      print("\nfullpath: ",request.fullpath)
      print("\npath_translated: ",request.path_translated)
      print("\noriginal_fullpath ",request.original_fullpath)
      print("\nserver_name ",request.server_name)
      print("\noriginal_fullpath ",request.original_fullpath)
      print("\npath ",request.path)
      print("\nserver_addr ",request.server_addr)
      print("\nhost ",request.host)
      print("\nremote_host ",request.remote_host)

      tree_node = create_tree(thisnode,root_url,is_project,@project)


      #print treedata
      treedata << tree_node

      respond_to do |format|
        format.html {
          if @output then 
            if @output.size <= 500 then
              flash.now[:notice] = "Issuetree:\n" + @output.to_s
            else
              flash.now[:notice] = "Issuetree too long response\n"
            end
          end
        }
        format.json { 
          require 'json'
          ActiveSupport.escape_html_entities_in_json = false
          render json: treedata
          ActiveSupport.escape_html_entities_in_json = true        
        }
      end
    end
  end
  
  def treeview_commit
    is_project = false
    if request.get? then
      print("GET!!!!!")
    else 
      print("POST!!!!!")
      structure = params[:structure]
      json_params_wrapper = JSON.parse(request.body.read())
      structure = json_params_wrapper['structure']
      print ("structure: \n\n")
      print structure
      rootnode = structure[0]
      ch = rootnode['children']
      chord = 1
      if (ch != nil) then
        ch.each { |c| 
          CosmosysIssue.update_node(c,nil,chord)
          chord += 1
        }
      end
      redirect_to :action => 'treeview', :method => :get, :id => @project.id 
    end
  end

  def tree
    require 'json'

    splitted_url = request.fullpath.split('/cosmosys')
    root_url = request.base_url+splitted_url[0]

    if request.get? then
      print("GET tree ")
      if (params[:issue_id]) then
        puts("nodo" + params[:issue_id].to_s)
        treedata = @project.csys.show_as_json(params[:issue_id],root_url)
      else
        puts("proyecto" + @project.id.to_s)
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
      puts("POST tree ")
      structure = params[:structure]
      json_params_wrapper = JSON.parse(request.body.read())
      structure = json_params_wrapper['structure']
      rootnode = structure[0]
      structure.each { |n|
        Cosmosys.update_node(n,nil,"",1)
      }
      redirect_to :action => 'tree', :method => :get, :id => @project.id 
    end
  end
  
  def find_this_project
    puts "find_this_project++++++"
    # @project variable must be set before calling the authorize filter
    if (params[:issue_id]) then
      @issue = Issue.find(params[:issue_id])
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
