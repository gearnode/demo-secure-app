require 'sinatra/base'
require 'webrick'
require 'webrick/https'
require 'openssl'

# Rack::Utils.escape_html(text)

# DemoApp is the sinatra application.
class DemoApp < Sinatra::Base
  get '/' do
    erb(:index)
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
