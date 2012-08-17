rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
uri = URI.parse(redis_config[rails_env])

$redis_call_flow_connection = Redis.new(:host => uri.host, :port => uri.port)      
