# frozen_string_literal: true

require "trestle/active_storage/field"

Trestle.configure do |config|
  # == Customization Options
  #
  # Set the page title shown in the main header within the admin.
  #
  config.site_title = "dogapi.dog"

  # Specify a custom image to be used in place of the site title for mobile and
  # expanded/desktop navigation. These images should be placed within your
  # asset paths, e.g. app/assets/images.
  #
  # config.site_logo = "logo.png"

  # Specify a custom image to be used for the collapsed/tablet navigation.
  #
  # config.site_logo_small = "logo-small.png"

  # Specify a favicon to be used within the admin.
  #
  # config.favicon = "favicon.ico"

  # Set the text shown in the page footer within the admin.
  # Defaults to 'Powered by Trestle'.
  #
  # config.footer = "Powered by Trestle"

  # Sets the default precision for timestamps (either :minutes or :seconds).
  # Defaults to :minutes.
  #
  # config.timestamp_precision = :minutes

  # == Mounting Options
  #
  # Set the path at which to mount the Trestle admin. Defaults to /admin.
  #
  # config.path = "/admin"

  # Toggle whether Trestle should automatically mount the admin within your
  # Rails application's routes. Defaults to true.
  #
  # config.automount = false

  # == Navigation Options
  #
  # Set the path to consider the application root (for title links and breadcrumbs).
  # Defaults to the same value as `config.path`.
  #
  # config.root = "/"

  # Set the initial breadcrumbs to display in the breadcrumb trail.
  # Defaults to a breadcrumb labeled 'Home' linking to to the application root.
  #
  # config.root_breadcrumbs = -> { [Trestle::Breadcrumb.new("Home", Trestle.config.root)] }

  # Set the default icon class to use when it is not explicitly provided.
  # Defaults to "fa fa-arrow-circle-o-right".
  #
  # config.default_navigation_icon = "fa fa-arrow-circle-o-right"

  # Add an explicit menu block to be added to the admin navigation.
  #
  # config.menu do
  #   group "Custom Group" do
  #     item "Custom Link", "/admin/custom", icon: "fa fa-car", badge: { text: "NEW!", class: "label-success" }, priority: :first
  #   end
  # end

  # == Extension Options
  #
  # Specify helper modules to expose to the admin.
  #
  # config.helper :all
  # config.helper -> { CustomHelper }

  # Register callbacks to run before, after or around all Trestle actions.
  #
  # config.before_action do |controller|
  #   Rails.logger.debug("Before action")
  # end
  #
  # config.after_action do |controller|
  #   Rails.logger.debug("After action")
  # end
  #
  # config.around_action do |controller, block|
  #   Rails.logger.debug("Around action (before)")
  #   block.call
  #   Rails.logger.debug("Around action (after)")
  # end

  # Specify a custom hook to be injected into the admin.
  #
  # config.hook(:stylesheets) do
  #   stylesheet_link_tag "custom"
  # end

  # Toggle whether Turbolinks is enabled within the admin.
  # Defaults to true if Turbolinks is available.
  #
  # config.turbolinks = false

  # Specify the parameters that should persist across requests when
  # paginating or reordering. Defaults to [:sort, :order, :scope].
  #
  # config.persistent_params << :query

  # List of methods to try calling on an instance when displayed by the `display` helper.
  # Defaults to [:display_name, :full_name, :name, :title, :username, :login, :email].
  #
  # config.display_methods.unshift(:admin_label)

  # Customize the default adapter class used by all admin resources.
  # See the documentation on Trestle::Adapters::Adapter for details on
  # the adapter methods that can be customized.
  #
  # config.default_adapter = Trestle::Adapters.compose(Trestle::Adapters::SequelAdapter)
  # config.default_adapter.include MyAdapterExtensions

  # Register a form field type to be made available to the Trestle form builder.
  # Field types should conform to the following method definition:
  #
  # class CustomFormField
  #   def initialize(builder, template, name, options={}, &block); end
  #   def render; end
  # end
  #
  # config.form_field :custom, -> { CustomFormField }

  # == Debugging Options
  #
  # Enable debugging of form errors. Defaults to true in development mode.
  #
  # config.debug_form_errors = true

  # == Authentication Options
  #
  # Specify the user class to be used by trestle-auth.
  #
  config.auth.user_class = -> { User }

  # Specify the scope for valid admin users.
  # Defaults to config.auth.user_class (unscoped).
  #
  # config.auth.user_scope = -> { User.where(admin: true) }

  # Specify the Trestle admin for managing the current user (My Account).
  #
  config.auth.user_admin = -> { :"auth/account" }

  # Specify the parameter (along with a password) to be used to
  # authenticate an administrator. Defaults to :email.
  #
  config.auth.authenticate_with = :username

  # Customize the method for authenticating a user given login parameters.
  # The block should return an instance of the auth user class, or nil.
  #
  config.auth.authenticate = lambda { |params|
    User.authenticate(params[:username], params[:password])
  }

  # Customize the method for finding a user given an ID from the session.
  # The block should return an instance of the auth user class, or nil.
  #
  # config.auth.find_user = ->(id) {
  #   User.find_by(id: id)
  # }

  # Customize the rendering of user avatars. Can be disabled by setting to false.
  # Defaults to the Gravatar based on the user's email address.
  #
  config.auth.avatar = false

  # Customize the rendering of the current user's name in the main header.
  # Defaults to the user's #first_name and #last_name (last name in bold),
  # with a fallback to `display(user)` if those methods aren't defined.
  #
  config.auth.format_user_name = lambda { |user|
    content_tag(:strong, user.username)
  }

  # Customize the method for determining the user's locale.
  # Defaults to user.locale (if the method is defined).
  #
  # config.auth.locale = ->(user) {
  #   user.locale if user.respond_to?(:locale)
  # }

  # Customize the method for determining the user's time zone.
  # Defaults to user.time_zone (if the method is defined).
  #
  # config.auth.time_zone = ->(user) {
  #   user.time_zone if user.respond_to?(:time_zone)
  # }

  # Specify the redirect location after a successful login.
  # Defaults to the main Trestle admin path.
  #
  # config.auth.redirect_on_login = -> {
  #   if admin = Trestle.lookup(Trestle.config.auth.user_admin)
  #     admin.instance_path(current_user)
  #   else
  #     Trestle.config.path
  #   end
  # }

  # Specify the redirect location after logging out.
  # Defaults to the trestle-auth new login path.
  #
  # config.auth.redirect_on_logout = -> { "/" }

  # Enable or disable the built-in login/logout form and actions. Defaults to true.
  # You may wish to disable these if you are using a custom backend and
  # handling authentication entirely within your main application.
  #
  # config.auth.enable_login = true
  # config.auth.enable_logout = true

  # Specify the logo used on the login form.
  # If not specified, will fall back to config.site_logo,
  # config.site_logo_small or config.site_title.
  #
  # config.auth.logo = "auth-logo.png"

  # Enable or disable remember me functionality. Defaults to true.
  #
  # config.auth.remember.enabled = false

  # Specify remember me expiration time. Defaults to 2 weeks.
  #
  # config.auth.remember.for = 30.days

  # Customize the method for authenticating a user given a remember token.
  #
  # config.auth.remember.authenticate = ->(token) {
  #   User.authenticate_with_remember_token(token)
  # }

  # Customize the method for remembering a user.
  #
  # config.auth.remember.remember_me = ->(user) { user.remember_me! }

  # Customize the method for forgetting a user.
  #
  # config.auth.remember.forget_me = ->(user) { user.forget_me! }

  # Customize the method for generating the remember cookie.
  #
  # config.auth.remember.cookie = ->(user) {
  #   { value: user.remember_token, expires: user.remember_token_expires_at }
  # }
end
