Rails.application.config.middleware.use OmniAuth::Builder do
  provider :discord, ENV['DISCORD_CLIENT_ID'], ENV['DISCORD_CLIENT_SECRET'],
    scope: 'identify email',
    callback_path: '/users/auth/discord/callback'
end

OmniAuth.config.allowed_request_methods = [:post, :get]