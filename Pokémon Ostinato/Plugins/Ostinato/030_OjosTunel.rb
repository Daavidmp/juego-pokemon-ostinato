#===============================================================================
# Pokemon Ostinato - Los ojos del tunel de la ruta 4 (mapas 15 a 18)
#
#   En el tunel no hay hierba: los Pokemon salvajes son ojos que brillan en la
#   oscuridad, envueltos en una sombra de niebla. Salen de vez en cuando en
#   casillas oscuras (lejos de las lamparas: se mira en oscuro_N.png de
#   029_TunelVivo), parpadean y miran a los lados.
#   - Si Kaia se acerca a DETECTA casillas, los ojos se abren de golpe, Kaia se
#     queda quieta (como cuando te ve un entrenador) y el Pokemon va hacia ella
#     por donde se puede andar. Al llegar, nube y combate.
#   - Si nadie se acerca, al rato se apagan y salen en otro sitio.
#   Los de ojos cian (Pokemon de agua) solo salen junto al agua.
#   Arte en Graphics/Pictures/Tunel/: ojos.png (4 parejas x 4 fotogramas de
#   24x12), niebla_ojos.png y nube.png (5 fotogramas).
#===============================================================================
module OstOjos
  DIR       = "Graphics/Pictures/Tunel/"
  MAX       = 2             # ojos a la vez en un mapa
  DETECTA   = 3.5           # casillas a las que te ven
  LEJOS     = 7             # no salen a menos de estas casillas de Kaia
  OSCURO    = 170           # alfa de oscuro_N.png a partir de la que es "oscuro"
  VELOCIDAD = 4.0           # casillas por segundo cuando van a por Kaia
  VIDA      = [18, 30]      # segundos que se quedan si nadie se acerca
  ESPERA    = [4, 9]        # segundos entre una aparicion y la siguiente
  CW, CH    = 24, 12        # cuadro de una pareja de ojos en ojos.png

  # tipo de ojos (fila de ojos.png): 0 amarillos, 1 rojos, 2 lilas, 3 cian (agua)
  # [tipo, especie, nivel minimo, nivel maximo, peso]
  ESPECIES = {
    15 => [[0, :ZUBAT, 8, 10, 6], [1, :RATTATA, 8, 10, 4], [3, :TYMPOLE, 8, 10, 3]],
    16 => [[0, :ZUBAT, 8, 11, 5], [0, :WOOBAT, 9, 11, 3], [1, :RATTATA, 9, 10, 3], [1, :ZORUA, 10, 11, 1],
           [3, :WOOPER, 9, 11, 3]],
    17 => [[0, :ZUBAT, 9, 11, 4], [0, :WOOBAT, 9, 12, 3], [2, :GASTLY, 10, 12, 3], [3, :TYMPOLE, 9, 11, 3]],
    18 => [[0, :WOOBAT, 10, 12, 4], [2, :GASTLY, 10, 12, 4], [2, :SABLEYE, 11, 12, 1], [3, :WOOPER, 10, 12, 3]]
  }
  # donde hay agua (casillas x0, y0, x1, y1): solo ahi salen los de ojos cian
  AGUA = {
    15 => [[1, 15, 22, 19]],
    16 => [[1, 11, 22, 13], [1, 20, 7, 29]],
    17 => [[19, 5, 25, 21]],
    18 => [[23, 19, 32, 22]]
  }

  def self.mapa?; return $game_map && ESPECIES.key?($game_map.map_id); end
  def self.bloqueado?; return @bloqueado; end
  def self.bmp(n); return (Bitmap.new(DIR + n) rescue nil); end
  def self.ahora; return (System.uptime rescue Time.now.to_f); end

  #--- donde pueden salir -------------------------------------------------------
  # casillas oscuras por las que se anda, sin eventos; se calcula al entrar
  def self.preparar
    @mapa = $game_map.map_id
    @ojos = []
    @proxima = ahora + 3
    @oscuras = []; @agua = []
    osc = bmp("oscuro_#{@mapa}.png")
    return if !osc
    $game_map.width.times do |x|
      $game_map.height.times do |y|
        next if osc.get_pixel(x * 32 + 16, y * 32 + 16).alpha < OSCURO
        next if ![2, 4, 6, 8].any? { |d| $game_map.passable?(x, y, d) }
        next if $game_map.events.values.any? { |e| e.x == x && e.y == y }
        agua = (AGUA[@mapa] || []).any? { |a| x >= a[0] && x <= a[2] && y >= a[1] && y <= a[3] }
        (agua ? @agua : @oscuras).push([x, y])
      end
    end
    osc.dispose
  end

  # elige especie (por peso) y casilla para unos ojos nuevos
  def self.elegir(px, py, rnd = Random)
    tabla = ESPECIES[@mapa] || []
    total = tabla.sum { |t| t[4] }
    return nil if total <= 0
    r = rnd.rand(total)
    fila = tabla.find { |t| (r -= t[4]) < 0 }
    sitios = (fila[0] == 3 ? @agua : @oscuras).select do |x, y|
      (x - px).abs + (y - py).abs >= LEJOS && !(@ojos || []).any? { |o| (o[:x] - x).abs + (o[:y] - y).abs < 4 }
    end
    return nil if sitios.empty?
    x, y = sitios[rnd.rand(sitios.length)]
    return { :tipo => fila[0], :especie => fila[1], :nivel => fila[2] + rnd.rand(fila[3] - fila[2] + 1),
             :x => x.to_f, :y => y.to_f, :estado => :aparece, :t => 0,
             :vida => VIDA[0] + rnd.rand(VIDA[1] - VIDA[0] + 1), :parpadeo => 60 + rnd.rand(120), :lado => 0 }
  end

  # el camino de (x, y) hasta una casilla al lado de (px, py): lista de casillas
  def self.camino(x, y, px, py, pasable, max = 400)
    ini = [x, y]
    meta = [[px + 1, py], [px - 1, py], [px, py + 1], [px, py - 1]]
    return [] if meta.include?(ini)
    de = { ini => nil }; cola = [ini]; n = 0
    while (p = cola.shift)
      n += 1
      break if n > max
      [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]].each do |d, dx, dy|
        q = [p[0] + dx, p[1] + dy]
        next if de.key?(q) || q == [px, py] || !pasable.call(p[0], p[1], d, q[0], q[1])
        de[q] = p
        if meta.include?(q)
          lista = [q]
          lista.unshift(de[lista[0]]) while de[lista[0]] && de[lista[0]] != ini
          return lista
        end
        cola.push(q)
      end
    end
    return nil
  end

  def self.pasable_mapa
    return proc do |x, y, d, nx, ny|
      $game_map.valid?(nx, ny) && $game_map.passable?(x, y, d) && $game_map.passable?(nx, ny, 10 - d) &&
        !$game_map.events.values.any? { |e| e.x == nx && e.y == ny && !e.through && e.character_name != "" }
    end
  end

  #--- cada fotograma (desde Scene_Map) -------------------------------------------
  def self.comprobar
    if !mapa?
      soltar; @mapa = nil; @bloqueado = false
      return
    end
    preparar if @mapa != $game_map.map_id || @ojos.nil?
    sprites
    ocupado = $game_temp.message_window_showing || $game_temp.player_transferring ||
              $game_temp.in_menu || pbMapInterpreterRunning?
    px, py = $game_player.x, $game_player.y
    # aparecen nuevos
    if !ocupado && !@bloqueado && @ojos.length < MAX && ahora >= @proxima
      o = elegir(px, py)
      @ojos.push(o) if o
      @proxima = ahora + ESPERA[0] + rand(ESPERA[1] - ESPERA[0] + 1)
    end
    combate = nil
    @ojos.each do |o|
      o[:t] += 1
      case o[:estado]
      when :aparece
        o[:estado] = :espera if o[:t] >= 36
      when :espera
        o[:parpadeo] -= 1
        if o[:parpadeo] <= 0
          o[:parpadeo] = 90 + rand(150); o[:lado] = (rand(3) == 0 ? 20 : 0)
        end
        if !ocupado && !@bloqueado && Math.hypot(o[:x] - px, o[:y] - py) <= DETECTA
          o[:estado] = :alerta; o[:t] = 0; @bloqueado = true
          pbSEPlay("Exclaim") rescue nil
        elsif o[:t] >= o[:vida] * 60
          o[:estado] = :se_va; o[:t] = 0
        end
      when :alerta                              # se abren de golpe y se quedan mirando
        if o[:t] >= 30
          o[:ruta] = camino(o[:x].round, o[:y].round, px, py, pasable_mapa)
          if o[:ruta]
            o[:estado] = :caza; o[:t] = 0
          else
            o[:estado] = :se_va; o[:t] = 0; @bloqueado = false
          end
        end
      when :caza                                # va hacia Kaia, casilla a casilla
        paso = VELOCIDAD / 60.0
        if o[:ruta].empty?
          o[:estado] = :nube; o[:t] = 0
        else
          dx = o[:ruta][0][0] - o[:x]; dy = o[:ruta][0][1] - o[:y]
          dist = Math.hypot(dx, dy)
          if dist <= paso
            o[:x], o[:y] = o[:ruta].shift.map(&:to_f)
          else
            o[:x] += dx / dist * paso; o[:y] += dy / dist * paso
          end
        end
      when :nube
        combate = o if o[:t] >= 20
      when :se_va
        o[:muerto] = true if o[:t] >= 30
      end
    end
    @ojos.reject! { |o| o[:muerto] }
    sprites
    luchar(combate) if combate
  end

  def self.luchar(o)
    @ojos.delete(o)
    soltar
    begin
      WildBattle.start(o[:especie], o[:nivel])
    ensure
      @bloqueado = false
      @proxima = ahora + ESPERA[1]
    end
  end

  #--- dibujo ---------------------------------------------------------------------
  def self.sprites
    vp = (Spriteset_Map.viewport rescue nil)
    return if !vp || vp.disposed?
    if @vp != vp
      soltar; @vp = vp
    end
    @b_ojos ||= bmp("ojos.png"); @b_niebla ||= bmp("niebla_ojos.png"); @b_nube ||= bmp("nube.png")
    @spr ||= {}
    vivos = (@ojos || []).map(&:object_id)
    @spr.keys.each do |k|
      next if vivos.include?(k)
      @spr[k].each { |s| s.dispose if !s.disposed? }
      @spr.delete(k)
    end
    ox = $game_map.display_x.to_f / Game_Map::X_SUBPIXELS
    oy = $game_map.display_y.to_f / Game_Map::Y_SUBPIXELS
    (@ojos || []).each do |o|
      s = (@spr[o.object_id] ||= [Sprite.new(vp), Sprite.new(vp), Sprite.new(vp)])
      niebla, ojos, nube = s
      niebla.bitmap = @b_niebla; ojos.bitmap = @b_ojos; nube.bitmap = @b_nube
      cx = (o[:x] * 32 + 16 - ox).round
      cy = (o[:y] * 32 + 16 - oy).round
      # la niebla, que respira un poco
      if @b_niebla
        niebla.ox = @b_niebla.width / 2; niebla.oy = @b_niebla.height / 2
        niebla.x = cx; niebla.y = cy - 6 + (Math.sin(o[:t] / 20.0) * 1.5).round
        niebla.z = 1504
      end
      # los ojos: abiertos, parpadeando o mirando de lado
      if @b_ojos
        cuadro = 0
        if o[:estado] == :espera
          p = o[:parpadeo]
          cuadro = (p <= 3 || (p > 9 && p <= 12)) ? 1 : (p <= 9 ? 2 : 0)
          cuadro = 3 if o[:lado] > 0 && p > 40 && p < 40 + o[:lado] * 3
        end
        ojos.src_rect.set(cuadro * CW, o[:tipo] * CH, CW, CH)
        ojos.ox = CW / 2; ojos.oy = CH / 2
        ojos.x = cx; ojos.y = cy - 12
        ojos.blend_type = 1
        ojos.z = 1505
        ojos.zoom_x = ojos.zoom_y = (o[:estado] == :alerta ? 1.25 : 1.0)
      end
      a = case o[:estado]
          when :aparece then o[:t] * 7
          when :se_va then 255 - o[:t] * 8
          when :nube then 255 - o[:t] * 12
          else 255
          end
      a = [[a, 0].max, 255].min
      niebla.opacity = a * 0.95; ojos.opacity = a
      # la nube al empezar el combate
      if @b_nube && o[:estado] == :nube
        w = @b_nube.height
        nube.src_rect.set([o[:t] / 4, 4].min * w, 0, w, w)
        nube.ox = w / 2; nube.oy = w / 2
        nube.x = cx; nube.y = cy - 6; nube.z = 1506
        nube.zoom_x = nube.zoom_y = 1.6
        nube.opacity = 255
      else
        nube.opacity = 0
      end
    end
  end

  def self.soltar
    (@spr || {}).each_value { |l| l.each { |s| s.dispose if !s.disposed? } }
    @spr = {}
  end
end

class Game_Player
  # mientras unos ojos vienen a por Kaia, no se mueve
  alias ostojos_update_command_new update_command_new
  def update_command_new
    return if OstOjos.bloqueado?
    ostojos_update_command_new
  end
end

class Scene_Map
  alias ostojos_update update
  def update
    ostojos_update
    OstOjos.comprobar
  end
end
