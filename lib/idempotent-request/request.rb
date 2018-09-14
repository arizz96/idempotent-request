module IdempotentRequest
  class Request
    attr_reader :request

    def initialize(env, config = {})
      @request = Rack::Request.new(env)
      @header_name = config.fetch(:header_key, 'HTTP_IDEMPOTENCY_KEY')
    end

    def key
      @key ||= request.env[header_name] || request.env['HTTP_X_AMZN_TRACE_ID'] || SecureRandom.uuid
    end

    def method_missing(method, *args)
      if request.respond_to?(method)
        request.send(method, *args)
      else
        super
      end
    end

    private

    def header_name
      key = @header_name.to_s
                        .upcase
                        .tr('-', '_')

      key.start_with?('HTTP_') ? key : "HTTP_#{key}"
    end
  end
end
