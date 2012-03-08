# Simple UDP server for aggregating counts of events and pushing them into
# Redis.
#
# Inspiration and code borrowed from
# https://github.com/quasor/statsd
# and
# https://github.com/fetep/ruby-statsd

require "eventmachine"
require "logger"
require "rubygems"
require "socket"
require 'redis'

module StatsD
  @@counters = Hash.new { |h, k| h[k] = 0 }
  @@logger = Logger.new(STDERR)
  @@logger.progname = File.basename($0)
  @@verbose = 0
  @@backend = nil

  def self.logger
    @@logger
  end

  def self.verbose=(verbose)
    @@verbose = verbose
  end

  def self.initialize_redis_backend(options)
    @@backend = RedisBackend.new(Redis.new(
      :host => options.host, :port => options.port, :db => options.db))
  end

  def receive_data(msg)
    msg.split("\n").each do |row|
      bits = row.split(':')

      if bits.size < 2
        raise "Malformed message: #{msg}" 
        next
      end

      key = bits.shift
      bits.each do |record|
        sample_rate = 1
        fields = record.split("|")

        if fields.size < 2
          @@logger.error "Malformed message: #{msg}" 
          next
        end

        if (fields[1].strip == "ms") 
          @@logger.error "Timer updates not supported"
        else
          if (fields[2] && fields[2].match(/^@([\d\.]+)/)) 
            sample_rate = fields[2].match(/^@([\d\.]+)/)[1]
          end
          @@counters[key] += (fields[0].to_i || 1) * (1.0 / sample_rate.to_f)
        end
      end
    end
  end

  def self.flush
    @@logger.info "Flushing #{@@counters.size} keys" if @@verbose >= 1
    @@backend.flush do |store|
      @@counters.each do |key, increment_by|
        super_key, sub_key = key.split('.', 2)
        if sub_key.nil?:
          sub_key = super_key
          super_key = 'c'
        end
        restored_sub_key = sub_key.gsub(/;COLON;/, ':').gsub(/;PERIOD;/, '.')
        restored_super_key = super_key.gsub(/;COLON;/, ':').gsub(/;PERIOD;/, '.')
        @@logger.info "Increment: #{restored_super_key}.#{restored_sub_key} += #{increment_by}" if @@verbose >= 2
        store.increment_by(restored_super_key, restored_sub_key, increment_by)
      end
    end

    @@counters.clear
  end
end

class RedisBackend
  def initialize(redis_client)
    @redis_client = redis_client
  end

  def retrieve_counts(group_name)
    ret = ActiveSupport::OrderedHash.new

    # The return value of zrangebyscore looks like this:
    # ["key 1", "1", "key 2", "4", "key 3", "100"]
    counts_array = @redis_client.zrangebyscore(group_name, '-inf', '+inf', :with_scores => true)
    counts_array.reverse.each_slice(2) do |pageviews, key|
      ret[key] = pageviews.to_i
    end
    ret
  end

  def flush
    @redis_client.pipelined do
      yield self
    end
  end

  def increment_by(group_name, key, increment_by)
    @redis_client.zincrby(group_name, increment_by, key)
  end
end

# In-memory backend useful for testing.
class InMemoryBackend
  def initialize
    @in_memory_hash ||= Hash.new { |h, group_name| h[group_name] = Hash.new { |h, key| h[key] = 0 } }
  end

  def retrieve_counts(group_name)
    ret = ActiveSupport::OrderedHash.new

    hash = @in_memory_hash[group_name]
    hash.keys.sort.each do |key|
      ret[key] = hash[key]
    end
    ret
  end

  def flush
    yield self
  end

  def increment_by(group_name, key, increment_by)
    @in_memory_hash[group_name][key] += increment_by
  end
end
