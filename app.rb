require 'sinatra/base'
require 'webrick'
require 'webrick/https'
require 'openssl'
require 'ostruct'
require 'pry'
require 'rack/csrf'


$store = OpenStruct.new
$store.messages = []
$store.accounts = []

# SecureHeaders is rack middleware to set HSTS header.
class StrictTransportSecurity
  def initialize(app)
    @app = app
    @header_key = 'Strict-Transport-Security'
  end

  def call(env)
    status, headers, response = @app.call(env)
    headers[@header_key] = 'max-age=31536000; includeSubdomains; preload'
    [status, headers, response]
  end
end

# ContentSecurityPolicy is rack middleware to set CSP header.
class ContentSecurityPolicy
  def initialize(app, opts = {})
    @app = app
    @header_key = 'Content-Security-Policy'
    @header_key += '-Report-Only' if opts.fetch(:report_only, false)
  end

  def call(env)
    status, headers, response = @app.call(env)
    headers[@header_key] = %(default-src 'self'; img-src *)
    headers['X-Frame-Options'] = 'none'
    [status, headers, response]
  end
end

# XFrameOptions is rack middleware to mitigate session hack.
class XFrameOptions
  def initialize(app)
    @app = app
    @header_key = 'X-Frame-Options'
  end

  def call(env)
    status, headers, response = @app.call(env)
    headers[@header_key] = 'none'
    [status, headers, response]
  end
end

# DefaultApplication is the default application configuration.
class DefaultApplication < Sinatra::Base
  set :csp_report_only, false
  set :session_cookie_secret, ENV.fetch('SESSION_COOKIE_SECRET')

  enable :logging

  # Add HTTP-Strict-Transport-Security header to minigate downgrade
  # protocol attak.
  use StrictTransportSecurity

  use XFrameOptions

  # Add Content-Security-Policy header to mitigate Stored XSS attack and
  # control what is evaluated by the browser.
  use ContentSecurityPolicy,
      report_only: settings.csp_report_only

  use Rack::Session::Cookie,
      key: 'SSID',
      domain: 'myapp.dev',
      path: '/',
      expire_after: 2_592_000, # seconds
      secret: settings.session_cookie_secret,
      httponly: true,
      secure: true

  # Add CSRF token to mitigate reflected XSS attack. This middleware
  # ensure CSRF is valid when user submit a form.
  use Rack::Csrf,
      raise: false

  not_found { erb :not_found }
end

# DemoApp is the sinatra application.
class DemoApp < DefaultApplication
  get '/' do
    erb :index, locals: {
      messages: $store.messages,
      accounts: $store.accounts
    }
  end

  post '/messages' do
    # Escape HTML before insert in the storage. This mitigate a
    # Stored XSS attack.
    msg = Rack::Utils.escape_html(params[:message])
    $store.messages << msg
    redirect('/')
  end

  post '/login' do
    account = Rack::Utils.escape_html(params[:username])

    exist = $store.accounts.find { |x| x == account }
    $store.accounts << account unless exist

    session[:username] = account

    redirect('/')
  end

  post '/logout' do
    $store.accounts.delete_if { |x| x == session[:username] }
    session[:username] = nil
    redirect('/')
  end
end

SSL_CERTIFICATE = IO.read(ENV.fetch('SSL_CERTIFICATE'))
SSL_PRIVATE_KEY = IO.read(ENV.fetch('SSL_PRIVATE_KEY'))

Rack::Handler::WEBrick.run(
  DemoApp,
  Port: ENV.fetch('PORT', '3000').to_i,
  Logger: WEBrick::Log.new($stderr, WEBrick::Log::DEBUG),
  DocumentRoot: '/ruby/htdocs',
  SSLEnable: true,
  SSLCertificate: OpenSSL::X509::Certificate.new(SSL_CERTIFICATE),
  SSLPrivateKey: OpenSSL::PKey::RSA.new(SSL_PRIVATE_KEY),
  Host: '0.0.0.0'
)
