# WarcraftLogsClient - Simple OAuth 2.0 client for Warcraft Logs API
class WarcraftLogsClient
  require 'net/http'
  require 'json'
  require 'uri'
  require 'securerandom'
  require 'base64'
  require 'digest'
  require 'httparty'
  
  BASE_URL = 'https://www.warcraftlogs.com'
  TOKEN_URI = "#{BASE_URL}/oauth/token"
  AUTHORIZE_URI = "#{BASE_URL}/oauth/authorize"
  API_URI = "#{BASE_URL}/api/v2/client"
  USER_API_URI = "#{BASE_URL}/api/v2/user"
  
  attr_reader :access_token
  
  def initialize
    @client_id = ENV['WARCRAFTLOGS_CLIENT_ID']
    @client_secret = ENV['WARCRAFTLOGS_CLIENT_SECRET']
    @access_token = nil
  end
  
  # Authenticate and get access token
  def authenticate_client_credentials!
    uri = URI(TOKEN_URI)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request.basic_auth(@client_id, @client_secret)
    request.set_form_data('grant_type' => 'client_credentials')

    response = http.request(request)
    
    if response.code == '200'
      token_data = JSON.parse(response.body)
      @access_token = token_data['access_token']
      true
    else
      raise "Authentication failed: #{response.body}"
    end
  end
  
  # Authorization Code Flow - for user private data access
  def get_authorization_url(redirect_uri, state = nil)
    state ||= SecureRandom.hex(16)
    params = {
      client_id: @client_id,
      response_type: 'code',
      redirect_uri: redirect_uri,
      state: state
    }
    
    "#{AUTHORIZE_URI}?#{params.to_query}"
  end
  
  def exchange_authorization_code(code, redirect_uri)
    response = HTTParty.post(
      TOKEN_URI,
      basic_auth: { username: @client_id, password: @client_secret },
      body: {
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: redirect_uri
      }
    )
    
    if response.success?
      data = response.parsed_response
      @access_token = data['access_token']
      @refresh_token = data['refresh_token']
      @expires_at = Time.now + data['expires_in'].seconds
      true
    else
      raise WarcraftLogsError.new("Authorization code exchange failed: #{response.body}")
    end
  end
  
  # PKCE Code Flow - for browser-based applications
  def get_pkce_authorization_url(redirect_uri, state = nil)
    @code_verifier = generate_code_verifier
    @code_challenge = generate_code_challenge(@code_verifier)
    state ||= SecureRandom.hex(16)
    
    params = {
      client_id: @client_id,
      response_type: 'code',
      redirect_uri: redirect_uri,
      code_challenge: @code_challenge,
      code_challenge_method: 'S256',
      state: state
    }
    
    "#{AUTHORIZE_URI}?#{params.to_query}"
  end
  
  def exchange_pkce_code(code, redirect_uri)
    response = HTTParty.post(
      TOKEN_URI,
      body: {
        client_id: @client_id,
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: redirect_uri,
        code_verifier: @code_verifier
      }
    )
    
    if response.success?
      data = response.parsed_response
      @access_token = data['access_token']
      @refresh_token = data['refresh_token']
      @expires_at = Time.now + data['expires_in'].seconds
      true
    else
      raise WarcraftLogsError.new("PKCE code exchange failed: #{response.body}")
    end
  end
  
  # Make a GraphQL query
  def public_query(query, variables = {})
    raise "Not authenticated" unless @access_token
    
    uri = URI(API_URI)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@access_token}"
    request['Content-Type'] = 'application/json'
    request.body = {
      query: query,
      variables: variables
    }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      if data['errors']
        raise "GraphQL errors: #{data['errors'].map { |e| e['message'] }.join(', ')}"
      end
      data['data']
    else
      raise "API request failed: #{response.body}"
    end
  end
  
  # User API calls (requires user authorization)
  def user_query(query, variables = {})
    ensure_authenticated!
    
    response = HTTParty.post(
      USER_API_URI,
      headers: {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json'
      },
      body: {
        query: query,
        variables: variables
      }.to_json
    )
    
    handle_response(response)
  end
  
  # Convenience methods for common queries
  
  # Get guild information
  def get_guild(name, server, region = 'US')
    query = <<~GRAPHQL
      query($name: String!, $server: String!, $region: String!) {
        guildData {
          guild(name: $name, serverSlug: $server, serverRegion: $region) {
            id
            name
            server {
              name
              slug
              region {
                name
                slug
              }
            }
            members {
              data {
                id
                name
                classID
                level
                guildRank
              }
            }
          }
        }
      }
    GRAPHQL
    
    public_query(query, { name: name, server: server, region: region })
  end
  
  # Get character information
  def get_character(name, server, region = 'US')
    query = <<~GRAPHQL
      query($name: String!, $server: String!, $region: String!) {
        characterData {
          character(name: $name, serverSlug: $server, serverRegion: $region) {
            id
            name
            classID
            level
            server {
              name
              slug
              region {
                name
                slug
              }
            }
            guildRank
            recentReports {
              data {
                id
                title
                startTime
                endTime
                zone {
                  name
                }
              }
            }
          }
        }
      }
    GRAPHQL
    
    public_query(query, { name: name, server: server, region: region })
  end
  
  # Get recent reports for a guild
  def get_guild_reports(name, server, region = 'US', limit = 10)
    query = <<~GRAPHQL
      query($name: String!, $server: String!, $region: String!, $limit: Int!) {
        guildData {
          guild(name: $name, serverSlug: $server, serverRegion: $region) {
            recentReports(limit: $limit) {
              data {
                id
                title
                startTime
                endTime
                zone {
                  name
                }
                fights {
                  encounterID
                  name
                  difficulty
                  kill
                  startTime
                  endTime
                }
              }
            }
          }
        }
      }
    GRAPHQL
    
    public_query(query, { name: name, server: server, region: region, limit: limit })
  end
  
  # Get user's private reports (requires user authorization)
  def get_user_reports(limit = 20)
    query = <<~GRAPHQL
      query($limit: Int!) {
        userData {
          reports(limit: $limit) {
            data {
              id
              title
              startTime
              endTime
              zone {
                name
              }
              fights {
                encounterID
                name
                difficulty
                kill
                startTime
                endTime
              }
            }
          }
        }
      }
    GRAPHQL
    
    user_query(query, { limit: limit })
  end
  
  # Get encounter rankings for a character
  def get_character_rankings(name, server, region = 'US', encounter_id = nil)
    query = <<~GRAPHQL
      query($name: String!, $server: String!, $region: String!, $encounterID: Int) {
        characterData {
          character(name: $name, serverSlug: $server, serverRegion: $region) {
            encounterRankings(encounterID: $encounterID) {
              data {
                encounter {
                  id
                  name
                }
                difficulty
                metric
                rank
                outOf
                percentile
                report {
                  id
                  title
                  startTime
                }
              }
            }
          }
        }
      }
    GRAPHQL
    
    public_query(query, { 
      name: name, 
      server: server, 
      region: region, 
      encounterID: encounter_id 
    })
  end
  
  private
  
  def ensure_authenticated!
    raise WarcraftLogsError.new("No access token available") unless @access_token
    raise WarcraftLogsError.new("Access token expired") if token_expired?
  end
  
  def token_expired?
    @expires_at && Time.now >= @expires_at
  end
  
  def handle_response(response)
    if response.success?
      data = response.parsed_response
      if data['errors']
        raise WarcraftLogsError.new("GraphQL errors: #{data['errors'].map { |e| e['message'] }.join(', ')}")
      end
      data['data']
    else
      raise WarcraftLogsError.new("API request failed: #{response.body}")
    end
  end
  
  def generate_code_verifier
    SecureRandom.urlsafe_base64(96).tr('=', '')
  end
  
  def generate_code_challenge(verifier)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier))
    challenge.tr('=', '')
  end
end

# Custom error class for Warcraft Logs API errors
class WarcraftLogsError < StandardError
end
