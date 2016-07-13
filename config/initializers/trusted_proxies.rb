# Override Rack::Request to make use of the same list of trusted_proxies
# as the ActionDispatch::Request object. This is necessary for libraries
# like rack_attack where they don't use ActionDispatch, and we want them
# to block/throttle requests on private networks.
# Rack Attack specific issue: https://github.com/kickstarter/rack-attack/issues/145 
module Rack
  class Request
    def trusted_proxy?(ip)
      Rails.application.config.action_dispatch.trusted_proxies.any? { |proxy| proxy === ip }
    end
  end
end

Rails.application.config.action_dispatch.trusted_proxies = (
  [ '127.0.0.1', '::1' ] + Array(Gitlab.config.gitlab.trusted_proxies)
).map { |proxy| IPAddr.new(proxy) }
