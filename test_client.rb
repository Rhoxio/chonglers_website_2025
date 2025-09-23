require_relative 'config/environment'

puts "ENV CLIENT_ID: #{ENV['WARCRAFTLOGS_CLIENT_ID']}"
puts "ENV CLIENT_SECRET: #{ENV['WARCRAFTLOGS_CLIENT_SECRET']}"

client = WarcraftLogsClient.new
puts "Client created"
puts "Client client_id: #{client.instance_variable_get(:@client_id)}"
puts "Client client_secret: #{client.instance_variable_get(:@client_secret)}"

# Try to authenticate
begin
  client.authenticate_client_credentials!
  puts "Authentication successful!"
  puts "Access token: #{client.access_token[0..20]}..."
rescue => e
  puts "Authentication failed: #{e.message}"
end
