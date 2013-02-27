require "pstore"

REDIRECT_STORE = PStore.new("redirects.pstore")
REDIRECT_STORE.ultra_safe = true



class Redirect
  attr_accessor :nickname, :url

  def initialize (params)
    @nickname = params['screen_name']
    @url = params['url'] || "http://localhost:3000/tweet"
    create_or_update
  end

  def create_or_update
    REDIRECT_STORE.transaction do
      REDIRECT_STORE[@nickname] = self
    end
  end

  def self.find_by_nickname(nickname, read_only=true)
    REDIRECT_STORE.transaction(read_only) do
      REDIRECT_STORE.fetch(nickname)
    end
  end

end



class TwitterAuthRedirect
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"] == "/auth/twitter"
      request = Rack::Request.new(env)
      Redirect.new(request.params)
    end
    @app.call(env)
  end
end