# frozen_string_literal: true
module KubernetesDeploy
  class CustomResource < KubernetesResource
    def initialize(namespace:, context:, definition:, logger:, statsd_tags: [], crd:)
      @crd = crd
      super(namespace: namespace, context: context, definition: definition,
            logger: logger, statsd_tags: statsd_tags)
    end

    def timeout
      timeout_override || @crd.timeout_for_children || super
    end

    def deploy_succeeded?
      if monitor_rollout?
        condition_status("Ready")
      else
        super
      end
    end

    def deploy_failed?
      if monitor_rollout?
        condition_status("Failed")
      else
        super
      end
    end

    def id
      "#{kind}/#{name}"
    end

    def type
      kind
    end

    private

    def condition_status(condition_type)
      return false unless condition = @instance_data&.dig("status", "Conditions")&.find { |cond| cond["type"] == condition_type }
      condition["status"] == "True"
    end

    def kind
      @definition["kind"]
    end

    def monitor_rollout?
      @crd.monitor_rollouts?
    end
  end
end
