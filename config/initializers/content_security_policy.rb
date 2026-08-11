# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy

cdn_host = "https://cdnjs.cloudflare.com"
stimulus_host = "https://unpkg.com"
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
    # Swagger UI and Prism are loaded from a CDN, Stimulus from unpkg,
    # analytics from the Umami instance.
    policy.script_src :self, cdn_host, stimulus_host, analytics_host
    # `unsafe_inline` is needed for the inline `style` attributes in the views
    # and the styles Swagger UI injects at runtime. Nonces do not cover
    # attributes, so there is no stricter option here today.
    policy.style_src :self, :unsafe_inline, cdn_host
    # The demo page calls the public API, Umami posts events back.
    policy.connect_src :self, "https://dogapi.dog", analytics_host
  end

  # Inline `<script>` blocks are allowed through a per-request nonce.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
