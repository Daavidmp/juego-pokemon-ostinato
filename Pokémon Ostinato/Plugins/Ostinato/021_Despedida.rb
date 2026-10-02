#===============================================================================
# Pokemon Ostinato - La despedida de Blanca, antes de salir por el sur
#
#   Tras el combate contra Lira (interruptor 78) la salida sur del pueblo
#   sigue cerrada: al intentar salir, Kaia dice que deberia despedirse de su
#   madre (PuerAvi02). En casa, al hablar con Blanca, en vez de lo de siempre
#   sale la despedida: Kaia le presenta a su Pokemon (sale de su Poke Ball a
#   su lado y dice su nombre en el bocadillo con pico), se despiden, el
#   Pokemon vuelve a su bola y se abre la salida (interruptor SW_DESPEDIDA).
#
#   Textos: AdiosTxt y AdiosPoke (recursos/dialogos_ostinato.txt).
#===============================================================================
module OstDespedida
  MAPA         = 3          # la casa de Kaia, donde esta Blanca
  SW_COMBATE   = 78         # el combate contra Lira ya ha pasado
  SW_DESPEDIDA = 79         # ya se ha despedido: salida sur abierta
  ID_POKE      = 940
  ESPECIES     = [:MUDKIP, :FENNEKIN, :SPRIGATITO]
  CHARSETS     = ["MUDKIP", "FENNEKIN", "SPRIGATITO"]
  SONIDO_BOLA  = "Battle recall"

  def self.toca?
    return false if !$game_switches || !$game_map
    return $game_switches[SW_COMBATE] && !$game_switches[SW_DESPEDIDA]
  end

  def self.pedir; @pedido = true; end

  def self.comprobar
    return if !@pedido || @corriendo
    @pedido = false
    @corriendo = true
    begin
      escena
    ensure
      @corriendo = false
    end
  end

  def self.inicial
    i = (($game_variables && $game_variables[7]) || 1).to_i - 1
    i = 0 if i < 0 || i > 2
    return i
  end

  # una casilla libre junto a Kaia (que no sea la de Blanca)
  def self.sitio_libre(blanca)
    [[-1, 0], [1, 0], [0, 1], [0, -1]].each do |dx, dy|
      x = $game_player.x + dx
      y = $game_player.y + dy
      next if blanca && blanca.x == x && blanca.y == y
      next if !$game_map.valid?(x, y) || !$game_map.passable?(x, y, 0)
      next if $game_map.events.values.any? { |e| e.x == x && e.y == y && !e.through }
      return [x, y]
    end
    return [$game_player.x, $game_player.y + 1]
  end

  def self.crear_poke(i, x, y)
    ev = RPG::Event.new(x, y)
    ev.id = ID_POKE
    ev.name = CHARSETS[i]
    ev.pages[0].graphic.character_name = CHARSETS[i]
    ev.pages[0].graphic.direction = 2
    ev.pages[0].through = true
    g = Game_Event.new($game_map.map_id, ev, $game_map)
    g.opacity = 0
    $game_map.events[ev.id] = g
    OstMapa.sprites
    return g
  end

  def self.borrar_poke
    return if !$game_map || !$game_map.events[ID_POKE]
    $game_map.events.delete(ID_POKE)
    OstMapa.sprites
  end

  def self.destello
    begin
      pbSEPlay(SONIDO_BOLA, 85)
    rescue
    end
    begin
      $game_screen.start_flash(Color.new(255, 255, 255, 130), 10)
    rescue
    end
  end

  # sale de su Poke Ball, con un destello, y dice su nombre en el bocadillo
  def self.sacar_poke(blanca)
    i = inicial
    x, y = sitio_libre(blanca)
    g = crear_poke(i, x, y)
    OstMapa.mirarse(g, blanca) if blanca
    destello
    while g.opacity < 255
      g.opacity = [g.opacity + 32, 255].min
      OstDlg.tick
    end
    begin
      Pokemon.play_cry(ESPECIES[i])
    rescue
    end
    OstDlg.esperar(0.3)
    if OstDlg.pnj_preparar(g)
      begin
        OstDlg.run([[sprintf("AdiosPoke%02d", i), "pnj"]], {})
      ensure
        OstDlg.pnj_soltar
      end
    end
  end

  def self.guardar_poke
    g = $game_map.events[ID_POKE]
    return if !g
    destello
    while g.opacity > 0
      g.opacity = [g.opacity - 32, 0].max
      OstDlg.tick
    end
    borrar_poke
  end

  def self.escena
    blanca = OstMapa.evento("Blanca")
    OstMapa.mirarse(blanca, $game_player) if blanca
    OstMapa.mirarse($game_player, blanca) if blanca
    artes = OstinatoCocina::ARTES
    ajustes = OstinatoCocina::AJUSTES
    OstDlg.run([["AdiosTxt00", "izq"],    # Hola, hija. Te veo contenta.
                ["AdiosTxt01", "der"]],   # Si, mama. Vengo a despedirme de ti, y de paso te presento a mi Pokemon.
               artes, ajustes)
    sacar_poke(blanca)
    OstDlg.run([["AdiosTxt02", "izq"],    # Vaya, que bonico. Y parece fuerte.
                ["AdiosTxt03", "der"],    # Si, claro. Bueno, mama, es la hora. Me voy.
                ["AdiosTxt04", "izq"],    # Que orgullosa estoy de ti. Suerte en tu viaje, hija.
                ["AdiosTxt05", "der"]],   # Nos vemos!
               artes, ajustes)
    guardar_poke
    $game_switches[SW_DESPEDIDA] = true
    $game_map.need_refresh = true
  ensure
    borrar_poke
  end
end

# Hablar con Blanca, si toca despedirse: la despedida en vez de lo de siempre
class Game_Event
  alias ostdesp_start start
  def start
    if @event && @event.name == "Blanca" && $game_map && $game_map.map_id == OstDespedida::MAPA &&
       OstDespedida.toca?
      OstDespedida.pedir
      return
    end
    ostdesp_start
  end
end

class Scene_Map
  alias ostdesp_update update
  def update
    ostdesp_update
    OstDespedida.comprobar
  end
end

# La salida sur: antes del laboratorio, el aviso de siempre; despues del
# combate y hasta despedirse, el de la madre.
module OstinatoSalida
  AVISO_MADRE = [
    ["PuerAvi02", "der"]    # Deberia de despedirme de mi madre antes de irme.
  ]

  def self.cerrado?
    return false if !$game_map || $game_map.map_id != MAPA_PUEBLO
    return false if !$game_switches
    return false if $game_switches[OstDespedida::SW_DESPEDIDA]
    return true
  end

  def self.avisar
    if $game_switches[SWITCH_LAB]
      OstDlg.run(AVISO_MADRE, ARTES)
    else
      OstDlg.run(AVISO, ARTES)
    end
  end
end
