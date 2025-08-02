# frozen_string_literal: true

require 'sinatra'
require 'faraday'
require 'json'
require 'fileutils'

# user-defined settings

# the port it will listen on
set :port, 100
# the address it will bind to
set :bind, '0.0.0.0'
# [REQUIRED] the user ID of the discord user whose avatar you want to fetch
USER_ID = ''
# [REQUIRED] an authorization token is required to access the Discord API
AUTHORIZATION_HEADER = ''
# the file where the avatar will be cached
CACHE_FILE = 'cached_image.png'
# how many seconds the cache is valid for
CACHE_TTL = 600 # 10m
# if the cache is enabled (recommended to not get rate-limited by Discord)
CACHE_ENABLED = true
# the filetype of the image returned
# this can be 'png', 'jpeg', 'webp'*, or 'gif'**
# * webp's can be returned as animated images if supported by setting RETURN_WEBP_ANIMATED to true
# ** gifs are only available in certain cases, set the fallback filetype by setting FALLBACK_FILETYPE
FILETYPE = 'png'
RETURN_WEBP_ANIMATED = false
FALLBACK_FILETYPE = 'png'
# the size of the image returned, for example, if you set it to 128 it  will return a 128x128 image
# it can be any power of 2 from 16 to 4096
IMAGE_SIZE = 128

# don't change these
USER_ENDPOINT = "https://discord.com/api/v10/users/#{USER_ID}"
AVATAR_BASE_URL = "https://cdn.discordapp.com/avatars/#{USER_ID}"

unless USER_ID.is_a?(String) && !USER_ID.empty?
  raise ArgumentError("Invalid USER_ID: #{USER_ID}. Must be a non-empty string formed of numbers.")
end

unless AUTHORIZATION_HEADER.is_a?(String) && !AUTHORIZATION_HEADER.empty?
  raise ArgumentError("Invalid AUTHORIZATION_HEADER: #{AUTHORIZATION_HEADER}. Must be a non-empty string formed of " \
                      "a valid Discord API authorization header.")
end

unless CACHE_FILE.is_a?(String) && !CACHE_FILE.empty?
  raise ArgumentError("Invalid CACHE_FILE: #{CACHE_FILE}. Must be a non-empty string representing a valid file path.")
end

unless CACHE_TTL.is_a?(Integer) && CACHE_TTL > 0
  raise ArgumentError("Invalid CACHE_TTL: #{CACHE_TTL}. Must be a non-zero positive integer representing seconds.")
end

unless [true, false].include?(CACHE_ENABLED)
  raise ArgumentError("Invalid CACHE_ENABLED: #{CACHE_ENABLED}. Must be a boolean.")
end

unless %w[png jpeg webp gif].contains?(FILETYPE)
  raise ArgumentError("Invalid FILETYPE: #{FILETYPE}. Must be one of 'png', 'jpeg', 'webp', or 'gif'.")
end

unless [true, false].include?(RETURN_WEBP_ANIMATED)
  raise ArgumentError("Invalid RETURN_WEBP_ANIMATED: #{RETURN_WEBP_ANIMATED}. Must be a boolean.")
end

unless %w[png jpeg webp].contains?(FALLBACK_FILETYPE)
  raise ArgumentError("Invalid FALLBACK_FILETYPE: #{FALLBACK_FILETYPE}. Must be one of 'png', 'jpeg' or 'webp'")
end

unless IMAGE_SIZE.is_a?(Integer) && IMAGE_SIZE >= 16 && IMAGE_SIZE <= 4096 &&
       (IMAGE_SIZE > 0 && (IMAGE_SIZE & (IMAGE_SIZE -1)) == 0)
  raise ArgumentError("Invalid IMAGE_SIZE: #{IMAGE_SIZE}. Must be an integer that is a power of 2 between 16 and 4096.")
end

def handle_query_strings(query_string_hash)
  query_string_array = []
  query_string_hash.each do |key, value|
    if value.nil?
      next
    elsif query_string_array.empty?
      query_string_array << "?#{key}=#{value}"
    else
      query_string_array << "&#{key}=#{value}"
    end
  end
  query_string_array << '' if query_string_array.empty?
  query_string_array.join
end

def cache_fresh?
  File.exist?(CACHE_FILE) && (Time.now - File.mtime(CACHE_FILE)) < CACHE_TTL
end

def fetch_user
  response = Faraday.get(USER_ENDPOINT) do |req|
    req.headers['Authorization'] = AUTHORIZATION_HEADER
    req.headers['User-Agent'] = 'AvatarServer/1.0'
  end
  halt 502, 'Failed to fetch user' unless response.status == 200
  JSON.parse(response.body)
end

def fetch_avatar
  user = fetch_user
  avatar_hash = user['avatar']
  query_string_hash = {}
  query_string_hash[:size] = IMAGE_SIZE
  if FILETYPE == 'webp' && avatar_hash.start_with?('a_')
    query_string_hash[:animated] = RETURN_WEBP_ANIMATED
    file_type = FILETYPE
  elsif FILETYPE == 'gif' && !avatar_hash.start_with?('a_')
    file_type = FALLBACK_FILETYPE
  else
    file_type = FILETYPE
  end
  query_string = handle_query_strings(query_string_hash)
  avatar_url = "#{AVATAR_BASE_URL}/#{avatar_hash}.#{file_type}#{query_string}"
  avatar = Faraday.get(avatar_url)
  halt 502, 'Failed to fetch avatar' unless avatar.status == 200
  File.write(CACHE_FILE, avatar.body, mode: 'wb') if CACHE_ENABLED
  [avatar.body, file_type]
end

get '/' do
  avatar = if CACHE_ENABLED && cache_fresh?
             File.read(CACHE_FILE, mode: 'rb')
           else
             fetch_avatar
           end
  content_type "image/#{avatar[1]}"
  headers 'Cache-Control' => "public, max-age=#{CACHE_TTL}"
  body avatar[0]
end
