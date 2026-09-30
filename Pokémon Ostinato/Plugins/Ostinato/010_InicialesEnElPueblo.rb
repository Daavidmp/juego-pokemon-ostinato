#===============================================================================
# Pokemon Ostinato - Los tres iniciales, escondidos por Pueblo Preludio
#
#   Despues de la fuga (SW 73, "los tres se han escapado") salen repartidos por
#   el pueblo, cada uno en un sitio que le pega: Mudkip en la fuente, Fennekin
#   en la hierba alta de debajo del laboratorio y Sprigatito en el columpio.
#   Cada uno deja de salir cuando se enciende su interruptor de "devuelto"
#   (74, 75, 76: los SW 0024, 0025 y 0026 del guion, +50).
#
#   Se crean al entrar, igual que los vecinos. Al hablarles sale su acotacion
#   (IniTxt, recursos/guion_iniciales_pueblo.txt) y empieza su minijuego. Al
#   ganarlo "se encarina contigo" y te sigue (interruptores 85, 86, 87), hasta
#   que lo devuelvas al laboratorio (74, 75, 76).
#   Montados: Sprigatito (011_MiniSprigatito.rb), Fennekin (012_MiniFennekin.rb)
#   y Mudkip (013_MiniMudkip.rb).
#===============================================================================
module OstinatoIniciales
  MAPA  = 2
  BASE  = 960        # ids de evento: despues de los vecinos (940+)
  SW_ESCAPE = 73

  # x, y, hacia donde mira, charset, texto, interruptor de "devuelto",
  # interruptor de "te sigue", texto de "se ha encarinado", nombre, minijuego
  TRES = [
    [10, 20, 6, "MUDKIP",     "IniTxt00", 74, 85, "IniTxt03", "Mudkip",     "OstinatoMiniMudkip"],   # en el borde de la fuente
    [17, 10, 2, "FENNEKIN",   "IniTxt01", 75, 86, "IniTxt04", "Fennekin",   "OstinatoMiniFennekin"],   # en la hierba alta, bajo el laboratorio
    [31,  9, 2, "SPRIGATITO", "IniTxt02", 76, 87, "IniTxt05", "Sprigatito", "OstinatoMiniSprigatito"]  # en el columpio
  ]

  def self.fuera?(i)
    return false if !$game_switches || !$game_switches[SW_ESCAPE]
    return false if $game_switches[TRES[i][6]]     # ya te sigue
    return !$game_switches[TRES[i][5]]
  end

  def self.hablar(i)
    g = TRES[i]
    return if !g
    OstDlg.run([[g[4], "cap"]], {})
    return if !g[9] || !Object.const_defined?(g[9])
    ganado = Object.const_get(g[9]).jugar
    return if !ganado
    begin
      pbMEPlay("Pkmn get")
    rescue
    end
    OstDlg.run([[g[7], "cap"]], {})
    seguir(i)
  end

  # Pasa a ser un seguidor de Kaia (el sistema Followers de la v21) y deja de
  # ser un evento del pueblo.
  def self.seguir(i)
    g = TRES[i]
    id = BASE + i
    $game_switches[g[6]] = true
    begin
      Followers.add(id, g[8], nil) if $game_map.events[id]
    rescue
    end
    $game_map.events.delete(id)
    begin
      OstMapa.sprites
    rescue
    end
  end

  def self.crear(i)
    g = TRES[i]
    ev = RPG::Event.new(g[0], g[1])
    ev.id = BASE + i
    ev.name = "Inicial" + i.to_s
    ev.pages[0].graphic.character_name = g[3]
    ev.pages[0].graphic.direction = g[2]
    ev.pages[0].step_anime = true
    ev.pages[0].trigger = 0
    ev.pages[0].list = [
      RPG::EventCommand.new(355, 0, ["OstinatoIniciales.hablar(" + i.to_s + ")"]),
      RPG::EventCommand.new(0, 0, [])
    ]
    $game_map.events[ev.id] = Game_Event.new($game_map.map_id, ev, $game_map)
  end

  def self.comprobar
    return if !$game_map || !$game_map.events || $game_map.map_id != MAPA
    return if !$game_player || $game_player.moving?
    return if $game_temp && ($game_temp.message_window_showing ||
                             $game_temp.player_transferring)
    cambiado = false
    TRES.each_index do |i|
      id = BASE + i
      if fuera?(i) && !$game_map.events[id]
        crear(i)
        cambiado = true
      elsif !fuera?(i) && $game_map.events[id]
        $game_map.events.delete(id)
        cambiado = true
      end
    end
    return if !cambiado
    begin
      OstMapa.sprites
    rescue
    end
  end
end

class Scene_Map
  alias ostinato_iniciales_update update

  def update
    ostinato_iniciales_update
    OstinatoIniciales.comprobar
  end
end
