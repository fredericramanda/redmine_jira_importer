class JiraImportsController < ApplicationController
  accept_api_auth :new, :create

  before_action :find_project
  before_action :authorize_import

  # GET /projects/:project_id/issues/import_jira
  def new
    render partial: 'modal_content', layout: false
  end

  # POST /projects/:project_id/issues/import_jira
  def create
    Rails.logger.info "Jira import started by #{User.current.login}"
    # Support for multiple URLs (textarea named :jira_urls) or single :jira_url
    raw = (params[:jira_urls].presence || params[:jira_url].to_s).to_s
    urls = raw.split(/\r?\n/).map(&:strip).reject(&:blank?)

    success = []
    errors = []

    urls.each do |url|
      begin
        Rails.logger.info "Importing Jira URL: #{url}"
        issue = import_jira_issue(url)
        success << { url: url, issue_id: issue.id, issue_subject: issue.subject }
        Rails.logger.info "Successfully imported Jira URL: #{url} as Redmine issue ##{issue.id}"
      rescue => e
        errors << { url: url, error: e.message }
        Rails.logger.error "Failed to import Jira URL: #{url}. Error: #{e.message}"
      end
    end

    # If this is an XHR (remote) request, return JSON expected by the frontend
    if request.xhr?
      render json: { success: success, errors: errors }
      return
    end

    # Non-AJAX fallback behaviour
    if errors.any?
      flash[:error] = "#{errors.size} error(s) during import"
      redirect_to "/projects/#{@project.identifier}/issues/import_jira"
    else
      flash[:notice] = "#{success.size} ticket(s) imported (simulation)"
      redirect_to project_issues_path(@project)
    end
  end

  private

  def find_project
    @project = Project.find_by_identifier(params[:project_id]) || Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_import
    render_403 unless User.current.allowed_to?(:import_from_jira, @project, :global => true)
  end

  def import_jira_issue(url)
    Rails.logger.info "Starting import_jira_issue for URL: #{url}"
    # Extract Jira key from URL
    jira_key = extract_jira_key(url)
    raise "Invalid Jira URL" unless jira_key
    Rails.logger.info "Extracted Jira key: #{jira_key}"

    # Fetch data from Jira
    Rails.logger.info "Fetching Jira data for key: #{jira_key}"
    jira_data = fetch_jira_issue(jira_key)
    Rails.logger.info "Successfully fetched Jira data for key: #{jira_key}}"

    settings = Setting.plugin_redmine_jira_importer
    customFieldKey = settings['custom_field_key']

    if customFieldKey
      # try to find by existing issue with ExtNumero = jira_key
      existing_issues = Issue.joins(:custom_values)
                            .where(custom_values: { custom_field_id: CustomField.find_by_name('ExtNumero').id, value: jira_key }, project_id: @project.id)
      if existing_issues.any?
        Rails.logger.error "Found existing Redmine issue(s) for Jira key: #{jira_key}, raise error"
        raise "Found existing Redmine issue(s) for Jira key: #{jira_key}"
      end
    end

    # Create Redmine issue
    Rails.logger.info "Creating Redmine issue for Jira key: #{jira_key}"
    issue = Issue.new(
      project: @project,
      tracker_id: @project.trackers.first.id,
      subject: jira_data['fields']['summary'],
      description: convert_description(jira_data),
      author: User.current,
      assigned_to: map_user(jira_data['fields']['assignee']),
      status: map_status(jira_data['fields']['status']),
      priority: map_priority(jira_data['fields']['priority'])
    )

    # Add custom fields if needed
    if jira_data['fields']['duedate']
      issue.due_date = Date.parse(jira_data['fields']['duedate'])
    end
    issue.save!
    issue.reload

    if customFieldKey
      # Save jira_key and url to custom fields
      if numero_field = CustomField.find_by_name('ExtNumero')
        numero_cv = issue.custom_values.find_or_initialize_by(:custom_field => numero_field)
        numero_cv.value = jira_key
        numero_cv.save
      end
    end

    customFieldUrl = settings['custom_field_url']
    if customFieldUrl
      jira_url = settings['jira_url']
      my_url = url
      if my_url == jira_key
        my_url = jira_url + '/browse/' + jira_key
      end

      if url_field = CustomField.find_by_name('ExtURL')
        url_cv = issue.custom_values.find_or_initialize_by(:custom_field => url_field)
        url_cv.value = my_url
        url_cv.save
      end
    end
    issue.save!

    Rails.logger.info "Successfully saved Redmine issue ##{issue.id} for Jira key: #{jira_key}"
    issue
  end

  def extract_jira_key(url)
    # Support different Jira URL formats
    # Ex: https://jira.example.com/browse/PROJ-123
    match = url.match(/\/browse\/([A-Z]+-\d+)/)
    match ? match[1] : url
  end

  def fetch_jira_issue(jira_key)
    settings = Setting.plugin_redmine_jira_importer
    jira_url = settings['jira_url']
    username = settings['jira_username']
    api_token = settings['jira_api_token']

    raise "Missing Jira configuration" if jira_url.blank? || username.blank? || api_token.blank?

    require 'net/http'
    require 'json'
    require 'uri'

    # Request only the needed fields to reduce payload
    fields = '-comments'
    uri = URI("#{jira_url}/rest/api/2/issue/#{jira_key}")
    uri.query = URI.encode_www_form(fields: fields)

    request = Net::HTTP::Get.new(uri)
    request.basic_auth(username, api_token)
    request['Content-Type'] = 'application/json'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    raise "Jira error: #{response.code} - #{response.body}" unless response.code == '200'

    JSON.parse(response.body)
  end

  def convert_description(jira_data)
    description = jira_data['fields']['description'] || ''
    
    # Add Jira metadata
    metadata = "\n\n---\n*Imported from Jira*\n"
    metadata += "* Jira Key: #{jira_data['key']}\n"
    metadata += "* Reporter: #{jira_data['fields']['reporter']['displayName']}\n" if jira_data['fields']['reporter']
    metadata += "* Created: #{jira_data['fields']['created']}\n"
    
    description + metadata
  end

  def map_user(jira_user)
    return User.current unless jira_user

    settings = Setting.plugin_redmine_jira_importer
    user_mapping = settings['user_mapping'] || {}
    
    jira_email = jira_user['emailAddress']
    redmine_user_id = user_mapping[jira_email]

    Rails.logger.info "map_user ==> #{jira_email} or #{User.current} or #{redmine_user_id}"

    if redmine_user_id
      User.find_by(id: redmine_user_id)
    else
      # Try to find by email using EmailAddress model
      email_address = EmailAddress.find_by(address: jira_email)
      Rails.logger.info "map_user ==> #{email_address}"
      if email_address and email_address&.user.status == User::STATUS_ACTIVE
        email_address&.user
      else
        User.current
      end
    end
  end

  def map_status(jira_status)
    return IssueStatus.find_by(id: 1) unless jira_status

    settings = Setting.plugin_redmine_jira_importer
    status_mapping = settings['status_mapping'] || {}
    
    jira_status_name = jira_status['name']
    redmine_status_id = status_mapping[jira_status_name]

    if redmine_status_id
      IssueStatus.find_by(id: redmine_status_id) || IssueStatus.find_by(id: 1)
    else
      IssueStatus.find_by(id: 1)
    end
  end

  def map_priority(jira_priority)
    return IssuePriority.default unless jira_priority

    # Simple mapping by name
    priority_name = jira_priority['name']
    IssuePriority.find_by(name: priority_name) || IssuePriority.default
  end
end
