require 'spec_helper'

describe Rack::RedisThrottle::Daily do

  # middleware settings
  before { app.options[:max]   = 5000 }
  before { app.options[:cache] = ConnectionPool.new { MockRedis.new } }

  let(:cache)      { app.options[:cache] }

  let(:time_key)   { Time.now.utc.strftime('%Y-%m-%d') }
  let(:client_key) { '127.0.0.1' }
  let(:cache_key)  { "#{client_key}:#{time_key}" }

  let(:tomorrow_time_key)  { Time.now.tomorrow.utc.strftime('%Y-%m-%d') }
  let(:tomorrow_cache_key) { "#{client_key}:#{tomorrow_time_key}" }

  before { cache.with { |c| c.set cache_key, 1 } }
  before { cache.with { |c| c.set tomorrow_cache_key, 1 } }

  describe 'when makes a request' do

    describe 'with the Authorization header' do

      describe 'when the rate limit is not reached' do

        before { get '/foo' }

        it 'returns a 200 status' do
          expect(last_response.status).to eq(200)
        end

        it 'returns the requests limit headers' do
          expect(last_response.headers['X-RateLimit-Limit']).not_to be_nil
        end

        it 'returns the remaining requests header' do
          expect(last_response.headers['X-RateLimit-Remaining']).not_to be_nil
        end

        it 'decreases the available requests' do
          previous = last_response.headers['X-RateLimit-Remaining'].to_i
          get '/', {}, 'AUTHORIZATION' => 'Bearer <token>'
          expect(previous).to eq(last_response.headers['X-RateLimit-Remaining'].to_i + 1)
        end
      end

      describe 'when reaches the rate limit' do

        before { cache.with { |c| c.set cache_key, 5000 } }
        before { get '/foo' }

        it 'returns a 403 status' do
          expect(last_response.status).to eq(403)
        end

        it 'returns a rate limited exceeded body' do
          expect(last_response.body).to eq('403 Forbidden (Rate Limit Exceeded)')
        end

        describe 'when comes the new day' do

          # If we are the 12-12-07 (any time) it gives the 12-12-08 00:00:00 UTC
          let!(:tomorrow) { Time.now.utc.tomorrow.beginning_of_day }
          before { Time.now.utc }
          before { Timecop.travel(tomorrow) }
          before { Time.now.utc }
          before { get '/foo', {}, 'AUTHORIZATION' => 'Bearer <token>' }
          after  { Timecop.return }

          it 'returns a 200 status' do
            expect(last_response.status).to eq(200)
          end

          it 'returns a new rate limit' do
          end
        end
      end
    end
  end
end
