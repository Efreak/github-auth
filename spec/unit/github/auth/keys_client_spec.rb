require 'spec_helper'
require 'github/auth/key'
require 'github/auth/keys_client'

describe GitHub::Auth::KeysClient do
  subject { described_class.new username: username }

  let(:username) { 'chrishunt' }
  let(:http_client) { double('HttpClient', get: response) }
  let(:response_code) { 200 }
  let(:body) { [] }
  let(:response) {
    double('Faraday::Response', {
      status: response_code,
      body: JSON.generate(body)
    })
  }

  before { allow(subject).to receive(:http_client).and_return(http_client) }

  describe '#initialize' do
    it 'requires a username' do
      expect {
        described_class.new
      }.to raise_error GitHub::Auth::KeysClient::UsernameRequiredError

      expect {
        described_class.new username: nil
      }.to raise_error GitHub::Auth::KeysClient::UsernameRequiredError
    end

    it 'saves the username' do
      keys_client = described_class.new username: username
      expect(keys_client.username).to eq username
    end

    it 'url escapes the username' do
      keys_client = described_class.new username: 'spaces are !o.k.'
      expect(keys_client.username).to eq 'spaces+are+%21o.k.'
    end
  end

  describe '#keys' do
    it 'requests keys from the GitHub API' do
      expect(http_client).to receive(:get).with(
        "https://api.github.com/users/#{username}/keys",
        { headers: { 'User-Agent' => "github_auth-#{GitHub::Auth::VERSION}" } }
      )
      subject.keys
    end

    it 'memoizes the response' do
      expect(http_client).to receive(:get).once
      2.times { subject.keys }
    end

    context 'when the github user has keys' do
      let(:body) {[
        { 'id' => 123, 'key' => 'abc123' },
        { 'id' => 456, 'key' => 'def456' }
      ]}

      it 'returns the keys' do
        expected_keys = body.map do |entry|
          GitHub::Auth::Key.new username, entry.fetch('key')
        end

        expect(subject.keys).to eq expected_keys
      end
    end

    context 'when the github user does not have keys' do
      let(:body) { [] }

      it 'returns an empty array' do
        expect(subject.keys).to eq []
      end
    end

    context 'when the github user does not exist' do
      let(:response_code) { 404 }

      it 'raises GitHubUserDoesNotExistError' do
        expect {
          subject.keys
        }.to raise_error GitHub::Auth::KeysClient::GitHubUserDoesNotExistError
      end
    end

    context 'when there is an issue connecting to GitHub' do
      before do
        expect(http_client)
          .to receive(:get)
          .and_raise Faraday::Error::ConnectionFailed.new('Oops!')
      end

      it 'raises a GitHubUnavailableError' do
        expect {
          subject.keys
        }.to raise_error GitHub::Auth::KeysClient::GitHubUnavailableError
      end
    end
  end
end
