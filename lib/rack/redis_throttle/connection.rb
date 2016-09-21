require 'rack'
require 'connection_pool'

module Rack
  module RedisThrottle
    class Connection

      POOL_SIZE = 10.freeze
      TIMEOUT = 5.freeze

      def self.create(options={})
        url = redis_provider || 'redis://localhost:6379/0'
        options.reverse_merge!({ url: url, pool_size: POOL_SIZE, timeout: TIMEOUT })
        ConnectionPool.new(size: options[:pool_size], timeout: options[:timeout]) do
          client = Redis.connect(url: options[:url], driver: :hiredis)
          Redis::Namespace.new("redis-throttle:#{ENV['RACK_ENV']}:rate", redis: client)
        end
      end

      private

      def self.redis_provider
        ENV['REDIS_RATE_LIMIT_URL']
      end
    end
  end
end
