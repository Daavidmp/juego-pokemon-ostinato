#===============================================================================
# Pokemon Ostinato - El patio de butacas del teatro (mapa 13)
#
#   El patio esta lleno: en las 50 butacas hay gente sentada menos en dos, las
#   de Kaia y Lira (tercera fila, bloque izquierdo, las dos de en medio).
#   Lira espera en el pasillo central. Kaia entra en la fila andando de lado
#   y al llegar a su butaca sale el cartel "ENTER SENTARSE". Con Enter se
#   sienta, y Lira entra detras y se sienta a su lado. Interruptor 82 = las
#   dos sentadas; despues se llama a OstObra.empezar si existe (la obra).
#
#   Las butacas del dibujo no van a la rejilla: las filas estan cada 40 px y
#   las butacas cada 34. Por eso:
#   - la gente sentada son personajes creados en marcha (ids 1000+), puestos
#     con desfase de pixel (x_offset / y_offset) justo encima de su butaca;
#   - las butacas se vuelven a pintar por encima de cada fila de gente
#     (Graphics/Titles/TeaButaca0..4.png, recortadas del propio mapa, sin
#     suelo): asi la butaca tapa el cuerpo y solo asoma la cabeza. Cada fila
#     va con su z entre la gente de esa fila y la de la siguiente;
#   - Kaia anda por el hueco de delante de cada fila (las piernas), que cae
#     entre casillas: mientras esta en una fila se le baja o sube unos pixeles
#     (PASILLO) y al entrar o salir el desfase se reparte por el paso;
#   - en las casillas de las filas solo se anda de lado (izquierda/derecha).
#===============================================================================
module OstButacas
  MAPA        = 13
  SW_ENTRADA  = 81
  SW_SENTADAS = 82
  ID_GENTE    = 1000
  ID_LIRA     = 990

  # Medido sobre el mapa (pixeles del mapa, 32 por casilla): donde empieza y
  # acaba el rojo de cada fila de butacas y el centro de cada butaca.
  ROJO_ARRIBA = [424, 464, 504, 544, 586]
  ROJO_ABAJO  = [447, 487, 525, 566, 607]
  CENTROS     = [288, 322, 358, 392, 426, 532, 566, 600, 634, 670]
  # La casilla de cada butaca y la fila de casillas por la que se anda por
  # delante de cada fila de butacas.
  CASILLA_X   = [9, 10, 11, 12, 13, 16, 17, 18, 19, 20]
  PASILLO_Y   = [12, 14, 15, 16, 17]
  BLOQUES     = [(8..13), (16..21)]
  # Ajustes a ojo: lo que se hunde la gente en la butaca y lo que queda la
  # capa de butacas por encima de la gente de su fila.
  SENT_DY = 2
  CAPA_DZ = 8
  # Las capas de butacas: x y y de su esquina en el mapa
  CAPA_X = 256
  CAPA_Y = [421, 461, 501, 541, 583]

  KAIA  = [2, 2]     # fila, butaca
  LIRA  = [2, 3]
  LIRA_ESPERA = [15, 15]
  SKINS = ["anciana1", "anciano1", "mujer1", "hombre1", "chaval1", "chica1",
           "veterano", "montanero", "anciano2", "chaval2", "mujer2", "nina",
           "pescador", "criadora", "campista", "ornitologo", "chaval3",
           "veterana", "operario", "asistente", "campistaa", "anciana2",
           "nino", "tendero", "marinero", "tecnico", "operaria", "chavala1",
           "minero"]
  CARTEL = "Graphics/Titles/TeaSentarse.png"

  def self.en_mapa?; return $game_map && $game_map.map_id == MAPA; end
  def self.ev(id); return $game_map.events[id]; end

  #--- donde va cada cosa --------------------------------------------------------
  def self.pasillo?(x, y)
    k = PASILLO_Y.index(y)
    return false if !k || k == 0          # la fila 12 ya era suelo normal
    return BLOQUES.any? { |b| b.include?(x) }
  end

  # lo que se sube o baja a quien esta en la casilla (x, y) de una fila
  def self.desfase(x, y)
    k = PASILLO_Y.index(y)
    return 0 if !k || !BLOQUES.any? { |b| b.include?(x) }
    return ROJO_ARRIBA[k] + 2 - (y + 1) * 32
  end

  # el desfase repartido entre las casillas por las que va pasando
  def self.desfase_real(ch)
    rx = ch.real_x.to_f / Game_Map::REAL_RES_X
    ry = ch.real_y.to_f / Game_Map::REAL_RES_Y
    x0 = rx.floor
    y0 = ry.floor
    fx = rx - x0
    fy = ry - y0
    v = desfase(x0, y0) * (1 - fx) * (1 - fy) + desfase(x0 + 1, y0) * fx * (1 - fy) +
        desfase(x0, y0 + 1) * (1 - fx) * fy + desfase(x0 + 1, y0 + 1) * fx * fy
    return v.round
  end

  # [x, y] de casilla y [dx, dy] de pixel para quien se sienta en (fila, butaca)
  def self.butaca(k, j)
    x = CASILLA_X[j]
    y = PASILLO_Y[k]
    return [x, y, CENTROS[j] - (x * 32 + 16), ROJO_ABAJO[k] + SENT_DY - (y + 1) * 32]
  end

  #--- la gente ------------------------------------------------------------------
  # quieto = la gente sentada: se la atraviesa, no se gira y no mueve los pies
  def self.crear(id, nombre, skin, x, y, dir, quieto = false)
    return ev(id) if ev(id)
    e = RPG::Event.new(x, y)
    e.id = id
    e.name = nombre
    e.pages[0].graphic.character_name = skin
    e.pages[0].graphic.direction = dir
    if quieto
      e.pages[0].through = true
      e.pages[0].direction_fix = true
      e.pages[0].walk_anime = false
    end
    g = Game_Event.new($game_map.map_id, e, $game_map)
    $game_map.events[id] = g
    return g
  end

  def self.sentar(ch, k, j)
    x, y, dx, dy = butaca(k, j)
    ch.moveto(x, y)
    ch.turn_up
    ch.ost_ofs = [dx, dy]
  end

  def self.poblar
    return if ev(ID_GENTE)
    n = 0
    5.times do |k|
      10.times do |j|
        next if [k, j] == KAIA || [k, j] == LIRA
        g = crear(ID_GENTE + k * 10 + j, "Publico", SKINS[(n * 7 + k) % SKINS.length], 0, 0, 8, true)
        sentar(g, k, j)
        n += 1
      end
    end
    if $game_switches[SW_ENTRADA]
      lira = crear(ID_LIRA, "Lira", "sora", LIRA_ESPERA[0], LIRA_ESPERA[1], 2)
      lira.ost_pasillo = true
      sentar(lira, LIRA[0], LIRA[1]) if $game_switches[SW_SENTADAS]
    end
    $game_player.ost_pasillo = true
    OstMapa.sprites
  end

  #--- las butacas por encima de la gente ----------------------------------------
  def self.capas
    vp = (Spriteset_Map.viewport rescue nil)
    if !en_mapa? || !vp || vp.disposed?
      soltar_capas
      return
    end
    if !@capas || @vp != vp
      soltar_capas
      @vp = vp
      @capas = []
      5.times do |k|
        s = Sprite.new(vp)
        s.bitmap = OstDlg.bmp("Graphics/Titles/TeaButaca#{k}.png")
        @capas.push(s)
      end
    end
    ox = ($game_map.display_x.to_f / Game_Map::X_SUBPIXELS).round
    oy = ($game_map.display_y.to_f / Game_Map::Y_SUBPIXELS).round
    @capas.each_with_index do |s, k|
      s.x = CAPA_X - ox
      s.y = CAPA_Y[k] - oy
      # la gente de la fila k tiene z = sus pies + 31
      s.z = ROJO_ABAJO[k] + SENT_DY + 31 + CAPA_DZ - oy
    end
  end

  def self.soltar_capas
    (@capas || []).each { |s| OstDlg.soltar(s) }
    @capas = nil
    @vp = nil
  end

  #--- el cartel "ENTER SENTARSE" -------------------------------------------------
  def self.cartel(ver, cuadro = nil)
    if !ver
      OstDlg.soltar(@cartel)
      @cartel = nil
      return
    end
    if !@cartel || @cartel.disposed?
      vp = (Spriteset_Map.viewport rescue nil)
      return if !vp
      @cartel = Sprite.new(vp)
      @cartel.bitmap = OstDlg.bmp(CARTEL)
      return if !@cartel.bitmap
      @cartel.z = 2000
    end
    return if !@cartel.bitmap
    w = @cartel.bitmap.width / 3
    cuadro ||= ((Graphics.frame_count / 30) % 2)    # la tecla se enciende y apaga
    @cartel.src_rect = Rect.new(cuadro * w, 0, w, @cartel.bitmap.height)
    @cartel.x = $game_player.screen_x - w / 2
    @cartel.y = $game_player.screen_y - 64 - @cartel.bitmap.height
  end

  #--- sentarse y levantarse --------------------------------------------------
  def self.sentada?; return @sentada; end

  # lleva el desfase de pixel de ch hasta [dx, dy] poco a poco
  def self.deslizar(ch, dx, dy, segundos = 0.3)
    x0 = ch.x_offset
    y0 = ch.y_offset
    pasos = [(segundos * 60).round, 1].max
    pasos.times do |i|
      f = (i + 1).to_f / pasos
      ch.ost_ofs = [(x0 + (dx - x0) * f).round, (y0 + (dy - y0) * f).round]
      OstDlg.tick
    end
  end

  def self.sentarse
    cartel(true, 2)
    OstDlg.esperar(0.15)
    cartel(false)
    x, y, dx, dy = butaca(KAIA[0], KAIA[1])
    $game_player.turn_up
    deslizar($game_player, dx, dy)
    @sentada = true
    lira = ev(ID_LIRA)
    if lira && !$game_switches[SW_SENTADAS]
      lx, ly, ldx, ldy = butaca(LIRA[0], LIRA[1])
      pasos = OstMapa.camino(lira, lx, ly) || []
      OstinatoLaboratorio.mover(lira, pasos + [PBMoveRoute::TURN_UP]) if pasos.length > 0
      lira.moveto(lx, ly)
      lira.turn_up
      deslizar(lira, ldx, ldy)
    end
    $game_switches[SW_SENTADAS] = true
    $game_map.need_refresh = true
    OstDlg.esperar(0.4)
    OstObra.empezar if defined?(OstObra) && OstObra.respond_to?(:empezar)
  end

  def self.levantarse
    deslizar($game_player, 0, desfase($game_player.x, $game_player.y), 0.25)
    $game_player.ost_ofs = nil
    @sentada = false
  end

  def self.en_su_butaca?
    x, y = butaca(KAIA[0], KAIA[1])
    return $game_player.x == x && $game_player.y == y
  end

  def self.pedir(que); @pedido = que; end

  def self.comprobar
    if !en_mapa?
      cartel(false)
      @sentada = false
      return
    end
    return if @corriendo || !$game_player
    poblar
    # una partida guardada con Kaia sentada vuelve con ella de pie
    $game_player.ost_ofs = nil if !@sentada && $game_player.ost_ofs
    libre = !$game_player.moving? && !pbMapInterpreterRunning? &&
            !($game_temp && ($game_temp.message_window_showing || $game_temp.player_transferring ||
                             $game_temp.in_menu))
    que = @pedido
    @pedido = nil
    puede = libre && !@sentada && en_su_butaca?
    cartel(puede)
    que = :sentarse if !que && puede && Input.trigger?(Input::USE)
    return if !que
    @corriendo = true
    begin
      que == :sentarse ? sentarse : levantarse
    ensure
      @corriendo = false
    end
  end
