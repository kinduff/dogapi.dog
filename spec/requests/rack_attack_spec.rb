# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rack::Attack', type: :request do
  before do
    Rack::Attack.enabled = true
    Rack::Attack.reset!
  end

  after do
    Rack::Attack.enabled = false
  end

  describe 'GET /' do
    let(:headers) { { 'REMOTE_ADDR' => '1.2.3.4' } }

    it 'successful for 300 requests, then blocks the user nicely' do
      300.times do
        get root_path, headers: headers
        expect(response).to have_http_status(:ok)
      end

      get root_path, headers: headers
      expect(response.body).to include('Retry later')
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
