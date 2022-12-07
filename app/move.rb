OPPOSITE_DIRECTIONS = {
  "right" => "left",
  "left" => "right",
  "up" => "down",
  "down" => "up"
}
MAZE_RUNNER = 0
PATH_FINDING = 1
LONGEST_SNAKE = 2
WARRIOR = 9

# This function is called on every turn of a game. It's how your Battlesnake decides where to move.
# Valid moves are "up", "down", "left", or "right".
# TODO: Use the information in board to decide your next move.
def move(params)
  # puts params
  # env[Rack::RACK_REQUEST_FORM_INPUT] # original params
  # env[Rack::RACK_REQUEST_FORM_HASH] # json parsed params
  # puts env[Rack::RACK_REQUEST_FORM_INPUT]

  possible_moves = [
    { command: "right", x: params[:you][:head][:x] + 1, y: params[:you][:head][:y] },
    { command: "left",  x: params[:you][:head][:x] - 1, y: params[:you][:head][:y] },
    { command: "up",    x: params[:you][:head][:x], y: params[:you][:head][:y] + 1 },
    { command: "down",  x: params[:you][:head][:x], y: params[:you][:head][:y] - 1 }
  ]
  previous_position_x, previous_position_y = params[:you][:shout].split(",")
  ruleset = params[:game][:ruleset][:name]
  ruleset_food_spawn_chance = params[:game][:ruleset][:settings][:food_spawn_chance]
  ruleset_minimum_food = params[:game][:ruleset][:settings][:minimum_food]

  if ruleset == "wrapped"
    behaviour_mode = MAZE_RUNNER
  elsif ruleset == "solo" && (ruleset_food_spawn_chance > 0 || ruleset_minimum_food > 0)
    behaviour_mode = PATH_FINDING
  else
    behaviour_mode = WARRIOR
  end

  possible_moves.reject! do |possible_move|
    # Do not move outside board
    (ruleset == "wrapped" && (possible_move[:x] < 0 || possible_move[:x] >= params[:board][:width] || possible_move[:y] < 0 || possible_move[:y] >= params[:board][:height])) ||
    # Do not move onto another snake
    params[:board][:snakes].find { |snake| snake[:body].include?({x: possible_move[:x], y: possible_move[:y]}) } ||
    # Do not move onto hazards
    params[:board][:hazards].include?({x: possible_move[:x], y: possible_move[:y]}) ||
    # Do not move into opposite direction of previous direction
    (possible_move[:x] == previous_position_x && possible_move[:y] == previous_position_y)
  end

  foods = params[:board][:food]

  # Sort possible moves by closest food
  possible_moves.each do |possible_move|
    foods_with_distances = foods.map do |food|
      food[:distance] = location_distance(possible_move[:x], possible_move[:y], food[:x], food[:y])
      food
    end

    possible_move[:closest_food_distance] = foods_with_distances.map { |food| food[:distance] }.sort.first || 0
  end

  move = {}

  if possible_moves.size > 0
    if behaviour_mode == LONGEST_SNAKE
      move = possible_moves.first
    elsif behaviour_mode == MAZE_RUNNER
      move = possible_moves.shuffle.first
    elsif behaviour_mode == PATH_FINDING

      if(params[:board][:food].size > 0)
        matrix = build_matrix(params[:board][:width], params[:board][:height])
        matrix = block_locations(matrix, params[:board][:hazards])
        matrix = block_locations(matrix, params[:board][:snakes].map { |s| s[:body] })
        matrix = open_locations(matrix, [{x: params[:you][:head][:x], y: params[:you][:head][:y]}])

        # Reverse the rows in the matrix as the Y-axis is different
        grid = Grid.new(matrix.reverse)
        start_node = grid.node(params[:you][:head][:x], params[:board][:height] - params[:you][:head][:y] - 1)
        end_node = grid.node(foods.first[:x], params[:board][:height] - foods.first[:y] - 1)
        # Do A* path finding
        finder = AStarFinder.new()
        path = finder.find_path(start_node, end_node, grid)
        puts grid.to_s(path, start_node, end_node)

        if path
          # there is a path to the food
          path_next = path[1]
          move = possible_moves.find { |possible_move| possible_move[:x] == path_next.x && possible_move[:y] == (params[:board][:height] - path_next.y - 1) }
        else
          # no path to the food
          move = possible_moves.sort_by { |move| move[:closest_food_distance] }.first
        end
      end

    elsif behaviour_mode == WARRIOR
      move = possible_moves.sort_by { |move| move[:closest_food_distance] }.first
    end
    # if params[:board][:food].size > 0
    #   # move towards the food, as the closest is the first
    #   move = possible_moves.first
    # else # move to a random possible move
    #   move = possible_moves.shuffle.first
    # end

  else possible_moves.size == 0
    # we're fucked
    move = [{ command: "up" }, { command: "down" }, { command: "left" }, { command: "right" }].sample
  end

  puts "=> #{move[:command].upcase}"
  { "move" => move[:command], "shout" => "#{move[:x]},#{move[:y]}" }
end


def location_distance(x1, y1, x2, y2)
  return 0 if x1.nil? || y1.nil? || x2.nil? || y2.nil?
  diff_x = (x1 - x2).abs
  diff_y = (y1 - y2).abs
  diff_x + diff_y
end

def build_matrix(width, height)
  Array.new(height) { Array.new(width) { 0 } }
end

def block_locations(matrix, locations, value = 1)
  set_locations(matrix, locations, value)
end

def open_locations(matrix, locations)
  set_locations(matrix, locations, 0)
end

def set_locations(matrix, locations, value)
  locations.flatten.each do |location|
    matrix[location[:y]][location[:x]] = value
  end
  matrix
end


