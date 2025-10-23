# Redmine Jira Importer Plugin

A Redmine plugin to import issues from Jira.

## Requirements

| Name               | requirement                      |
| -------------------|----------------------------------|
| `Redmine` version  | >= 4.0                           |
| `Ruby` version     | >= 2.4                           |

## Installation

1.  Clone the repository into your Redmine `plugins` directory:
    ```shell
    cd {REDMINE_ROOT}
    git clone https://github.com/fredericramanda/redmine_jira_importer.git plugins/redmine_jira_importer
    ```

2.  Install the required gems:
    ```shell
    cd {REDMINE_ROOT}
    bundle install
    ```

3.  Run the database migrations:
    ```shell
    bundle exec rake redmine:plugins:migrate RAILS_ENV=production
    ```

4.  Restart your Redmine application server.

## Configuration

1.  Go to `Administration -> Plugins` and configure the `Redmine Jira Importer` plugin.
2.  Enter your Jira instance URL, username, and API token.
3.  Configure the user and status mappings.

## Usage

1.  Go to a project's `Issues` tab.
2.  Click on the `Import Jira` button.
3.  Paste the Jira issue URLs into the text area (one per line).
4.  Click `Import`.

## Features

*   Import Jira issues into Redmine.
*   Map Jira users to Redmine users.
*   Map Jira statuses to Redmine statuses.
*   Fetches issue details like summary, description, assignee, and priority.
*   Adds a link back to the original Jira issue in the description.

## License

This plugin is licensed under the terms of the MIT License.
