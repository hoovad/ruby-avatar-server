# frozen_string_literal: true

require 'sinatra'
require 'faraday'
require 'json'
require 'fileutils'

set :port, 100
set :bind, '0.0.0.0'

# you need to set both of these
# the user ID of the discord user whose avatar you want to fetch
USER_ID = ''
# a valid authorization token to access the Discord API is required
AUTHORIZATION_HEADER = ''

USER_ENDPOINT = "https://discord.com/api/v10/users/#{USER_ID}"
AVATAR_BASE_URL = "https://cdn.discordapp.com/avatars/#{USER_ID}"
CACHE_FILE = "cached_image.png"
CACHE_TTL = 600 # 10m

def cache_fresh?
  File.exist?(CACHE_FILE) && (Time.now - File.mtime(CACHE_FILE)) < CACHE_TTL
end

def fetch_user
  response = Faraday.get(USER_ENDPOINT) do |req|
    req.headers['Authorization'] = AUTHORIZATION_HEADER
    req.headers['User-Agent'] = 'AvatarFetcher/1.0'
  end
  halt 502, "Could not fetch user info" unless response.status == 200
  JSON.parse(response.body)
end

def fetch_avatar
  user_json = fetch_user
  avatar_hash = user_json["avatar"]
  avatar_url = "#{AVATAR_BASE_URL}/#{avatar_hash}.png?size=128"
  resp = Faraday.get(avatar_url)
  halt 502, "Could not fetch avatar image" unless resp.status == 200
  File.write(CACHE_FILE, resp.body, mode: "wb")
  resp.body
end

get '/' do
  image_data =
    if cache_fresh?
      File.read(CACHE_FILE, mode: "rb")
    else
      fetch_avatar
    end
  content_type 'image/png'
  headers 'Cache-Control' => "public, max-age=#{CACHE_TTL}"
  body image_data
end
