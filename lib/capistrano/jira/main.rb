module Capistrano
  module Jira
    class Error < StandardError; end

    class Main
      attr_reader :transition_status

      def initialize(hostname:, username:, password:, transition_statustatus
        @client = JIRA::Client.new(
          site:         hostname,
          username:     username,
          password:     password,
          context_path: "",
          auth_type:    :basic
        )
        @transition_status = transition_status
      end

      def get_issue(issue_key)
        @client.Issue.jql("key = '#{issue_key}'").first
      end

      def get_github_info(issue)
        JSON.parse(@client.get("/rest/dev-status/1.0/issue/summary?issueId=#{issue.id}").body)
      end

      def transition!(issue_key)
        begin
          issue = get_issue(issue_key)
        rescue JIRA::HTTPError
          raise Error, "Could not find issue with key: #{issue_key}"
        end
        transition =
          issue.transitions.all.find do |transition|
            transition if transition.attrs["name"] == transition_status
          end.compact.first
        raise Error, "Invalid transition from '#{issue.status.name}' to '#{transition_status}'" if transition.nil?
        raise Warning, "'#{issue.status.name}' is already in '#{transition_status}'" if transition.name == issue.status.name
        begin
          transition_hash = { transition: id: transition.id }
          issue.transitions.build.save!(transition_hash(transition))
        rescue JIRA::HTTPError
          raise Error, "An error occurred while saving the transition"
        end
      end

      def transition_hash(transition)
        hash = { transition: { id: transition.id } }
        if fetch(:jira_comment_on_transition)
          hash.merge({
            update: {
              comment: [
                {
                  add: {
                    body: "Issue transitioned from '#{transition.issue.status.name}'" +
                          " to '#{transition_status}' automatically during deployment."
                  }
                }
              ]
            }
          })
        else
          hash
        end
      end

      def issue_keys
        commits_since_master.scan(/\b([\w]+-[\d]+)\b/).uniq.flatten
      end

      def branch_name
        @branch_name ||= `git rev-parse --abbrev-ref HEAD`.chomp
      end

      def commits_since_master
        @commits_since_master ||= `git log origin/master..origin/#{branch_name}`.chomp
      end
    end
  end
end
