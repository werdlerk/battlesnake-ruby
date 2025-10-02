require 'rack'
require 'rack/contrib'
require 'sinatra'
require './app/util'
require './app/move'

class BattleSnake < Sinatra::Base
  use Rack::JSONBodyParser

  set :host_authorization, permitted_hosts: []

  # This function is called when you register your Battlesnake on play.battlesnake.com
  # It controls your Battlesnake appearance and author permissions.
  # TIP: If you open your Battlesnake URL in browser you should see this data
  get '/' do
    appearance = {
      apiversion: "1",
      author: "koen",           # TODO: Your Battlesnake Username
      color: "#FF1122",     # TODO: Personalize
      head: "evil",      # TODO: Personalize
      tail: "flake",      # TODO: Personalize
    }

    camelcase(appearance).to_json
  end

  # This function is called everytime your snake is entered into a game.
  # rack.request.form_hash contains information about the game that's about to be played.
  # TODO: Use this function to decide how your snake is going to look on the board.
  post '/start' do
    request = underscore(env['rack.request.form_hash'])
    save_params("start", nil)

    puts "START"
    "OK\n"
  end

  # This function is called on every turn of a game. It's how your snake decides where to move.
  # Valid moves are "up", "down", "left", or "right".
  # TODO: Use the information in rack.request.form_hash to decide your next move.
  post '/move' do
    request = underscore(env['rack.request.form_hash'])

    # Implement move logic in app/move.rb
    response = move(request)
    save_params("move", response[:command])

    content_type :json
    camelcase(response).to_json
  end

  # This function is called when a game your Battlesnake was in ends.
  # It's purely for informational purposes, you don't have to make any decisions here.
  post '/end' do
    save_params("end", nil)

    puts "END"
    "OK\n"
  end
end

def save_params(method, result, extension = "json")
  params = underscore(env[Rack::RACK_REQUEST_FORM_HASH])
  raw_params = env[Rack::RACK_REQUEST_FORM_INPUT].read
  ruleset_name = params[:game][:ruleset][:name]
  map_name = params[:game][:map]
  game_id = params[:game][:id]
  turn_id = params[:turn]
  dir_name = "#{ruleset_name}_#{map_name}_#{game_id}"

  FileUtils.mkdir("runs") unless Dir.exist? "runs"
  FileUtils.mkdir(File.join("runs", dir_name)) unless Dir.exist? "./runs/#{dir_name}"
  File.open(File.join("runs", dir_name, "#{method}_#{turn_id}_#{result}.#{extension}"), "w") do |f|
    f.write raw_params
  end
end
