#===============================================================================
# Pokemon Ostinato - Los Pokemon salvajes del tunel de la ruta 4 (mapas 15 a 18)
#
#   En el tunel no hay hierba: los Pokemon andan por el mapa con su sprite de
#   seguidor (Graphics/Characters/Followers/), como en Escarlata/Purpura. Cada
#   especie se porta a su manera cuando Kaia esta cerca:
#     :curioso  se acerca a mirar      :miedoso  huye      :agresivo  la persigue
#   Si te tocan o los tocas, combate (evento con disparo "contacto con evento",
#   que salta en los dos casos). Para que se vean en la oscuridad del tunel (029)
#   se pinta una copia de cada uno por encima de ella (VISIBLE). Los de agua no
#   se alejan de la orilla (AGUA).
#   Se crean en marcha con ids 700+; al cambiar de mapa desaparecen solos.
#===============================================================================
module OstPkTunel
  MAX       = 3             # Pokemon a la vez en un mapa
  LEJOS     = 7             # no aparecen a menos de estas casillas de Kaia
  CERCA     = 4             # a partir de aqui reaccionan a Kaia
  ESPERA    = [5, 10]       # segundos entre una aparicion y la siguiente
  VIDA      = 45            # segundos; luego, si estan lejos, se van
  ID0       = 700
  VISIBLE   = 0.75          # opacidad de la copia que va por encima de la oscuridad

  # [especie, nivel minimo, nivel maximo, peso, comportamiento, vuela]
  ESPECIES = {
    15 => [[:ZUBAT, 8, 10, 6, :curioso, true], [:RATTATA, 8, 10, 4, :miedoso, false],
           [:TYMPOLE, 8, 10, 3, :curioso, false]],
    16 => [[:ZUBAT, 8, 11, 5, :curioso, true], [:WOOBAT, 9, 11, 3, :curioso, true],
           [:RATTATA, 9, 10, 3, :miedoso, false], [:ZORUA, 10, 11, 1, :miedoso, false],
           [:WOOPER, 9, 11, 3, :curioso, false]],
    17 => [[:ZUBAT, 9, 11, 4, :curioso, true], [:WOOBAT, 9, 12, 3, :curioso, true],
           [:GASTLY, 10, 12, 3, :agresivo, true], [:TYMPOLE, 9, 11, 3, :curioso, false]],
    18 => [[:WOOBAT, 10, 12, 4, :curioso, true], [:GASTLY, 10, 12, 4, :agresivo, true],
           [:SABLEYE, 11, 12, 1, :agresivo, false], [:WOOPER, 10, 12, 3, :curioso, false]]
  }
  AGUA_ESPECIES = [:TYMPOLE, :WOOPER]
  # orillas (casillas x0, y0, x1, y1): solo ahi andan los de agua
  AGUA = {
    15 => [[1, 15, 22, 19]],
    16 => [[1, 11, 22, 13], [1, 20, 7, 29]],
    17 => [[19, 5, 25, 21]],
    18 => [[23, 19, 32, 22]]
  }

  def self.ahora; return (System.uptime rescue Time.now.to_f); end

  def self.en_zona?(x, y, zonas)
    return zonas.any? { |a| x >= a[0] && x <= a[2] && y >= a[1] && y <= a[3] }
  end

  #--- donde pueden aparecer -----------------------------------------------------
  def self.preparar
    @mapa = $game_map.map_id
    @pk = {}                  # id => datos
    @proxima = ahora + 2
    @suelo = []; @orilla = []
    zonas = AGUA[@mapa] || []
    $game_map.width.times do |x|
      $game_map.height.times do |y|
        next if ![2, 4, 6, 8].any? { |d| $game_map.passable?(x, y, d) }
        next if $game_map.events.values.any? { |e| e.x == x && e.y == y }
        (en_zona?(x, y, zonas) ? @orilla : @suelo).push([x, y])
      end
    end
  end

  # especie por peso y casilla libre lejos de Kaia
  def self.elegir(px, py, rnd = Random)
    tabla = ESPECIES[@mapa] || []
    total = tabla.sum { |t| t[3] }
    return nil if total <= 0
    r = rnd.rand(total)
    fila = tabla.find { |t| (r -= t[3]) < 0 }
    sitios = (AGUA_ESPECIES.include?(fila[0]) ? @orilla : @suelo).select do |x, y|
      (x - px).abs + (y - py).abs >= LEJOS && !ocupada?(x, y)
    end
    return nil if sitios.empty?
    x, y = sitios[rnd.rand(sitios.length)]
    return { :especie => fila[0], :nivel => fila[1] + rnd.rand(fila[2] - fila[1] + 1),
             :modo => fila[4], :vuela => fila[5], :agua => AGUA_ESPECIES.include?(fila[0]),
             :x => x, :y => y, :nace => ahora, :espera => 0, :alfa => 0 }
  end

  def self.ocupada?(x, y)
    return false if !$game_map
    return $game_map.events.values.any? { |e| e.x == x && e.y == y && !e.instance_variable_get(:@erased) }
  end

  #--- crear y quitar -------------------------------------------------------------
  def self.crear(d)
    id = ID0
    id += 1 while $game_map.events[id]
    e = RPG::Event.new(d[:x], d[:y])
    e.id = id
    e.name = "PkTunel"
    pg = e.pages[0]
    pg.graphic.character_name = "Followers/#{d[:especie]}"
    pg.graphic.direction = 2
    pg.trigger = 2                                # contacto: lo toques o te toque
    pg.step_anime = d[:vuela]                     # los que vuelan aletean siempre
    pg.move_speed = (d[:modo] == :agresivo ? 4 : 3)
    pg.list = [RPG::EventCommand.new(355, 0, ["OstPkTunel.luchar(#{id})"]), RPG::EventCommand.new(0, 0, [])]
    g = Game_Event.new($game_map.map_id, e, $game_map)
    g.opacity = 0
    $game_map.events[id] = g
    @pk[id] = d
    OstMapa.sprites
  end

  def self.quitar(id)
    @pk.delete(id)
    ev = $game_map.events[id]
    ev.erase if ev
    OstMapa.sprites rescue nil
  end

  #--- el combate (lo llama el evento al tocarse) -----------------------------------
  def self.luchar(id)
    d = @pk[id]
    return if !d
    quitar(id)
    WildBattle.start(d[:especie], d[:nivel])
    @proxima = ahora + ESPERA[1]
  end

  #--- moverse ----------------------------------------------------------------------
  PASOS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }

  # direcciones por orden de preferencia segun el comportamiento
  def self.direcciones(d, ex, ey, px, py, rnd = Random)
    cerca = (ex - px).abs + (ey - py).abs <= CERCA
    al_azar = PASOS.keys.shuffle(random: rnd)
    return al_azar if !cerca
    hacia = PASOS.keys.sort_by { |k| (ex + PASOS[k][0] - px).abs + (ey + PASOS[k][1] - py).abs }
    case d[:modo]
    when :miedoso then return hacia.reverse
    when :agresivo then return hacia
    else return rnd.rand(2) == 0 ? hacia : al_azar       # curioso: se acerca a ratos
    end
  end

  def self.mover(id, ev, d)
    return if ev.moving?
    if d[:espera] > 0
      d[:espera] -= 1
      return
    end
    px, py = $game_player.x, $game_player.y
    zonas = d[:agua] ? (AGUA[@mapa] || []) : nil
    direcciones(d, ev.x, ev.y, px, py).each do |dir|
      nx = ev.x + PASOS[dir][0]; ny = ev.y + PASOS[dir][1]
      next if zonas && !en_zona?(nx, ny, zonas)
      next if !ev.passable?(ev.x, ev.y, dir) && !(nx == px && ny == py)
      case dir
      when 2 then ev.move_down
      when 4 then ev.move_left
      when 6 then ev.move_right
      when 8 then ev.move_up
      end
      break
    end
    cerca = (ev.x - px).abs + (ev.y - py).abs <= CERCA
    d[:espera] = cerca ? (d[:modo] == :agresivo ? 4 : 10) : 30 + rand(60)
  end

  #--- cada fotograma ------------------------------------------------------------------
  def self.comprobar
    return if !$game_map || !ESPECIES.key?($game_map.map_id)
    preparar if @mapa != $game_map.map_id || @pk.nil?
    @pk.keys.each { |id| @pk.delete(id) if !$game_map.events[id] }
    return if pbMapInterpreterRunning? || $game_temp.message_window_showing ||
              $game_temp.player_transferring || $game_temp.in_menu
    px, py = $game_player.x, $game_player.y
    if @pk.length < MAX && ahora >= @proxima
      d = elegir(px, py)
      crear(d) if d
      @proxima = ahora + ESPERA[0] + rand(ESPERA[1] - ESPERA[0] + 1)
    end
    @pk.keys.each do |id|
      ev = $game_map.events[id]
      d = @pk[id]
      # aparecen y se van con un fundido
      if d[:vete]
        d[:alfa] -= 12
        if d[:alfa] <= 0
          quitar(id)
          next
        end
      elsif d[:alfa] < 255
        d[:alfa] += 12
      end
      ev.opacity = [[d[:alfa], 0].max, 255].min
      lejos = (ev.x - px).abs + (ev.y - py).abs > LEJOS + 4
      d[:vete] = true if !d[:vete] && lejos && ahora - d[:nace] > VIDA
      mover(id, ev, d) if !d[:vete]
    end
    copias
  end

  # una copia de cada Pokemon (su mismo dibujo y cuadro) por encima de la oscuridad
  def self.copias
    vp = (Spriteset_Map.viewport rescue nil)
    @copia ||= {}
    @copia.keys.each do |id|
      next if @pk[id] && vp
      @copia[id].dispose if !@copia[id].disposed?
      @copia.delete(id)
    end
    return if !vp || !$scene.is_a?(Scene_Map)
    ss = ($scene.spriteset($game_map.map_id) rescue nil)
    lista = ss ? ss.instance_variable_get(:@character_sprites) : nil
    return if !lista
    @pk.each_key do |id|
      ev = $game_map.events[id]
      sp = lista.find { |c| c.character == ev }
      cp = (@copia[id] ||= Sprite.new(vp))
      if !sp || sp.disposed? || !sp.bitmap
        cp.opacity = 0
        next
      end
      cp.bitmap = sp.bitmap; cp.src_rect = sp.src_rect
      cp.x = sp.x; cp.y = sp.y; cp.ox = sp.ox; cp.oy = sp.oy
      cp.zoom_x = sp.zoom_x; cp.zoom_y = sp.zoom_y
      cp.z = 1502
      cp.opacity = (sp.opacity * VISIBLE).round
    end
  rescue
  end
end

class Scene_Map
  alias ostpk_update update
  def update
    ostpk_update
    OstPkTunel.comprobar
  end
end
