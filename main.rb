require 'pocket-ruby'
require 'redis'
require 'net/http'
require 'uri'
require 'cgi'
require 'json'
require 'pp'

$redis = Redis.new(url: ENV.fetch('REDIS_URL'))
access_token = $redis.get('access_token')
puts "access_token=#{access_token}"

Pocket.configure do |config|
  config.consumer_key = ENV.fetch('CONSUMER_KEY')
end

client = Pocket::Client.new(access_token: access_token)
since = Integer($redis.get('since') || 0)
list = client.retrieve(since: since)['list']
puts "Retrieve #{list.count} items since #{Time.at(since)}"
list.each do |_item|
  timestamp, item = *_item
  url = item['resolved_url'] || item['given_url']
  http = Net::HTTP.new('b.hatena.ne.jp')
  req = Net::HTTP::Get.new("/entry/jsonlite/?url=#{CGI.escape(url)}", {'User-Agent' => 'curl/7.43.0'})
  res = http.request(req)
  body = res.body
  begin
    data = JSON.parse(body)
  rescue
  end
  next if data.nil?
  tags = []
  data['bookmarks'].each do |bookmark|
    tags << bookmark['tags']
  end
  tags = tags.flatten.compact
  next if tags.empty?
  tags.uniq!
  actions = [
    {
      action: 'tags_add',
      item_id: item['item_id'],
      tags: tags.join(','),
    }
  ]
  client.modify(actions)
  puts "Add tags #{tags.join(',')} to #{url}"
end
now = Time.now.to_i
$redis.set('since', now)
puts "Set since=#{Time.at(now)}"
