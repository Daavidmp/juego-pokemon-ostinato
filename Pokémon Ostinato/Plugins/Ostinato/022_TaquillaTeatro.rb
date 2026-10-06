#===============================================================================
# Pokemon Ostinato - La taquilla del teatro de Villa Bambalina
#
#   Delante del teatro (mapa 12) esta la tiquera con mucha gente alrededor
#   (24 vecinos, de las skins del tamano de Kaia que ya usa el juego).
#   La primera vez que Kaia sube a la explanada del teatro:
#     - la tiquera anuncia la obra nueva y la gente grita que quiere verla;
#     - Lira llega con Kaia: "Que es todo ese murmullo?";
#     - entran tres personas, la pantalla funde a negro y al volver solo
#       queda la tiquera;
#     - la tiquera les cobra 10$ la entrada (se elige pagar o no).
#   Sin entrada, la puerta del teatro no deja pasar (barrera invisible) y la
#   tiquera vuelve a ofrecerla. Con entrada, la puerta lleva dentro (mapa 13),
#   y el felpudo de dentro saca otra vez a la puerta.
#
#   La tiquera habla con su retrato (DlgTiquera.png, del .kra de CREDITOS);
#   la gente, con el bocadillo. La tiquera, la gente y Lira se crean en marcha.
#   Interruptores: 80 = escena vista, 81 = entrada comprada.
#   Textos: TiqTxt, GenteTxt, BamTxt, TiqOpc (recursos/dialogos_ostinato.txt).
#===============================================================================
module OstTaquilla
  MAPA        = 12
  MAPA_TEATRO = 13
  SW_VISTA    = 80
  SW_ENTRADA  = 81
  PRECIO      = 10
  PUERTA      = [8, 5]           # la puerta del teatro
  ESCALON     = [8, 6]           # la casilla de delante (la barrera)
  DENTRO      = [10, 18]         # el felpudo de dentro del teatro
  TIQUERA     = [9, 7]
  ID_TIQ      = 960
  ID_LIRA     = 969
  GENTE = [
    [961, "mujer1",    5, 8], [962, "anciano1",  6, 8], [963, "hombre1",   7, 8],
    [964, "chaval1",   9, 8], [965, "chica1",   10, 8], [966, "anciana1", 11, 8],
    [967, "veterano",  6, 9], [968, "montanero", 10, 9],
    [970, "anciano2",  4, 7], [971, "chaval2",   5, 7], [972, "mujer2",    6, 7],
    [973, "nina",     10, 7], [974, "pescador", 11, 7], [975, "criadora", 12, 7],
    [976, "campista",  4, 8], [977, "ornitologo", 12, 8], [978, "chaval3",  4, 9],
    [979, "veterana",  5, 9], [980, "operario",  7, 9], [981, "asistente", 9, 9],
    [982, "campistaa", 11, 9], [983, "anciana2", 3, 7], [984, "chica1",   13, 7],
    [985, "anciano1", 13, 8]
  ]
  # quien grita cada frase de la gente
  GRITOS = [["GenteTxt00", 961], ["GenteTxt01", 964], ["GenteTxt02", 966],
            ["GenteTxt03", 962], ["GenteTxt04", 968]]

  def self.en_mapa?(id); return $game_map && $game_map.map_id == id; end
  def self.ev(id); return $game_map.events[id]; end
  # la tiquera habla con su retrato a la izquierda; Lira, en el segundo hueco
  ARTES = {
    "izq"  => ["DlgTiquera.png", 40, 465, "DlgNomTiquera"],
    "izq2" => ["DlgLira.png", 174, 465, "DlgNomLira"],
    "der"  => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }
  def self.artes; return ARTES; end

  #--- personajes creados en marcha -------------------------------------------
  def self.crear(id, nombre, skin, x, y, dir = 2)
    return ev(id) if ev(id)
    e = RPG::Event.new(x, y)
    e.id = id
    e.name = nombre
    e.pages[0].graphic.character_name = skin
    e.pages[0].graphic.direction = dir
    g = Game_Event.new($game_map.map_id, e, $game_map)
    $game_map.events[id] = g
    OstMapa.sprites
    return g
  end

  def self.borrar(id)
    return if !ev(id)
    $game_map.events.delete(id)
    OstMapa.sprites
  end

  def self.poblar
    return if !en_mapa?(MAPA)
    crear(ID_TIQ, "Tiquera", "tiquera", TIQUERA[0], TIQUERA[1], 2)
    return if $game_switches[SW_VISTA]
    GENTE.each { |id, skin, x, y| crear(id, "Gente", skin, x, y, 8) }
  end

  #--- hablar -------------------------------------------------------------------
  # una frase con el bocadillo de pico sobre quien la dice; con segundos, se va sola
  def self.bocadillo(codigo, quien, segundos = nil)
    return if !quien || !OstDlg.pnj_preparar(quien)
    paso = segundos ? [codigo, "pnj", segundos] : [codigo, "pnj"]
    begin
      OstDlg.run([paso], {})
    ensure
      OstDlg.pnj_soltar
    end
  end

  def self.dialogo(lista)
    OstDlg.run(lista, artes)
  end

  def self.ir(quien, x, y, dir = nil)
    return if !quien
    pasos = OstMapa.camino(quien, x, y) || []
    pasos = pasos + [dir] if dir
    OstinatoLaboratorio.mover(quien, pasos) if pasos.length > 0
  end

  #--- la escena ----------------------------------------------------------------
  def self.toca_escena?
    return false if !en_mapa?(MAPA) || $game_switches[SW_VISTA]
    return $game_player.y >= 7 && $game_player.y <= 10
  end

  def self.escena
    tiq = ev(ID_TIQ)
    # Kaia se para al fondo y llega Lira
    ir($game_player, 13, 9, PBMoveRoute::TURN_UP)
    lira = crear(ID_LIRA, "Lira", "sora", 14, 11, 8)
    ir(lira, 14, 9, PBMoveRoute::TURN_UP)
    OstDlg.esperar(0.3)
    # el anuncio y el jaleo
    dialogo([["TiqTxt00", "izq"], ["TiqTxt01", "izq"]])
    GRITOS.each { |cod, id| bocadillo(cod, ev(id), 1.1) }
    OstMapa.mirarse(lira, $game_player)
    dialogo([["BamTxt00", "izq2"], ["BamTxt01", "der"]])
    # la gente entra en el teatro
    # entran los tres que estan mas cerca de la puerta; luego, a negro, y al
    # volver ya no queda nadie mas que la tiquera
    cerca = GENTE.sort_by { |_id, _s, x, y| (x - PUERTA[0]).abs + (y - PUERTA[1]).abs }.first(3)
    rutas = []
    cerca.each_with_index do |(id, _s, _x, _y), i|
      g = ev(id)
      next if !g
      g.through = true
      g.move_speed = 4
      pasos = OstMapa.camino(g, PUERTA[0], PUERTA[1]) || []
      rutas.push([g, pasos, 1 + i * 16])
    end
    OstinatoFuga.mover_juntos(rutas)
    cerca.each { |id, _s, _x, _y| borrar(id) }
    pbFadeOutIn do
      GENTE.each { |id, _s, _x, _y| borrar(id) }
      OstDlg.esperar(0.4)
    end
    $game_switches[SW_VISTA] = true
    # Kaia y Lira se acercan a la taquilla
    ir($game_player, 8, 8, PBMoveRoute::TURN_UP)
    ir(lira, 7, 8, PBMoveRoute::TURN_UP)
    OstMapa.mirarse($game_player, tiq)
    OstMapa.mirarse(tiq, $game_player)
    dialogo([["TiqTxt02", "izq"], ["BamTxt02", "der"], ["TiqTxt03", "izq"]])
    comprar(tiq, lira, true)
    # Lira entra
    if lira
      lira.through = true
      ir(lira, PUERTA[0], PUERTA[1])
      borrar(ID_LIRA)
    end
    $game_map.need_refresh = true
  ensure
    borrar(ID_LIRA) if en_mapa?(MAPA) && ev(ID_LIRA) && $game_switches[SW_VISTA]
  end

  # la eleccion de pagar; primera = con Lira delante
  def self.comprar(tiq, lira = nil, primera = false)
    i = OstDlg.elegir(["TiqOpc00", "TiqOpc01"])
    if i == 0 && $player.money >= PRECIO
      $player.money -= PRECIO
      $game_switches[SW_ENTRADA] = true
      begin
        pbSEPlay("Mart buy item")
      rescue
      end
      dialogo([["BamTxt03", "izq2"]]) if primera
      dialogo([["TiqTxt04", "izq"]])
    elsif i == 0
      dialogo([["TiqTxt06", "izq"]])
      dialogo([["BamTxt04", "izq2"]]) if primera
    else
      dialogo([["TiqTxt05", "izq"]])
      dialogo([["BamTxt04", "izq2"]]) if primera
    end
  end

  def self.hablar
    tiq = ev(ID_TIQ)
    return if !tiq
    OstMapa.mirarse(tiq, $game_player)
    if $game_switches[SW_ENTRADA]
      dialogo([["TiqTxt08", "izq"]])
    else
      dialogo([["TiqTxt07", "izq"]])
      comprar(tiq)
    end
    tiq.turn_down
  end

  #--- la puerta ----------------------------------------------------------------
  def self.cerrada?
    return en_mapa?(MAPA) && !$game_switches[SW_ENTRADA]
  end

  def self.pedir(que); @pedido = que; end

  def self.trasladar(mapa, x, y, dir)
    $game_temp.player_new_map_id    = mapa
    $game_temp.player_new_x         = x
    $game_temp.player_new_y         = y
    $game_temp.player_new_direction = dir
    $game_temp.player_transferring  = true
  end

  def self.mira_a_tiquera?
    tiq = ev(ID_TIQ)
    return false if !tiq
    d = $game_player.direction
    x = $game_player.x + (d == 6 ? 1 : d == 4 ? -1 : 0)
    y = $game_player.y + (d == 2 ? 1 : d == 8 ? -1 : 0)
    return tiq.x == x && tiq.y == y
  end

  def self.comprobar
    return if @corriendo || !$game_map || !$game_player
    poblar
    return if $game_player.moving?
    return if $game_temp && ($game_temp.message_window_showing || $game_temp.player_transferring || $game_temp.in_battle)
    que = @pedido
    @pedido = nil
    if !que && en_mapa?(MAPA) && Input.trigger?(Input::USE) && mira_a_tiquera?
      que = :hablar
    end
    que = :escena if !que && toca_escena?
    if !que && en_mapa?(MAPA) && $game_switches[SW_ENTRADA] &&
       $game_player.x == PUERTA[0] && $game_player.y == PUERTA[1]
      pbSEPlay("Door exit") rescue nil
      trasladar(MAPA_TEATRO, DENTRO[0], DENTRO[1], 8)
      return
    end
    if que == :salir
      pbSEPlay("Door exit") rescue nil
      trasladar(MAPA, ESCALON[0], ESCALON[1], 2)
      return
    end
    return if !que || que == :salir
    @corriendo = true
    begin
      que == :escena ? escena : hablar
    ensure
      @corriendo = false
    end
  end
end

class Game_Player
  alias ostaq_passable? passable?
  def passable?(x, y, d, *resto)
    begin
      nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0))
      ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
      if OstTaquilla.cerrada? && nx == OstTaquilla::ESCALON[0] && ny == OstTaquilla::ESCALON[1]
        OstTaquilla.pedir(:hablar) if $game_switches[OstTaquilla::SW_VISTA]
        return false
      end
      if OstTaquilla.en_mapa?(OstTaquilla::MAPA_TEATRO) && d == 2 && y == OstTaquilla::DENTRO[1] &&
         (x == OstTaquilla::DENTRO[0] || x == OstTaquilla::DENTRO[0] + 1)
        OstTaquilla.pedir(:salir)
        return false
      end
    rescue
    end
    return ostaq_passable?(x, y, d, *resto)
  end
end

class Scene_Map
  alias ostaq_update update
  def update
    ostaq_update
    OstTaquilla.comprobar
  end
end
