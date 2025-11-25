# ruby-avatar-server

![project status: discontinued](https://img.shields.io/badge/project_status-discontinued-orange)

Simple backend that gets an up-to-date user avatar straight from Discord and serves it via HTTP.
You can see this server in action at <https://avatar.hoovad.tech>.

# Setup

You can use the server in two ways:

- You can use avatar_server.rb: (default) more customizable, but quite bloated
- You can use simple_avatar_server.rb: less customizable, but much smaller, it gets a 128x128 png file from Discord, you can change this manually, but avatar_server.rb has much of the customization logic and proper handling done, so if you want to change this it's recommended to use avatar_server.rb

By default the server will bind to 0.0.0.0 and listen on port 100, it's designed to be served via a reverse proxy.

If you want to use simple_avatar_server.rb instead, you need to change 'config.ru' and change the line `require_relative 'avatar_server'` to `require_relative 'simple_avatar_server'`.

In order for the server to work properly, you need to open the code of the server (`avatar_server.rb` or `simple_avatar_server.rb`) and change 2 variables: `USER_ID` (the Discord user ID to get the avatar of) and `AUTHORIZATION_HEADER` (a valid authorization header to authenticate to the Discord API, see <https://discord.com/developers/docs/reference#authentication>), the rest of the options are optional to change and they are explained with a comment above them.

## Reverse proxy

ruby-avatar-server is designed to be used with nginx + Phusion Passenger. In order to use Passenger inside nginx you need to compile nginx with the Passenger module, see [the installation guide](https://www.phusionpassenger.com/docs/tutorials/deploy_to_production/installations/oss/ownserver/ruby/nginx/).

Example nginx config (please note that this isn't a full nginx configuration file, just a snippet, you still need to do your own setup as well):
```
server {
    listen 80;
    server_name example.com; # CHANGE THIS
    root /where/the/avatar/server/is/located; # CHANGE THIS TO WHERE THE FILES TO THE SERVER ARE LOCATED
    passenger_enabled on;
        
    location / {
        try_files $uri @passenger;
    }

    location @passenger {
        passenger_enabled on;
        passenger_app_root /where/the/avatar/server/is/located; # CHANGE THIS TO WHERE THE FILES TO THE SERVER ARE LOCATED
    }
}

```

By putting this simple config in your nginx config file, it serves the avatar via HTTP on port 80, and nginx will automatically start the server for you (because we use Phusion Passenger).

With this configuration, if you go to http://[your domain here]/ it should return the avatar of the user you specified in the code.