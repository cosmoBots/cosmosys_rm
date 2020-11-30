class CosmosysController < ApplicationController
  before_action :find_project#, :authorize, :except => [:find_project, :treeview]

  def menu
  end

  def show
  end
  
  def up
    @issue.csys.chapter_order -= 1.1
    @issue.csys.save
    @issue.reenumerate_group
    redirect_to :action => 'show', :method => :get, :id => @project.id 
  end
  
  def down
    @issue.csys.chapter_order += 1.1
    @issue.csys.save
    @issue.reenumerate_group
    redirect_to :action => 'show', :method => :get, :id => @project.id 
  end
  
  def create_tree(current_issue, root_url, is_project)
    if (is_project) then
      output = ""
      output += ("\project: " + current_issue.project.name)
      issue_url = root_url + '/projects/' + current_issue.project.identifier
      output += ("\nissue_url: " + issue_url.to_s)
      issue_new_url = root_url + '/projects/' + current_issue.project.identifier + '/issues/new'
      output += ("\nissue_new_url: " + issue_new_url.to_s)
      cfprefixvalue = current_issue.project.prefix

      tree_node = {'title':  cfprefixvalue + ". " + current_issue.project.identifier  + ": " + current_issue.project.name,
       'subtitle': current_issue.project.description,
       'expanded': true,
       'id': current_issue.project.id.to_s,
       'return_url': root_url+'/cosmosys/'+current_issue.project.id.to_s+'/treeview.json',
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
    issue_new_url = root_url + '/projects/' + current_issue.project.identifier + '/issues/new?issue[parent_issue_id]=' + current_issue.id.to_s + '&issue[tracker_id]=' + "Feature"
    output += ("\nissue_new_url: " + issue_new_url.to_s)
    cftitlevalue = current_issue.subject
      cfchapterstring = current_issue.chapter_str
      tree_node = {'title':  cfchapterstring + " " + current_issue.identifier  + ": " + cftitlevalue,
       'subtitle': current_issue.description,
       'expanded': true,
       'id': current_issue.id.to_s,
       'return_url': root_url+'/cosmosys/'+current_issue.project.id.to_s+'/treeview.json',
       'issue_show_url': issue_url,
       'issue_new_url': issue_new_url,
       'issue_edit_url': issue_url+"/edit",
       'children': []
     }
   end

    #print tree_node
    #print "children: " + tree_node[:children].to_s + "++++\n"
    if (is_project) then
      childrenitems = current_issue.project.issues.where(:parent => nil).sort_by {|obj| obj.csys.chapter_order}
    else
      childrenitems = current_issue.children.sort_by {|obj| obj.csys.chapter_order}
    end
    childrenitems.each{|c|
      child_node = create_tree(c,root_url,false)
      tree_node[:children] << child_node
    }

    return tree_node
  end
  
  
  def treeview
    require 'json'

    is_project = false
    if request.get? then
      print("GET!!!!!")
      if (params[:node_id]) then
        print("NODO!!!\n")
        thisnodeid = params[:node_id]
      else
        print("PROYECTO!!!\n")     
        res = @project.issues.where(:parent => nil).limit(1)
        thisnodeid = res.first.id
        is_project = true
      end
      thisnode=Issue.find(thisnodeid)

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

      treedata = []

      tree_node = create_tree(thisnode,root_url,is_project)

      treedata << tree_node

      #print treedata


      respond_to do |format|
        format.html {
          if @output then 
            if @output.size <= 500 then
              flash[:notice] = "Issuetree:\n" + @output.to_s
            else
              flash[:notice] = "Issuetree too long response\n"
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
      if (params[:node_id]) then
        puts("nodo" + params[:node_id].to_s)
        treedata = @project.csys.show_as_json(params[:node_id],root_url)
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
