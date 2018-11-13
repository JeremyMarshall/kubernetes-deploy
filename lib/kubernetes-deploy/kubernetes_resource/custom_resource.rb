# frozen_string_literal: true
module KubernetesDeploy
  class CustomResource < KubernetesResource
    def initialize(namespace:, context:, definition:, logger:, statsd_tags: [], crd:)
      @crd = crd
      super(namespace: namespace, context: context, definition: definition,
            logger: logger, statsd_tags: statsd_tags)
    end

    def sync(mediator)
      @instance_data = mediator.get_instance(kind, name, raise_if_not_found: true)
    rescue KubernetesDeploy::Kubectl::ResourceNotFoundError
      @disappeared = true if deploy_started?
      @instance_data = {}
    end

    def timeout
      timeout_override || @crd.timeout_for_children || super
    end

    def deploy_succeeded?
      if monitor_rollout?
        return false unless ready_status = @instance_data&.dig("status", "Conditions")&.find { |cond| cond["type"] == "Ready" }
        ready_status["status"] == "True"
      else
        super
      end
    end

    def deploy_failed?
      if monitor_rollout?
        return false unless failed_status = @instance_data&.dig("status", "Conditions")&.find { |cond| cond["type"] == "Failed" }
        failed_status["status"] == "True"
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

    def kind
      @definition["kind"]
    end

    def monitor_rollout?
      @crd.monitor_rollouts?
    end
  end
end
