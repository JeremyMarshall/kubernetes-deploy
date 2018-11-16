# frozen_string_literal: true
require 'pry'
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
        condition("Ready")["status"] == "True"
      else
        super
      end
    end

    def deploy_failed?
      if monitor_rollout?
        condition("Failed")["status"] == "True"
      else
        super
      end
    end

    def failure_message
      condition("Failed")["message"] || "unknown error deploying #{id}"
    end

    def id
      "#{kind}/#{name}"
    end

    def type
      kind
    end

    private

    def condition(type)
      @instance_data&.dig("status", "Conditions")&.find do |cond|
        cond["type"] == type
      end || {}
    end

    def kind
      @definition["kind"]
    end

    def monitor_rollout?
      @crd.monitor_rollouts?
    end
  end
end
