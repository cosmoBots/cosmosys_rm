class CosmosysController < ApplicationController
  before_action :find_this_project
  before_action :authorize, :except => [:find_this_project, :treeview,:treeview_commit,:dep_gv,:hie_gv, :convert_to]
  skip_before_action :verify_authenticity_token, only: [:convert_to]

  @@tmpdir = './tmp/csys_plugin/'

  def dep_gv
    splitted_url = request.fullpath.split('/cosmosys')
    root_url = request.base_url+splitted_url[0]
    dg,hg = @project.csys.calculate_graphs(root_url)
    if (dg != nil) then
      respond_to do |format|  ## Add this
        format.svg {
          render :inline => dg.output(:svg => String)
        }
        format.gv {
          render :inline => dg.to_s
        }
      end
    end
  end

  def hie_gv
    splitted_url = request.fullpath.split('/cosmosys')
    root_url = request.base_url+splitted_url[0]
    dg,hg = @project.csys.calculate_graphs(root_url)
    if (hg != nil) then
      respond_to do |format|  ## Add this
        format.svg {
          render :inline => hg.output(:svg => String)
        }
        format.gv {
          render :inline => hg.to_s
        }
      end
    end
  end



  def menu
  end

  def show
    require 'json'

    is_project = false

    u = nil
    if params[:key] != nil then
      u = User.find_by_api_key(params[:key])
    end
    if u == nil then
      u = User.current
    end

     unless u.allowed_to?(:csys_treeview, @project)
      raise ::Unauthorized
    end
    if request.get? then
      print("GET!!!!!")
      respond_to do |format|
        format.html {
          # calculate 
          @key = User.current.api_key
          @treeviewpath = "/cosmosys/"+@project.identifier+"/treeview"
        }
        format.json { 
          treedata = []
          if (@issue) then
            thisnodeid = params[:issue_id]
          else
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
          #print("\nsplitted_url: ",splitted_url)
          root_url = splitted_url[0]
          #print("\nroot_url: ",root_url)
          #print("\nbase_url: ",request.base_url)
          #print("\nurl: ",request.url)
          #print("\noriginal: ",request.original_url)
          #print("\nhost: ",request.host)
          #print("\nhost wp: ",request.host_with_port)
          #print("\nfiltered_path: ",request.filtered_path)
          #print("\nfullpath: ",request.fullpath)
          #print("\npath_translated: ",request.path_translated)
          #print("\noriginal_fullpath ",request.original_fullpath)
          #print("\nserver_name ",request.server_name)
          #print("\noriginal_fullpath ",request.original_fullpath)
          #print("\npath ",request.path)
          #print("\nserver_addr ",request.server_addr)
          #print("\nhost ",request.host)
          #print("\nremote_host ",request.remote_host)
    
          tree_node = create_tree(thisnode,root_url,is_project,@project,u.api_key)
    
          #print treedata
          treedata << tree_node

          require 'json'
          ActiveSupport.escape_html_entities_in_json = false
          render json: treedata
          ActiveSupport.escape_html_entities_in_json = true        
        }
      end
    end
   
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
  
  def translate_rel(is_dir_to,reltype)
    if is_dir_to then
      if (reltype == "blocks") then
        return "blocked by"
      else 
          if (reltype == "precedes") then
            return "follows"
          else 
            return reltype
          end
        end
    else
      return reltype
    end
  end

  def create_tree(current_issue, root_url, is_project, thisproject,thiskey)
    if (is_project) then
      output = ""
      output += ("\project: " + thisproject.name)
      issue_url = root_url + '/projects/' + thisproject.identifier
      output += ("\nissue_url: " + issue_url.to_s)
      issue_new_url = root_url + '/projects/' + thisproject.identifier + '/issues/new'
      output += ("\nissue_new_url: " + issue_new_url.to_s)
      cfprefixvalue = thisproject.code
      childrentypevector = thisproject.trackers.map{|t| t.name}
      # TODO: CHANGE THESE PATCHES BY A CALLBACK OR SOME PROPERTY, SO COSMOSYS DOES NOT KNOW ANYTHING ABOUT CSYSREQ
      if childrentypevector.include?("rq") then
        childrentypevector += ["rqInfo","rqComplex","rqOpt","rqMech","rqHw","rqSw"]
      end
      infobox = [
        ["Project:"],
        [thisproject.name,"/projects/"+thisproject.identifier,"link"],
        [thisproject.description],
      ]
      tree_node = {
        'title':  cfprefixvalue + ". " + thisproject.identifier  + ": " + thisproject.name,
        'subtitle': thisproject.description,
        'expanded': true,
        'id': thisproject.id.to_s,
        'return_url': root_url+'/cosmosys/'+thisproject.id.to_s+'/treeview.json'+'?key='+thiskey,
        'issue_show_url': issue_url+'?key='+thiskey,
        'issue_new_url': issue_new_url+'?key='+thiskey,
        'issue_edit_url': issue_url+"/edit"+'?key='+thiskey,
        'leaf': childrentypevector.size <= 0,
        'nodetype': "project",
        'childrentype': childrentypevector,
        'info': infobox,
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
      childrentypevector = CosmosysIssue.get_childrentype(current_issue,current_issue.tracker)
      currentnodetype = CosmosysIssue.get_nodetype(current_issue,current_issue.tracker)
      infobox = [
        [currentnodetype+": "+current_issue.csys.identifier],
        [current_issue.description],
      ]
      if current_issue.relations_to.size > 0 then
        infobox += [["*** Incoming relations ***"]]
        current_issue.relations_to.each{|r|
          infobox += [["<- "+translate_rel(true,r.relation_type)+" '"+r.issue_from.subject+"'","/issues/"+r.issue_from_id.to_s,r.issue_from.csys.identifier]]
        }
      end
      if current_issue.relations_from.size > 0 then
        infobox += [["*** Outgoing relations ***"]]
        current_issue.relations_from.each{|r|
          infobox += [["-> "+translate_rel(false,r.relation_type)+" '"+r.issue_to.subject+"'","/issues/"+r.issue_to_id.to_s,r.issue_to.csys.identifier]]
        }
      end
      if (current_issue.children.size > 0) then
        titlestring = cfchapterstring + " : " + cftitlevalue
      else
        # TODO: CHANGE THESE PATCHES BY A CALLBACK OR SOME PROPERTY, SO COSMOSYS DOES NOT KNOW ANYTHING ABOUT CSYSREQ
        if currentnodetype == "rqInfo" then
          titlestring = cfchapterstring + " " + cftitlevalue
        else
          titlestring = cfchapterstring + " " + current_issue.csys.get_identifier  + ": " + cftitlevalue
        end
      end
      tree_node = {
        'title':  titlestring,
        'subtitle': current_issue.description,
        'expanded': true,
        'id': current_issue.id.to_s,
        'return_url': root_url+'/cosmosys/'+thisproject.id.to_s+'/treeview.json?issue_id='+current_issue.id.to_s+'?key='+thiskey,
        'issue_show_url': issue_url+'?key='+thiskey,
        'issue_new_url': issue_new_url+'?key='+thiskey,
        'issue_edit_url': issue_url+"/edit"+'?key='+thiskey,
        'leaf': childrentypevector.size <= 0,
        'nodetype': currentnodetype,
        'childrentype': childrentypevector,
        'info': infobox,
        'children': []
      }
    end

    #print tree_node
    #print "children: " + tree_node[:children].to_s + "++++\n"
    if (is_project) then
      childrenitems = thisproject.issues.where(:parent => nil).sort_by {|obj| obj.csys.chapter_order}
      if childrenitems.size == 0 then
        childrenitems = thisproject.issues.select { |n| n.parent.project != thisproject }
      end
    else
      childrenitems = current_issue.children.sort_by {|obj| obj.csys.chapter_order}
    end
    childrenitems.each{|c|
      if c.csys.shall_draw then
        child_node = create_tree(c,root_url,false,thisproject,thiskey)
        tree_node[:children] << child_node
      end
    }
    if (is_project) then
      thisproject.csys.update_cschapters
    end
    return tree_node
  end
  
  
  def treeview
    require 'json'

    is_project = false

    u = nil
    if params[:key] != nil then
      u = User.find_by_api_key(params[:key])
    end
    if u == nil then
      u = User.current
    end

    unless u.allowed_to?(:csys_treeview, @project)
      raise ::Unauthorized
    end
    if request.get? then
      print("GET!!!!!")
      respond_to do |format|
        format.html {
          # calculate 
          puts("key")
          @key = User.current.api_key
          puts(@key)
          splitted_url = request.fullpath.split('/cosmosys')
          root_url = splitted_url[0]
          @treeviewpath = root_url+"/cosmosys/"+@project.identifier+"/treeview"
        }
        format.json { 
          treedata = []
          if (@issue) then
            thisnodeid = params[:issue_id]
          else
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
          #print("\nsplitted_url: ",splitted_url)
          root_url = splitted_url[0]
          #print("\nroot_url: ",root_url)
          #print("\nbase_url: ",request.base_url)
          #print("\nurl: ",request.url)
          #print("\noriginal: ",request.original_url)
          #print("\nhost: ",request.host)
          #print("\nhost wp: ",request.host_with_port)
          #print("\nfiltered_path: ",request.filtered_path)
          #print("\nfullpath: ",request.fullpath)
          #print("\npath_translated: ",request.path_translated)
          #print("\noriginal_fullpath ",request.original_fullpath)
          #print("\nserver_name ",request.server_name)
          #print("\noriginal_fullpath ",request.original_fullpath)
          #print("\npath ",request.path)
          #print("\nserver_addr ",request.server_addr)
          #print("\nhost ",request.host)
          #print("\nremote_host ",request.remote_host)
    
          puts("---->User",u)
          tree_node = create_tree(thisnode,root_url,is_project,@project,u.api_key)
    
          #print treedata
          treedata << tree_node

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

    if params[:key] != nil then
      u = User.find_by_api_key(params[:key])
    else
      u = User.current
    end

    unless u.allowed_to?(:csys_treeview_commit, @project)
      raise ::Unauthorized
    end

    if request.get? then
      print("GET!!!!!")
    else 
      print("POST!!!!!")
      structure = params[:structure]
      json_params_wrapper = JSON.parse(request.body.read())
      structure = json_params_wrapper['structure']
      print ("structure: \n\n")
      puts structure
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
      if (params[:issue_id]) then
        treedata = @project.csys.show_as_json(params[:issue_id],root_url,false)
      else
        treedata = @project.csys.show_as_json(nil,root_url,false)
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

  def convert_to
    uploaded_file = params[:file]
    destination_format = params[:format]

    if uploaded_file.blank? || destination_format.blank?
      render json: { error: 'Missing file or format' }, status: :bad_request
      return
    end
    
    begin
      temp_dir = Dir.mktmpdir

      # Choose the flavour to execute
      flavour_use_template = true

      if (flavour_use_template) then
        # Construct the expected output file name and path
        #expected_output_file_name = "#{File.basename(uploaded_file.path, File.extname(uploaded_file.path))}.#{destination_format}"
        expected_output_file_name = "#{File.basename(uploaded_file.path, File.extname(uploaded_file.path))}.odt"
        expected_output_file_path = File.join(temp_dir, expected_output_file_name)
        puts expected_output_file_name
        puts expected_output_file_path
        puts temp_dir

        # First we copy the macro and the correct configuration to the LibreOffice profile
        command = "cp -r plugins/cosmosys/assets/template/.config/ ~"
        puts command
        output = `#{command} 2>&1`

        # Then we prepare the temporary directory
        # TODO: Confirm and remove this step
        command = "mkdir -p #{temp_dir}"
        puts command
        output = `#{command} 2>&1`

        # Copy the template as the base for the LibreOffice management
        command = "cp ./plugins/cosmosys/assets/template/report_template.odt #{uploaded_file.path}.odt"
        puts command
        output = `#{command} 2>&1`

        # Execute LibreOffice command to process the file
        command = "/usr/bin/soffice --invisible --nofirststartwizard --headless --norestore  'macro:///Standard.csys.Headless(\"#{uploaded_file.path}.odt\",\"#{uploaded_file.path}\")'"
        puts command
        output = `#{command} 2>&1`

        # Copy the output file to its expected location
        command = "cp #{uploaded_file.path}.odt #{expected_output_file_path}"        
        puts command
        output = `#{command} 2>&1`
        
        success = $?.success?

        # Kill soffice
        command = 'pkill soffice'
        output = `#{command} 2>&1`
        puts command

      else
        expected_output_file_name = "#{File.basename(uploaded_file.path, File.extname(uploaded_file.path))}.#{destination_format}"
        expected_output_file_path = File.join(temp_dir, expected_output_file_name)

        # Execute LibreOffice command to convert the file
        command = "/usr/bin/soffice --invisible --nofirststartwizard --headless --norestore --convert-to #{destination_format} --outdir #{temp_dir} #{uploaded_file.path}"
        puts command
        output = `#{command} 2>&1`

        success = $?.success?
      end

      unless success
        Rails.logger.error "Conversion command failed with output: #{output}"
        render json: { error: 'Conversion failed', output: output }, status: :internal_server_error
        return
      else
        # If conversion is successful, send the file back to the client
        if File.exist?(expected_output_file_path)
          send_file(
            expected_output_file_path,
            filename: expected_output_file_name,
            disposition: 'attachment'
          )

        else
          render json: { error: 'Conversion failed' }, status: :internal_server_error
        end
      end
      
    ensure
      Thread.new do
        sleep 60 # sleep for 60 seconds
        FileUtils.remove_entry_secure(temp_dir)
        File.delete(expected_output_file_path) if File.exist?(expected_output_file_path)
      end
    end
  end

end
