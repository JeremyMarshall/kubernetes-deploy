# frozen_string_literal: true
module KubernetesDeploy
  class CustomResourceDefinition < KubernetesResource
    TIMEOUT = 2.minutes
    CHILD_CR_TIMEOUT_ANNOTATION = "kubernetes-deploy.shopify.io/cr-timeout-override"
    MONITOR_ROLLOUT_ANNOTATION = "kubernetes-deploy.shopify.io/monitor-rollout"
    GLOBAL = true

    def deploy_succeeded?
      names_accepted_status == "True"
    end

    def deploy_failed?
      names_accepted_status == "False"
    end

    def timeout_message
      "The names this CRD is attempting to register were neither accepted nor rejected in time"
    end

    def status
      if !exists?
        super
      elsif deploy_succeeded?
        "Names accepted"
      else
        "#{names_accepted_condition['reason']} (#{names_accepted_condition['message']})"
      end
    end

    def group_version_kind
      group = @definition.dig("spec", "group")
      version = @definition.dig("spec", "version")
      "#{group}/#{version}/#{kind}"
    end

    def kind
      @definition.dig("spec", "names", "kind")
    end

    def prunable?
      prunable = @definition.dig("metadata", "annotations", "kubernetes-deploy.shopify.io/prunable")
      prunable == "true"
    end

    def timeout_for_children
      @definition.dig("metadata", "annotations", CHILD_CR_TIMEOUT_ANNOTATION)&.to_i
    end

    def monitor_rollouts?
      @definition.dig("metadata", "annotations", MONITOR_ROLLOUT_ANNOTATION) == "true"
    end

    private

    def names_accepted_condition
      conditions = @instance_data.dig("status", "conditions") || []
      conditions.detect { |c| c["type"] == "NamesAccepted" } || {}
    end

    def names_accepted_status
      names_accepted_condition["status"]
    end
  end
end
