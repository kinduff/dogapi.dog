# frozen_string_literal: true

require "webmock/rspec"

# Nothing in the suite is allowed to reach the network. Image importer specs
# stub Commons and the file downloads explicitly.
WebMock.disable_net_connect!(allow_localhost: true)