end

class Game_Character
  attr_accessor :ost_ofs       # [dx, dy] de pixel fijos (sentado), o nil
  attr_accessor :ost_pasillo   # se le aplica el desfase de las filas del teatro

  alias ostbut_x_offset x_offset
  def x_offset
    return @ost_ofs[0] if @ost_ofs
    return ostbut_x_offset
  end

  alias ostbut_y_offset y_offset
  def y_offset
    return @ost_ofs[1] if @ost_ofs
    if @ost_pasillo && OstButacas.en_mapa?
      return ostbut_y_offset + OstButacas.desfase_real(self)
    end
    return ostbut_y_offset
  end

  # la z tiene en cuenta el desfase: si no, la gente sentada no quedaria
  # entre su butaca y la fila de atras
  alias ostbut_screen_z screen_z
  def screen_z(height = 0)
    z = ostbut_screen_z(height)
    return z if @always_on_top || @tile_id > 0 || !OstButacas.en_mapa?
    return z + y_offset
  end
end

class Game_Player
  # sentada no se anda: con una direccion, primero se levanta
  alias ostbut_update_command_new update_command_new
  def update_command_new
    if OstButacas.sentada?
      OstButacas.pedir(:levantarse) if Input.dir4 > 0
      return
    end
    ostbut_update_command_new
  end
end

class Game_Map
  # en las filas de butacas solo se anda de lado
  alias ostbut_passable? passable?
  def passable?(x, y, d, *resto)
    if @map_id == OstButacas::MAPA && OstButacas.pasillo?(x, y)
      return d == 4 || d == 6
    end
    return ostbut_passable?(x, y, d, *resto)
  end
end

class Scene_Map
  alias ostbut_update update
  def update
    ostbut_update
    OstButacas.comprobar
  end

  # las capas de butacas se mueven con el mapa, tambien durante las escenas
  alias ostbut_updateSpritesets updateSpritesets
  def updateSpritesets(*args)
    ostbut_updateSpritesets(*args)
    OstButacas.capas
  end
end
