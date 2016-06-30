#!/usr/bin/env rackup
#
# This is a basic HTTP server, conforming to the authentication protocol
#  required by Nginx's mail module.
#
# Author: Dimitri Aivaliotis
# Date: 2012
#
require 'logger'
require 'rack'

module MailAuth

  # setup a protocol-to-port mapping
  Port = {
    'smtp' => '25',
    'pop3' => '110',
    'imap' => '143'
  }

  class Handler

    def initialize
      # setup logging, as a mail service
      @log = Logger.new("| logger -p mail.info")
      # replacing the normal timestamp by the service name and pid
      @log.datetime_format = "nginx_mail_proxy_auth pid: "
      # the "Auth-Server" header must be an IP address
      @mailhost = '127.0.0.1'
      # set a maximum number of login attempts
      @max_attempts = 3
      # our authentication 'database' will just be a fixed hash for this example
      # it should be replaced by a method to connect to LDAP or a database
      @auths = { "test:1234" => '127.0.1.1' }
    end

    def call(env)
      # our headers are contained in the environment
      @env = env
      # set up the request and response objects
      @req = Rack::Request.new(env)
      @res = Rack::Response.new
      # pass control to the method named after the HTTP verb
      #  with which we're called
      self.send(@req.request_method.downcase)
      # come back here to finish the response when done
      @res.finish
    end

    def get
      # the authentication mechanism
      meth = @env['HTTP_AUTH_METHOD']
      # the username (login)
      user = @env['HTTP_AUTH_USER']
      # the password, either in the clear or encrypted, depending on the
      #  authentication mechanism used
      pass = @env['HTTP_AUTH_PASS']
      # need the salt to encrypt the cleartext password, used for some
      #  authenticatin mechanisms, not in our example
      salt = @env['HTTP_AUTH_SALT']
      # this is the protocol being proxied
      proto = @env['HTTP_AUTH_PROTOCOL']
      # the number of attempts needs to be an integer
      attempt = @env['HTTP_AUTH_LOGIN_ATTEMPT'].to_i
      # not used in our implementation, but these are here for reference
      client = @env['HTTP_CLIENT_IP']
      host = @env['HTTP_CLIENT_HOST']

      # fail if more than the maximum login attempts are tried
      if attempt > @max_attempts
        @res["Auth-Status"] = "Maximum login attempts exceeded"
        return
      end

      # for the special case where no authentication is done
      #  on smtp transactions, the following is in nginx.conf:
      #     smtp_auth   none;
      # may want to setup a lookup table to steer certain senders
      #  to particular SMTP servers
      if meth == 'none' && proto == 'smtp'
        helo = @env['HTTP_AUTH_SMTP_HELO']
        # want to get just the address from these two here
        from = @env['HTTP_AUTH_SMTP_FROM'].split(/: /)[1]
        to = @env['HTTP_AUTH_SMTP_TO'].split(/: /)[1]
        @res["Auth-Status"] = "OK"
        @res["Auth-Server"] = @mailhost
        # return the correct port for this protocol
        @res["Auth-Port"] = MailAuth::Port[proto]
        @log.info("a mail from #{from} on #{helo} for #{to}")
      # try to authenticate using the headers provided
      elsif auth(user, pass)
        @res["Auth-Status"] = "OK"
        @res["Auth-Server"] = @mailhost
        # return the correct port for this protocol
        @res["Auth-Port"] = MailAuth::Port[proto]
        # if we're using APOP, we need to return the password in cleartext
        if meth == 'apop' && proto == 'pop3'
          @res["Auth-User"] = user
          @res["Auth-Pass"] = pass
        end
        @log.info("+ #{user} from #{client}")
      # the authentication attempt has failed
      else
        # if authentication was unsuccessful, we return an appropriate response
        @res["Auth-Status"] = "Invalid login or password"
        # and set the wait time in seconds before the client may make another
        #  authentication attempt
        @res["Auth-Wait"] = "3"
        # we can also set the error code to be returned to the SMTP client
        @res["Auth-Error-Code"] = "535 5.7.8"
        @log.info("! #{user} from #{client}")
      end

    end

    private

    # our authentication method, adapt to fit your environment
    def auth(user, pass)
      # this simply returns the value looked-up by the 'user:pass' key
      if @auths.key?("#{user}:#{pass}")
        @mailhost = @auths["#{user}:#{pass}"]
        return @mailhost
      #  if there is no such key, the method returns false
      else
        return false
      end
    end

    # just in case some other process tries to access the service
    #  and sends something other than a GET
    def method_missing(env)
      @res.status = 404
    end

  end # class MailAuthHandler
end # module MailAuth

# setup Rack middleware
use Rack::ShowStatus
# map the /auth URI to our authentication handler
map "/auth" do
  run MailAuth::Handler.new
end
