Rails.logger.info "redmine_jira_importer: loading routes..."

RedmineApp::Application.routes.draw do
  scope '/projects/:project_id' do
    get  'issues/import_jira', to: 'jira_imports#new',    as: 'import_jira_project_issues'
    post 'issues/import_jira', to: 'jira_imports#create'
  end
end

Rails.logger.info "redmine_jira_importer: routes loaded."