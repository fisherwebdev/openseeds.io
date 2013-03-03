# -*- encoding: utf-8 -*-
require "pry" # A better console.  On the command line, after navigating to this directory, do this: pry -r ./app.rb

require "rack/cors"
# require "sinatra/cross_origin"
require "cgi"
require "json"
require "./user" # Simple, persistent storage of OAuth codes with PStore.  Use a database instead if you need to scale.
require "./twitter_auth_redirect" # Simple storage of redirection URLs, per user nickname.
require "bundler"

Bundler.setup(:default)
Bundler.require

#configure do
#  enable :cross_origin
#end
#set :allow_origin, :any
#set :allow_methods, [:get, :post, :options]
#set :allow_credentials, true
#set :allow_headers, ["*", "Content-Type", "Accept", "AUTHORIZATION", "Cache-Control", "Origin", "X-Requested-With"]
#set :max_age, "1728000"

enable :sessions
set :session_secret, 'a8hksfoonneppaldfoqoirbxiciiikefRrRRjdjha22uawwowdudethisishellasecret'

disable :protection # very dangerous!

set :port, 3000

# totally open for CORS
use Rack::Cors do |config|
  config.allow do |allow|
    allow.origins '*'
    allow.resource '*',
      :methods => [:get, :post, :put, :delete, :options],
      :headers => :any

  end
end

TWITTER_CONSUMER_KEY = "rzDUv21waQGsPYAZgPAMg"
TWITTER_CONSUMER_SECRET = "1NLfK3ig0co40iBOx7riopoUichOVXSxWhOCsFGlZc"

use OmniAuth::Builder do
  use TwitterAuthRedirect # custom middleware to store the post-auth redirect address
  provider :twitter, TWITTER_CONSUMER_KEY, TWITTER_CONSUMER_SECRET
end

Twitter.configure do |config|
  config.consumer_key = TWITTER_CONSUMER_KEY
  config.consumer_secret = TWITTER_CONSUMER_SECRET
end



################## routes #####################

before /^(?!\/($|auth.+))/ do  # all except the root and auth routes
  if !session[:secret]
    halt 403, {error: 'invalid session data'}.to_json
  end
end



get "/" do
  erb :index
end

get "/auth/twitter/callback" do
  auth = request.env["omniauth.auth"]
  user = User.new(auth)
  session[:secret] = user.app_token
  redirection = Redirect.find_by_nickname(CGI.escape(user.nickname))
  redirect CGI.unescape(redirection.url)
end

get "/auth/failure" do
  erb :auth_failure
end

get '/auth/twitter/deauthorized' do
  erb "twitter has deauthorized this app."
end







# params:
#
# :since_id (Integer) — Returns results with an ID greater than (that is, more recent than) the specified ID.
# :max_id (Integer) — Returns results with an ID less than (that is, older than) or equal to the specified ID.
# :count (Integer) — Specifies the number of records to retrieve. Must be less than or equal to 200.
# :trim_user (Boolean, String, Integer) — Each tweet returned in a timeline will include a user object with only the author's numerical ID when set to true, 't' or 1.
# :exclude_replies (Boolean, String, Integer) — This parameter will prevent replies from appearing in the returned timeline. Using exclude_replies with the count parameter will mean you will receive up-to count tweets - this is because the count parameter retrieves that many tweets before filtering out retweets and replies.
# :include_rts (Boolean, String, Integer) — Specifies that the timeline should include native retweets in addition to regular tweets. Note: If you're using the trim_user parameter in conjunction with include_rts, the retweets will no longer contain a full user object.
# :contributor_details (Boolean, String, Integer) — Specifies that the contributors element should be enhanced to include the screen_name of the contributor.
# :include_entities (Boolean, String, Integer) — The tweet entities node will be disincluded when set to false.
# :type (String) - this is a custom param to denote the twitter timeline type
get "/tweets" do

  app_token = session[:secret]

  params.delete_if { |key, value| %w(captures splat).include? key } # delete extraneous params
  symb_params = params.reduce({}) do |memo,(k,v)| # symbolize keys
    memo[k.to_sym] = v
    memo
  end

  begin
    user = User.find_by_app_token(app_token)
    client = Twitter::Client.new(
        oauth_token: user.oauth_token,
        oauth_token_secret: user.oauth_secret
    )
    type = params.delete('type') || 'home'

    raise "invalid timeline type" unless %(home mentions user).include? type
    data = client.send("#{type}_timeline", symb_params)

    tweets = data.map do |tweet|
      tweet.attrs
    end
    tweets.to_json

  rescue Exception => error
    $stderr << "\n#{error.class} => #{error.message}\n"
    $stderr << "\n"
    $stderr << error.backtrace.join("\n") << "\n"
    $stderr << "\n"
    status 500
    {error: error.class.name}.to_json
  end
end

get "/tweets/new" do
  app_token = session[:secret]
  begin
    user = User.find_by_app_token(app_token)
    @nickname = user.nickname
  rescue Exception => error
    @nickname = "Error!"
  end
  erb :tweet
end

post "/tweets" do
  app_token = session[:secret]
  begin
    user = User.find_by_app_token(app_token)
    client = Twitter::Client.new(
        oauth_token: user.oauth_token,
        oauth_token_secret: user.oauth_secret
    )
    Thread.new { client.update(params[:text ]) }
    content_type :json
    {foo: "bar"}.to_json
  rescue Exception => error
    $stderr << "#{error.class} => #{error.message}\n"
    $stderr << error.backtrace.join("\n") << "\n"
  end
end




get "/users/:nickname" do |nickname|
  app_token = session[:secret]

  begin
    user = User.find_by_app_token(app_token)
    client = Twitter::Client.new(
        oauth_token: user.oauth_token,
        oauth_token_secret: user.oauth_secret
    )

    client.user(nickname == "me" ? user.nickname : nickname).attrs.to_json

  rescue Exception => error
    $stderr << "\n#{error.class} => #{error.message}\n"
    $stderr << "\n"
    $stderr << error.backtrace.join("\n") << "\n"
    $stderr << "\n"
    status 500
    {error: error.class.name}.to_json
  end
end
