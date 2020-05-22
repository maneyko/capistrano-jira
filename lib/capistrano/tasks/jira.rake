namespace :load do
  task :defaults do
    set :jira_username,                 ENV["CAPISTRANO_JIRA_USERNAME"]
    set :jira_password,                 ENV["CAPISTRANO_JIRA_PASSWORD"]
    set :jira_hostname,                 ENV["CAPISTRANO_JIRA_HOSTNAME"]
    set :jira_project_key,              nil
    set :jira_status_name,              nil
    set :jira_transition_status,        nil
  end
end

namespace :jira do
  desc "Find and transit possible JIRA issues"
  task :find_and_transit do |_t|
    on :all do |_host|
      utf_x     = "\u{2717}"
      utf_check = "\u{2713}"
      utf_skip  = "\u{21B7}"
      transition_status = fetch(:jira_transition_status)

      cap_jira = Capistrano::Jira.new(
        hostname:          fetch(:jira_hostname),
        username:          fetch(:jira_username),
        password:          fetch(:jira_password),
        transition_status: transition_status
      )

      issue_keys = cap_jira.issue_keys
      info "Transitioning '#{issue_keys.join(", ")}' to '#{transition_status}'"

      issue_keys.each do |issue_key|
        begin
          issue = get_issue(issue_key)
          github_info = get_github_info(issue)

          cap_jira.transition!(issue_key))
          info "#{issue_key}  #{utf_check}  Transitioned to '#{transition_status}'"
        rescue Capistrano::Jira::Warning => e
          warn "#{issue_key}  #{utf_skip}  Skipping transition to #{transition_status}: #{e.message}"
        rescue Capistrano::Jira::Error => e
          warn "#{issue_key}  #{utf_x}  Failed to transition to '#{transition_status}': #{e.message}"
        end
      end
    end
  end

  desc "Check JIRA setup"
  task :check do
    errored = false
    required_params =
      %i[jira_username jira_password jira_site jira_project_key
         jira_status_name jira_transition_name jira_comment_on_transition]

    puts "=> Required params"
    required_params.each do |param|
      print "#{param} = "
      if fetch(param).nil? || fetch(param) == ""
        puts "!!!!!! EMPTY !!!!!!"
        errored = true
      else
        puts param == :jira_password ? "**********" : fetch(param)
      end
    end
    raise StandardError, "Not all required parameters are set" if errored
    puts "<= OK"

    puts "=> Checking connection"
    projects = ::Capistrano::Jira.client.Project.all
    puts "<= OK"

    puts "=> Checking for given project key"
    exist = projects.any? { |project| project.key == fetch(:jira_project_key) }
    unless exist
      raise StandardError, "Project #{fetch(:jira_project_key)} not found"
    end
    puts "<= OK"
  end

  after "deploy:finished", "jira:find_and_transit"
end
