class CosmosysController < ApplicationController
  before_action :find_this_project
  before_action :authorize, :except => [:find_this_project, :treeview,:treeview_commit,:dep_gv,:hie_gv, :convert_to]
  skip_before_action :verify_authenticity_token, only: [:convert_to]

  @@tmpdir = './tmp/csys_plugin/'

  def dep_gv
    splitted_url = request.fullpath.split('/cosmosys')
    root_url = request.base_url+splitted_url[0]
    dg,hg = @project.csys.calculate_graphs(root_url)

    # Prefer early return to avoid over-indentation
    return unless dg != nil

    respond_to do |format|  ## Add this
      format.svg {render :inline => dg.output(:svg => String)}
      format.gv {render :inline => dg.to_s}
    end
  end

  def hie_gv
    splitted_url = request.fullpath.split('/cosmosys')
    root_url = request.base_url+splitted_url[0]
    dg,hg = @project.csys.calculate_graphs(root_url)

    # Prefer early return to avoid over-indentation
    return unless hg != nil

    respond_to do |format|  ## Add this
      format.svg {render :inline => hg.output(:svg => String)}
      format.gv {render :inline => hg.to_s}
    end
  end

  def menu
  end

  def show
    require 'json'

    # Get the user, either from the key or from the current user
    u = (params[:key] != nil) ? User.find_by_api_key(params[:key]) : User.current

    # Block access if the user is not allowed to see the project
    raise ::Unauthorized unless u.allowed_to?(:csys_treeview, @project)

    # Do nothing if the request is not a GET
    return unless request.get?

    respond_to do |format|
      format.html {
        # calculate
        @key = User.current.api_key
        @treeviewpath = "/cosmosys/"+@project.identifier+"/treeview"
      }

      format.json {
        treedata = []
        is_project = @issue ? false : true

        if (@issue) then
          thisnodeid = params[:issue_id]
        else
          res = @project.issues.where(:parent => nil).limit(1)
          thisnodeid = (res.size > 0) ? res.first.id : nil
        end

        thisnode = Issue.find(thisnodeid) unless thisnodeid == nil

        splitted_url = request.fullpath.split('/cosmosys')
        root_url = splitted_url[0]

        tree_node = create_tree(thisnode,root_url,is_project,@project,u.api_key)

        treedata << tree_node

        ActiveSupport.escape_html_entities_in_json = false
        render json: treedata
        ActiveSupport.escape_html_entities_in_json = true
      }
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
    return reltype unless is_dir_to

    return "blocked by" if reltype == "blocks"

    return "follows" if reltype == "precedes"

    return reltype
  end

  private def create_project_tree(current_issue, root_url, thisproject, thiskey)
    issue_url = root_url + '/projects/' + thisproject.identifier
    issue_new_url = root_url + '/projects/' + thisproject.identifier + '/issues/new'
    cfprefixvalue = thisproject.code
    childrentypevector = thisproject.trackers.map{|t| t.name}

    # TODO: CHANGE THESE PATCHES BY A CALLBACK OR SOME PROPERTY, SO COSMOSYS DOES NOT KNOW ANYTHING ABOUT CSYSREQ
    childrentypevector += ["rqInfo","rqComplex","rqOpt","rqMech","rqHw","rqSw"] if childrentypevector.include?("rq")

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

    childrenitems = thisproject.issues.where(:parent => nil).sort_by {|obj| obj.csys.chapter_order}

    childrenitems = thisproject.issues.select { |n| n.parent.project != thisproject } if childrenitems.size == 0

    childrenitems.each {|c| tree_node[:children] << create_tree(c,root_url,false,thisproject,thiskey) if c.csys.shall_draw}

    thisproject.csys.update_cschapters

    return tree_node
  end

  private def create_nonproject_tree(current_issue, root_url, thisproject, thiskey)
    issue_url = root_url + '/issues/' + current_issue.id.to_s
    issue_new_url = root_url + '/projects/' + thisproject.identifier + '/issues/new?issue[parent_issue_id]=' + current_issue.id.to_s + '&issue[tracker_id]=' + "Feature"
    cftitlevalue = current_issue.subject
    cfchapterstring = current_issue.chapter_str
    childrentypevector = CosmosysIssue.get_childrentype(current_issue,current_issue.tracker)
    if current_issue.tracker.name != "rq" then
      childrentypevector += ["rqInfo","rqComplex","rqOpt","rqMech","rqHw","rqSw"] if childrentypevector.include?("rq")
    end
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
      if currentnodetype == "rqInfo" or current_issue.tracker.name == "csInfo" then
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

    childrenitems = current_issue.children.sort_by {|obj| obj.csys.chapter_order}

    childrenitems.each {|c| tree_node[:children] << create_tree(c,root_url,false,thisproject,thiskey) if c.csys.shall_draw}

    return tree_node
  end

  def create_tree(current_issue, root_url, is_project, thisproject, thiskey)
    return is_project ?
      create_project_tree(current_issue, root_url, thisproject, thiskey) :
      create_nonproject_tree(current_issue, root_url, thisproject, thiskey)
  end

  def treeview
    require 'json'

    # Get the user, either from the key or from the current user
    u = (params[:key] != nil) ? User.find_by_api_key(params[:key]) : User.current

    # Block access if the user is not allowed to see the project
    raise ::Unauthorized unless u.allowed_to?(:csys_treeview, @project)

    # Do nothing if the request is not a GET
    return unless request.get?

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
        is_project = @issue ? false : true

        if (@issue) then
          thisnodeid = params[:issue_id]
        else
          res = @project.issues.where(:parent => nil).limit(1)
          thisnodeid = (res.size > 0) ? res.first.id : nil
        end

        thisnode = Issue.find(thisnodeid) if thisnodeid != nil

        splitted_url = request.fullpath.split('/cosmosys')
        root_url = splitted_url[0]

        tree_node = create_tree(thisnode,root_url,is_project,@project,u.api_key)

        treedata << tree_node

        ActiveSupport.escape_html_entities_in_json = false
        render json: treedata
        ActiveSupport.escape_html_entities_in_json = true
      }
    end
  end

  def treeview_commit
    # Get the user, either from the key or from the current user
    u = (params[:key] != nil) ? User.find_by_api_key(params[:key]) : User.current

    # Block access if the user is not allowed to see the project
    raise ::Unauthorized unless u.allowed_to?(:csys_treeview_commit, @project)

    # Do nothing if the request is a GET
    return if request.get?

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

  def tree
    require 'json'

    splitted_url = request.fullpath.split('/cosmosys')
    root_url = request.base_url+splitted_url[0]

    if request.get? then
      treedata = params[:issue_id] ?
        @project.csys.show_as_json(params[:issue_id],root_url,false) :
        @project.csys.show_as_json(nil,root_url,false)

      respond_to do |format|
        format.html {@to_json = treedata.to_json}

        format.json {
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
      structure.each {|n| Cosmosys.update_node(n,nil,"",1)}
      redirect_to :action => 'tree', :method => :get, :id => @project.id
    end
  end

  def find_this_project
    # @project variable must be set before calling the authorize filter
    if (params[:issue_id]) then
      @issue = Issue.find(params[:issue_id])
      @project = @issue.project
    else
      @project = params[:id] ? Project.find(params[:id]) : Project.first
    end
    #print("Project: "+@project.to_s+"\n")
  end

  def convert_to
    project = params[:project]
    title = params[:title]
    code = params[:code]
    uploaded_file = params[:file]
    destination_format = params[:format]

    p = Project.find(project)

    if uploaded_file.blank? || destination_format.blank?
      render json: { error: 'Missing file or format' }, status: :bad_request
      return
    end

    begin
      temp_dir = Dir.mktmpdir

      # Choose the flavour to execute
      flavour_use_template = true

      expected_output_file_name = "#{File.basename(uploaded_file.path, File.extname(uploaded_file.path))}.#{destination_format}"
      expected_output_file_path = File.join(temp_dir, expected_output_file_name)

      if (flavour_use_template) then
        # Construct the expected output file name and path
        inner_output_file_name = "#{File.basename(uploaded_file.path, File.extname(uploaded_file.path))}.odt"
        inner_output_file_path = File.join(temp_dir, inner_output_file_name)
        puts inner_output_file_name
        puts inner_output_file_path
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

        s = Setting.find_by_name("plugin_cosmosys")
        puts("********** HERE **************")
        if (s != nil) then
          puts("********** HERE ************1**")
          report_format = s.value["report_format"]
          report_orientation = s.value["report_orientation"]
        else
          report_format = "A4"
          report_orientation = "Landscape"
        end

        # Copy the template as the base for the LibreOffice management
        # Check first if there is a custom template to use
        # TODO: We are using the "public" folder for uploading an alternative document template for the repos
        # Obviously this is not a good idea, we should find a better way to allow users to change their templates
        command = "cp ./public/csys/template/#{project}/#{report_format}/#{report_orientation}/report_template.odt #{uploaded_file.path}.odt"
        puts command
        output = `#{command} 2>&1`
        success = $?.success?
        if (!success) then
          # There were no template document in public folder
          # copyin the one from the plugin
          command = "cp ./plugins/cosmosys/assets/template/#{report_format}/#{report_orientation}/report_template.odt #{uploaded_file.path}.odt"
          puts command
          output = `#{command} 2>&1`
        end

        # Execute LibreOffice command to process the file
        if p != nil then
          command = "/usr/bin/soffice --invisible --nofirststartwizard --headless --norestore  'macro:///Standard.csys.Headless(\"#{uploaded_file.path}.odt\",\"#{uploaded_file.path}\",\"#{p.name + " requirements"}\",\"#{code}\",\"#{p.name}\")'"
        else
          command = "/usr/bin/soffice --invisible --nofirststartwizard --headless --norestore  'macro:///Standard.csys.Headless(\"#{uploaded_file.path}.odt\",\"#{uploaded_file.path}\",\"#{project + " requirements"}\",\"#{code}\",\"#{project}\")'"
        end

        puts command
        output = `#{command} 2>&1`

        # Copy the output file to its expected location
        command = "cp #{uploaded_file.path}.odt #{inner_output_file_path}"
        puts command
        output = `#{command} 2>&1`

        success = $?.success?

        if success && destination_format != "odt" then
          # Execute LibreOffice command to convert the file
          command = "/usr/bin/soffice --invisible --nofirststartwizard --headless --norestore --convert-to #{destination_format} --outdir #{temp_dir} #{inner_output_file_path}"
          puts command
          output = `#{command} 2>&1`
        end

        success = $?.success?

      else

        # Execute LibreOffice command to convert the file
        command = "/usr/bin/soffice --invisible --nofirststartwizard --headless --norestore --convert-to #{destination_format} --outdir #{temp_dir} #{uploaded_file.path}"
        puts command
        output = `#{command} 2>&1`

        success = $?.success?
      end

      # Kill soffice
      command = 'pkill soffice'
      output = `#{command} 2>&1`
      puts command

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
