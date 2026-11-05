#===============================================================================
# En debug, cada choque de Kaia queda apuntado en debug_choques.txt (carpeta del
# juego): mapa, casilla, hacia donde iba y la casilla que no la dejo pasar. Sirve
# para revisar el paso de los mapas despues de jugar. Un choque por casilla.
#===============================================================================
class Game_Player
  alias_method :_ost_choque_bump, :bump_into_object unless method_defined?(:_ost_choque_bump)
  def bump_into_object
    if $DEBUG
      begin
        dx = { 4 => -1, 6 => 1 }[direction] || 0
        dy = { 2 => 1, 8 => -1 }[direction] || 0
        clave = [$game_map.map_id, x, y, direction]
        @ost_choques ||= {}
        if !@ost_choques[clave]
          @ost_choques[clave] = true
          tiles = (0..2).map { |l| $game_map.data[x + dx, y + dy, l] rescue nil }
          File.open("debug_choques.txt", "a") do |f|
            f.puts("#{Time.now.strftime('%H:%M:%S')} mapa #{$game_map.map_id} kaia (#{x},#{y}) hacia #{direction} " \
                   "bloquea (#{x + dx},#{y + dy}) tiles #{tiles.inspect}")
          end
        end
      rescue Exception
      end
    end
    _ost_choque_bump
  end
end
