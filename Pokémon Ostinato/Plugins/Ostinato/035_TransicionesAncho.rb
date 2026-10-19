#===============================================================================
# Pokemon Ostinato - Transiciones de entrada a combate a lo ancho de la pantalla
#
#   Las de Essentials estan pensadas para 512 de ancho. En SnakeSquares (la de
#   los salvajes en exterior, la que usa tambien Pokemon Anil) los cuadrados
#   se ensanchan a la pantalla pero se colocan cada 64 px sin ensanchar: con
#   el mapa de Ostinato (mas ancho que 512) quedaba una franja de la derecha
#   sin tapar. Aqui se colocan con el mismo ensanche. En RisingSplash (agua)
#   el negro que sube no llegaba a todo el ancho.
#===============================================================================
module Transitions
  class SnakeSquares
    alias ostancho_initialize_sprites initialize_sprites
    def initialize_sprites
      ostancho_initialize_sprites
      @sprites.each do |s|
        next if !s
        s.x = (s.x * @zoom_x_target).round      # ox (medio cuadrado) ya va ensanchado con zoom_x
      end
    end
  end

  class RisingSplash
    alias ostancho_initialize_sprites initialize_sprites
    def initialize_sprites
      ostancho_initialize_sprites
      if @black_sprite && @black_bitmap && @black_bitmap.width < Graphics.width
        @black_sprite.zoom_x = Graphics.width.to_f / @black_bitmap.width
      end
    end
  end
end
