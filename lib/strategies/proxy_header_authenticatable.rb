# Authenticates a request that an upstream reverse proxy has already vetted.
# The proxy is trusted to strip any client-supplied copy of these headers and
# set its own.
module Strategies
  class ProxyHeaderAuthenticatable < Devise::Strategies::Authenticatable
    USER_ID_HEADER = "HTTP_X_PROXY_USER_ID"
    EMAIL_HEADER   = "HTTP_X_PROXY_USER_EMAIL"

    # The proxy identifies the upstream user with an opaque UUID.
    UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

    def valid?
      UUID_FORMAT.match?(user_id)
    end

    def authenticate!
      user = User.find_or_initialize_by(email: request.get_header(EMAIL_HEADER))
      user.password = SecureRandom.hex(16) if user.new_record?
      user.save! if user.changed?

      success!(user)
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    def store?
      false
    end

    private

    def user_id
      request.get_header(USER_ID_HEADER)
    end
  end
end
