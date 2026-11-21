# frozen_string_literal: true

# How an agent gets access, in the place agents look for it (auth.md). The
# answer here is that there is nothing to get: no account, no key, no token.
# Saying so in a file beats leaving an agent to probe for a sign up flow.
class AuthController < ApplicationController
  # The document only changes with a deploy.
  CACHE_MAX_AGE = 1.hour

  def show
    expires_in CACHE_MAX_AGE, public: true
    @contact_email = OpenapiDocument.load("v2").contact_email

    respond_to do |format|
      format.md
    end
  end
end
