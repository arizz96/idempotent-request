module IdempotentRequest
  class Policy
    attr_reader :request

    def initialize(request)
      @request = request
    end

    def should?
      route = Rails.application.routes.recognize_path(request.path, method: request.request_method)
      Rails.application.config.idempotent_routes.any? do |idempotent_route|
        idempotent_route[:controller] == route[:controller].to_sym &&
          idempotent_route[:action] == route[:action].to_sym
      end
    end
  end
end
