module IdempotentRequest
  class Middleware
    def initialize(app, config = {})
      @app = app
      @config = config
      @policy = config.fetch(:policy)
      @notifier = ActiveSupport::Notifications if defined?(ActiveSupport::Notifications)
    end

    def call(env)
      dup.debug_process(env)
    end

    def debug_process(env)
      begin
        process(env)
      rescue => e
        log_rails("Rescue IdempotencyError: #{e.message} #{e.backtrace} #{request.env}")
        storage.unlock
        raise e
      end
    end

    def process(env)
      set_request(env)
      request.request.env['idempotent.request'] = {}
      return app.call(request.env) unless process?
      request.env['idempotent.request']['key'] = request.key
      response = read_idempotent_request || write_idempotent_request || concurrent_request_response
      instrument(request.request)
      response
    end

    private

    def storage
      @storage ||= RequestManager.new(request, config)
    end

    def read_idempotent_request
      request.env['idempotent.request']['read'] ||= storage.read
    end

    def write_idempotent_request
      return unless storage.lock(request.env)
      begin
        result = app.call(request.env)
        request.env['idempotent.request']['write'] = result
        storage.write(*result)
      ensure
        request.env['idempotent.request']['unlocked'] = [storage.unlock, storage.send(:key)]
        result
      end
    end

    def concurrent_request_response
      status = 429
      headers = { 'Content-Type' => 'application/json' }
      body = [ Oj.dump('error' => 'Concurrent requests detected') ]
      request.env['idempotent.request']['concurrent_request_response'] = true
      Rack::Response.new(body, status, headers).finish
    end

    attr_reader :app, :env, :config, :request, :policy, :notifier

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

    def instrument(request)
      notifier.instrument('idempotent.request', request: request) if notifier
    end

    def set_request(env)
      @env = env
      @request = Request.new(env, config)
    end
  end
end
