# Devise + Warden: first request to a cold process runs zero strategies

This is a minimal reproduction of a Devise/Warden issue on Rails 8: when
`config.eager_load` is `false`, the **first request to a newly booted server**
tries to authenticate before the strategies have been loaded and 401s. After
that, all other requests authenticate normally.

Ruby 4.0.2 - Rails 8.1.3.1 - Devise 5.0

## The app

A stock Rails app with a Devise `User` and one custom Warden strategy,
`Strategies::ProxyHeaderAuthenticatable` (`lib/strategies/`) that simulates a
proxy header authentication. It is session-less, so every request reads the
header again.

`config/initializers/devise.rb`:

```ruby
Rails.application.config.to_prepare do
  Warden::Strategies.add(:proxy_header, Strategies::ProxyHeaderAuthenticatable)
end

# ...inside Devise.setup:
config.warden do |warden_config|
  warden_config.default_strategies(scope: :user).unshift :proxy_header
end
```

`GET /` is `HomeController#index`, behind `authenticate_user!`.

## Setup

```bash
bin/setup
```

## Reproducing it

The failure happens **once per boot**, so each attempt needs a new process.

```bash
bin/rails server
```

Then, at least three times:

```bash
curl -s -o /dev/null -w "%{http_code} -> %{redirect_url}\n" \
  -H "X-Proxy-User-Id: 00000000-0000-0000-0000-000000000001" \
  -H "X-Proxy-User-Email: devise@thoughtbot.test" \
  http://localhost:3000/
```

```
request 1: 302 -> http://localhost:3000/users/sign_in   <- the bug
request 2: 200
request 3: 200
...
```

Restart the server to see it again.

For simplicity, this app is not built to be tested in a browser.

## The issue

From 8, Rails defers drawing routes until the first request unless eager loading
is on. Devise only applies its Warden configuration when routes finalize
loading. This is why the first cold request fails to authenticate.

## The workaround

In my project, this is the configuration I added to workaround this issue:

```ruby
Rails.application.config.after_initialize do |app|
  app.reload_routes! unless app.config.eager_load
end
```
