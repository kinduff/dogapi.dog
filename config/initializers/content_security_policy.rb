# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy

analytics_host = "https://good.lasagna.pizza"

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.frame_ancestors :none
    policy.font_src :self, :data
    # Third party badges (Product Hunt) and the inline SVG favicon.
    policy.img_src :self, :data, :https
    # Everything but analytics is served from this app.
    policy.script_src :self, analytics_host
    # `unsafe_inline` covers the few inline `style` attributes left in the
    # views. Nonces do not apply to attributes, so there is no stricter option
    # here today.
    policy.style_src :self, :unsafe_inline
    # The demo and docs pages call this API, Umami posts events back.
    policy.connect_src :self, analytics_host
  end

  # Inline `<script>` blocks are allowed through a per-request nonce.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
