# frozen_string_literal: true
require 'pry'
require 'jsonpath'
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
      return super unless rollout_params

      rollout_params[:success_queries]&.all? do |query|
        jsonpath_query(path: query[:path]) == query[:value]
      end
    end

    def deploy_failed?
      return super unless rollout_params

      rollout_params[:failure_queries].any? do |query|
        jsonpath_query(path: query[:path]) == query[:value]
      end
    end

    def failure_message
      messages = rollout_params[:failure_queries].map do |query|
        jsonpath_query(path: query[:error_msg_path]) if query[:error_msg_path]
      end.compact
      messages.present? ? messages.join("\n") : "error deploying #{id}"
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

    def rollout_params
      @rollout_params ||= @crd.rollout_params
    end

    def jsonpath_query(path:)
      JsonPath.new(path).first(@instance_data)
    rescue StandardError
      raise FatalDeploymentError, "fatal error for #{id}. Failed to parse JsonPath for #{path}"
    end
  end
end
