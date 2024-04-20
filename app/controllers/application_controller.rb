class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: { safari: 17.0, chrome: 119, firefox: 121, opera: 104, ie: false }
end
