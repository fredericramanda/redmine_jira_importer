Redmine::Plugin.register :redmine_jira_importer do
  name 'Redmine Jira Importer Plugin'
  author 'Harison Frédéric RAMANDANIARIVO'

  # Assurer la compatibilité avec Redmine 6.1+
  requires_redmine :version_or_higher => '6.1.0'

  description 'Importe des tickets depuis Jira via leurs URLs'
  version '1.0.0'
  url 'https://github.com/fredericramanda/redmine_jira_importer'
  author_url 'https://github.com/fredericramanda'

  # Configuration du plugin
  settings default: {
    'jira_url' => '',
    'jira_username' => '',
    'jira_api_token' => '',
    'custom_field_key' => 'ExtNumero',
    'custom_field_url' => 'ExtURL',
    'user_mapping' => {},
    'status_mapping' => {}
  }, partial: 'settings/jira_importer_settings'

  # Permissions
  project_module :jira_importer do
    permission :import_from_jira, {
      jira_imports: [:new, :create]
    }
  end

  # NOTE: on supprime ici le menu :project_menu (qui faisait apparaître un onglet).
  # Le bouton "Importer depuis Jira" sera injecté via JS pour apparaître à droite du bouton "Nouvelle demande".
end

# Make plugin assets available to the Rails asset pipeline and precompile the JS
Rails.application.config.assets.paths << File.join(File.dirname(__FILE__), 'assets', 'javascripts')
Rails.application.config.assets.precompile += %w[redmine_jira_importer.js]

# Charger le hook qui inclura le JS du plugin
require_relative 'lib/redmine_jira_importer/hooks'

# Ensure settings are properly initialized in database
Rails.configuration.to_prepare do
  begin
    # Initialiser les settings avec les valeurs par défaut si nécessaire
    setting = Setting.where(name: 'plugin_redmine_jira_importer').first_or_initialize
    if setting.new_record?
      setting.value = {
        'jira_url' => '',
        'jira_username' => '',
        'jira_api_token' => '',
        'custom_field_key' => 'ExtNumero',
        'custom_field_url' => 'ExtURL',
        'user_mapping' => {},
        'status_mapping' => {}
      }
      setting.save!
    end
  rescue => e
    Rails.logger.error "Failed to initialize jira_importer settings: #{e.message}"
  end
end
