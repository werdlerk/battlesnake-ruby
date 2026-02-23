OPPOSITE_DIRECTIONS = {
  'right' => 'left',
  'left' => 'right',
  'up' => 'down',
  'down' => 'up'
}
MAZE_RUNNER = 0
PATH_FINDING = 1
LONGEST_SNAKE = 2
WARRIOR = 9

# This function is called on every turn of a game. It's how your Battlesnake decides where to move.
# Valid moves are "up", "down", "left", or "right".
# TODO: Use the information in board to decide your next move.
def move(params)
  possible_moves = [
    { command: 'right', x: params[:you][:head][:x] + 1, y: params[:you][:head][:y] },
    { command: 'down', x: params[:you][:head][:x], y: params[:you][:head][:y] - 1 },
    { command: 'left', x: params[:you][:head][:x] - 1, y: params[:you][:head][:y] },
    { command: 'up', x: params[:you][:head][:x], y: params[:you][:head][:y] + 1 }
  ]
  previous_command, previous_position_x, previous_position_y = params[:you][:shout].split(',')
  ruleset = params[:game][:ruleset][:name]
  ruleset_food_spawn_chance = params[:game][:ruleset][:settings][:food_spawn_chance]
  ruleset_minimum_food = params[:game][:ruleset][:settings][:minimum_food]

  behaviour_mode = if ruleset == 'wrapped'
                     MAZE_RUNNER
                   elsif ruleset == 'solo' && (ruleset_food_spawn_chance > 0 || ruleset_minimum_food > 0)
                     if params[:board][:hazards].length > 0
                       PATH_FINDING
                     else
                       LONGEST_SNAKE
                     end
                   else
                     # behaviour_mode = WARRIOR
                     PATH_FINDING
                   end

  my_body_length = params[:you][:body].length

  possible_moves.reject! do |possible_move|
    # Do not move outside board
    (ruleset != 'wrapped' && (possible_move[:x] < 0 || possible_move[:x] >= params[:board][:width] || possible_move[:y] < 0 || possible_move[:y] >= params[:board][:height])) ||
      # Do not move onto hazards
      params[:board][:hazards].include?({ x: possible_move[:x], y: possible_move[:y] }) ||
      # Do not move into opposite direction or previous direction
      (possible_move[:x] == previous_position_x && possible_move[:y] == previous_position_y) ||
      # Do not move onto another snake's body (except opponent head when we are longer or equal)
      params[:board][:snakes].any? { |snake| snake[:body][0...-1].include?({ x: possible_move[:x], y: possible_move[:y] }) } ||
      begin
        opponent = params[:board][:snakes].find do |snake|
          next false if snake[:id] == params[:you][:id]

          head = snake[:body].first
          opponent_possible_heads = [
            { x: head[:x] + 1, y: head[:y] },
            { x: head[:x] - 1, y: head[:y] },
            { x: head[:x], y: head[:y] + 1 },
            { x: head[:x], y: head[:y] - 1 }
          ]
          opponent_possible_heads.any? { |pos| pos[:x] == possible_move[:x] && pos[:y] == possible_move[:y] }
        end

        # Allow head-to-head if we are longer or equal (we win or tie)
        opponent && opponent[:body].length >= my_body_length
      end
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
      # repeat last move
      move_order = %w[up right down left]
      previous_command = move_order.first if previous_command.nil?
      move = possible_moves.find { |pm| pm[:command] == previous_command }
      while move.nil? && possible_moves.size > 0
        next_move_order = move_order[move_order.index(previous_command) + 1] || move_order.first
        move = possible_moves.find { |pm| pm[:command] == next_move_order }
      end
    elsif behaviour_mode == MAZE_RUNNER
      move = possible_moves.sample
    elsif behaviour_mode == PATH_FINDING

      if params[:board][:food].size > 0
        matrix = build_matrix(params[:board][:width], params[:board][:height])
        matrix = block_locations(matrix, params[:board][:hazards])
        matrix = block_locations(matrix, params[:board][:snakes].map { |s| s[:body] })
        matrix = open_locations(matrix, [{ x: params[:you][:head][:x], y: params[:you][:head][:y] }])

        # Reverse the rows in the matrix as the Y-axis is different
        grid = Grid.new(matrix.reverse)
        start_node = grid.node(params[:you][:head][:x], params[:board][:height] - params[:you][:head][:y] - 1)

        # closest food
        closest_foods_to_me = foods.map do |food|
          food[:distance] = location_distance(params[:you][:head][:x], params[:you][:head][:y], food[:x], food[:y])
          food
        end
        closest_food_to_me = closest_foods_to_me.sort_by { |food| food[:distance] }.first
        end_node = grid.node(closest_food_to_me[:x], params[:board][:height] - closest_food_to_me[:y] - 1)

        # end_node = grid.node(foods.first[:x], params[:board][:height] - foods.first[:y] - 1)

        # Do A* path finding
        finder = AStarFinder.new
        path = finder.find_path(start_node, end_node, grid)
        # puts grid.to_s(path, start_node, end_node)

        if path
          # there is a path to the food
          path_next = path[1]
          move = possible_moves.find do |possible_move|
            possible_move[:x] == path_next.x && possible_move[:y] == (params[:board][:height] - path_next.y - 1)
          end
        end

        if !path || !move
          # no path to the food or no possible move on path to food
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

  else
    possible_moves.size
    puts "we're fucked"
    move = [{ command: 'up' }, { command: 'down' }, { command: 'left' }, { command: 'right' }].sample
  end

  puts "=> #{move[:command].upcase}"
  { 'move' => move[:command], 'shout' => "#{move[:command]},#{move[:x]},#{move[:y]}" }
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
