module IdempotentRequest
  class Middleware
    def initialize(app, config = {})
      @app = app
      @config = config
      @policy = config.fetch(:policy)
    end

    def call(env)
      @request = Request.new(env, config)
      debug_process
    end

    def debug_process
      begin
        process
      rescue => e
        log_rails("Rescue IdempotencyError: #{e.message} #{e.backtrace} #{request.env}")
        storage.unlock
        raise e
      end
    end

    def process
      return app.call(request.env) unless process?
      read_idempotent_request ||
        write_idempotent_request ||
        concurrent_request_response
    end

    private

    def storage
      @storage ||= RequestManager.new(request, config)
    end

    def read_idempotent_request
      storage.read
    end

    def write_idempotent_request
      return unless storage.lock(request.env)
      begin
        result = app.call(request.env)
        storage.write(*result)
      ensure
        storage.unlock
        result
      end
    end

    def concurrent_request_response
      status = 429
      headers = { 'Content-Type' => 'application/json' }
      body = [ Oj.dump('error' => 'Concurrent requests detected') ]
      Rack::Response.new(body, status, headers).finish
    end

    attr_reader :app, :env, :config, :request, :policy

    def process?
      !request.key.to_s.empty? && should_be_idempotent?
    end

    def should_be_idempotent?
      return false unless policy
      policy.new(request).should?
    end

    def log_rails(message)
      return unless defined?(Rails)
      Rails.logger.info message
    end
  end
end
