module IdempotentRequest
  class Request
    attr_reader :request

    def initialize(env, config = {})
      @request     = Rack::Request.new(env)
      @header_name = sanitize_header_name(config.fetch(:header_key, nil))
      @body_name   = config.fetch(:body_key, nil)
    end

    def key
      if @header_name.present?
        request.env[@header_name.to_s]
      elsif @body_name.present? && request.env['action_dispatch.request.request_parameters'].present?
        request.env['action_dispatch.request.request_parameters'][@body_name.to_s]
      else
        nil
      end
    end

    def method_missing(method, *args)
      if request.respond_to?(method)
        request.send(method, *args)
      else
        super
      end
    end

    private

    def sanitize_header_name(string)
      if string.present?
        key = string.to_s.strip.upcase.tr('-', '_')
        key.start_with?('HTTP_') ? key : "HTTP_#{key}"
      else
        nil
      end
    end
  end
end
