#===============================================================================
# Pokemon Ostinato - Las escaleras del vestibulo del teatro (mapa 13)
#
#   Los dos tramos en diagonal se bajan y suben con las escaleras laterales de
#   la base (eventos "Slope" del mapa). Ese sistema solo arranca desde la casilla
#   del pie, (6,27) y (23,27). Para que se pueda subir llegando por la fila de
#   arriba o la de abajo, desde esas casillas Kaia da un paso en diagonal hasta
#   el pie y sigue subiendo si mantiene la direccion.
#===============================================================================
module OstEscalerasTeatro
  MAPA = 13
  # [x, y, direccion pulsada] => [dx, dy] hasta el pie de la escalera
  ATAJOS = {
    [7, 26, 4]  => [-1, 1], [7, 28, 4]  => [-1, -1],   # escalera izquierda
    [22, 26, 6] => [1, 1],  [22, 28, 6] => [1, -1]     # escalera derecha
  }
end

class Game_Player
  alias ostesc_move_generic move_generic
  def move_generic(dir, turn_enabled = true)
    if $game_map && $game_map.map_id == OstEscalerasTeatro::MAPA && !on_stair?
      paso = OstEscalerasTeatro::ATAJOS[[@x, @y, dir]]
      if paso && !moving?
        turn_generic(dir, true) if turn_enabled
        @move_initial_x = @x
        @move_initial_y = @y
        @x += paso[0]
        @y += paso[1]
        @move_timer = 0.0
        increase_steps
        return
      end
    end
    ostesc_move_generic(dir, turn_enabled)
  end
end
