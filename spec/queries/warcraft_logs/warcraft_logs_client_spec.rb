require 'rails_helper'

RSpec.describe WarcraftLogsClient, type: :model do
  let(:client) { described_class.new }
  
  before do
    # Keep existing environment variables (don't override with test values)
    # ENV['WARCRAFTLOGS_CLIENT_ID'] and ENV['WARCRAFTLOGS_CLIENT_SECRET'] 
    # should be loaded from .env file via dotenv-rails
  end

  describe '#initialize' do
    it 'initializes with environment credentials' do
      expect(client.instance_variable_get(:@client_id)).to eq(ENV['WARCRAFTLOGS_CLIENT_ID'])
      expect(client.instance_variable_get(:@client_secret)).to eq(ENV['WARCRAFTLOGS_CLIENT_SECRET'])
      expect(client.access_token).to be_nil
    end
  end

  describe '#authenticate_client_credentials!', :vcr do
    context 'with valid credentials' do
      it 'successfully authenticates and sets access token' do
        VCR.use_cassette('warcraft_logs/warcraft_logs_client/authenticate_success') do
          result = client.authenticate_client_credentials!
          expect(result).to be true
          expect(client.access_token).not_to be_nil
        end
      end
    end

    context 'with invalid credentials' do
      it 'raises an authentication error' do
        # Create a client with invalid credentials
        invalid_client = described_class.new
        invalid_client.instance_variable_set(:@client_id, 'invalid_id')
        invalid_client.instance_variable_set(:@client_secret, 'invalid_secret')
        
        VCR.use_cassette('warcraft_logs/warcraft_logs_client/authenticate_failure') do
          expect { invalid_client.authenticate_client_credentials! }.to raise_error(/Authentication failed/)
        end
      end
    end
  end

  describe '#public_query', :vcr do
    let(:test_query) do
      <<~GRAPHQL
        query {
          userData {
            currentUser {
              id
              name
            }
          }
        }
      GRAPHQL
    end

    context 'when authenticated' do
      it 'executes a GraphQL query successfully' do
        VCR.use_cassette('warcraft_logs/warcraft_logs_client/authenticate_and_query_success') do
          client.authenticate_client_credentials!
          result = client.public_query(test_query)
          expect(result).to be_a(Hash)
        end
      end

      it 'handles GraphQL errors' do
        invalid_query = "query { invalidField }"
        
        VCR.use_cassette('warcraft_logs/warcraft_logs_client/authenticate_and_query_error') do
          client.authenticate_client_credentials!
          expect { client.public_query(invalid_query) }.to raise_error(/GraphQL errors/)
        end
      end
    end

    context 'when not authenticated' do
      it 'raises an error when trying to query without authentication' do
        expect { client.public_query(test_query) }.to raise_error(/Not authenticated/)
      end
    end

    context 'with query variables' do
      let(:query_with_variables) do
        <<~GRAPHQL
          query($limit: Int!) {
            reportData {
              reports(limit: $limit) {
                data {
                  code
                  title
                }
              }
            }
          }
        GRAPHQL
      end

      it 'passes variables correctly' do
        VCR.use_cassette('warcraft_logs/warcraft_logs_client/authenticate_and_query_with_variables') do
          client.authenticate_client_credentials!
          result = client.public_query(query_with_variables, { limit: 5 })
          expect(result).to be_a(Hash)
        end
      end
    end
  end

  describe 'error handling' do
    context 'when API request fails' do
      it 'raises an API request error' do
        VCR.use_cassette('warcraft_logs/warcraft_logs_client/api_request_failure') do
          allow(Net::HTTP).to receive(:new).and_raise(StandardError.new("Network error"))
          expect { client.authenticate_client_credentials! }.to raise_error(StandardError, "Network error")
        end
      end
    end
  end
end
