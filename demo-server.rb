require "sinatra"
require 'pocket-ruby'
require 'redis'

CALLBACK_URL = ENV.fetch('CALLBACK_URL') + "/oauth/callback"

$redis = Redis.new

Pocket.configure do |config|
  config.consumer_key = ENV.fetch('CONSUMER_KEY')
end

get "/" do
  begin
    @access_token = $redis.get('access_token')
    client = Pocket::Client.new(access_token: @access_token)
    client.retrieve(count: 1)
  rescue Pocket::Error
    puts "DEL code #{$redis.get('code')}"
    $redis.del('code')
    puts "DEL access_token #{$redis.get('access_token')}"
    $redis.del('access_token')
  end
  erb :index
end

get "/oauth/connect" do
  puts "OAUTH CONNECT"
  code = Pocket.get_code(:redirect_uri => CALLBACK_URL)
  $redis.set('code', code)
  new_url = Pocket.authorize_url(:code => code, :redirect_uri => CALLBACK_URL)
  puts "new_url: #{new_url}"
  redirect new_url
end

get "/oauth/callback" do
  puts "OAUTH CALLBACK"
  puts "request.url: #{request.url}"
  puts "request.body: #{request.body.read}"
  code = $redis.get('code')
  result = Pocket.get_result(code, :redirect_uri => CALLBACK_URL)
  access_token = result['access_token']
  $redis.set('access_token', access_token)
  puts result['access_token']
  puts result['username']
  redirect "/"
end

# get '/add' do
#   client = Pocket.client(:access_token => session[:access_token])
#   info = client.add :url => 'http://getpocket.com'
#   "<pre>#{info}</pre>"
# end
#
get "/retrieve" do
  client = Pocket.client(:access_token => $redis.get('access_token'))
  info = client.retrieve(:detailType => :complete, :count => 1)

  # html = "<h1>#{user.username}'s recent photos</h1>"
  # for media_item in client.user_recent_media
  #   html << "<img src='#{media_item.images.thumbnail.url}'>"
  # end
  # html
  "<pre>#{info}</pre>"
end
