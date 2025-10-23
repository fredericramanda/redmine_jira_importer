module RedmineJiraImporter
  class Hooks < Redmine::Hook::ViewListener
    # Injecte le JS du plugin dans le <head>
    def view_layouts_base_html_head(context = {})
      javascript_include_tag('redmine_jira_importer')
    end

  end
end
