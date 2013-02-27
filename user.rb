require "pstore"

USER_STORE = PStore.new("users.pstore")
USER_STORE.ultra_safe = true

class User
  attr_accessor :app_token, :uid, :nickname, :oauth_token, :oauth_secret

  def initialize (auth)
    @app_token = SecureRandom.hex
    @uid = auth.uid
    @nickname = auth.info.nickname
    @oauth_token = auth.credentials.token
    @oauth_secret = auth.credentials.secret

    create_or_update
  end

  def create_or_update
    USER_STORE.transaction do
      USER_STORE[@app_token] = self
    end
  end

  def self.find_by_app_token(app_token, read_only=true)
    USER_STORE.transaction(read_only) do
      USER_STORE.fetch(app_token)
    end
  end

end


