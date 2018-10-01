# demo-secure-app
Demo of secure application built with sinatra

## Requirements

- [mkcert](https://github.com/FiloSottile/mkcert/blob/master/README.md)
- [ruby](https://www.ruby-lang.org/en/)
- [bundler](https://bundler.io/)

## Install

Generate TLS certificate:
```
mkcert myapp.dev
```

Add myapp.dev to your `/etc/hosts` file:
```
127.0.0.1 myapp.dev
```

Create configuration file:
```
cp .env.sample .env
```

Import configuration vars:
```
source .env
```

Bundle dependencies:
```
bundle install
```

Run the application:
```
ruby app.rb
```
