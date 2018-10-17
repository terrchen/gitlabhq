module Gitlab
  module Ci
    module Status
      module Deployment
        class Success < Status::Extended
          def environment_text_for_pipeline
            if subject.last?
              "Successfully deployed to %{environment_path}."
            else
              "Outdated deployment to %{environment_path}. View the most recent deployment %{deployment_path}."
            end
          end

          def environment_text_for_job
            if subject.last?
              "This job is the most recent deployment to %{environment_path}."
            else
              "This job is an out-of-date deployment to %{environment_path}. View the most recent deployment %{deployment_path}."
            end
          end

          def deployment_path
            return unless subject.environment.last_deployment

            project_job_path(subject.project, subject.environment.last_deployment.deployable)
          end

          def self.matches?(deployment, user)
            deployment.success?
          end
        end
      end
    end
  end
end
