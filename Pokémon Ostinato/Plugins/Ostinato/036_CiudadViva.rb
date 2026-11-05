#===============================================================================
# Pokemon Ostinato - La ciudad del gimnasio (mapa 19), viva
#
#   - Portones: con Enter delante de uno se abre o se cierra, y lo recuerda.
#   - Bancos: delante de uno sale "ENTER SENTARSE"; Kaia se sienta segun como
#     este puesto el banco y se levanta con una direccion o con Enter.
#   - Coches: circulan en sentido unico, se ceden los cruces, frenan cuando
#     Kaia se acerca (y no arrancan hasta que se aleja), giran poco a poco en
#     las esquinas y las barreras del parking suben cuando se acercan.
#   Se buscan por sus casillas en el mapa: se pueden mover en RPG Maker.
#===============================================================================
module OstCiudad
  MAPA = 19
  # filas del tileset 50
  PORTON          = 988    # 5x3
  PORTON_ABIERTO  = 1011   # 5x3
  BARRERA         = 950    # 4x2
  BARRERA_ABIERTA = 952    # 4x3
  BANCO           = 1005   # 3 filas: frente col 0-2, espaldas col 3-5, lados col 6 y 7
  CARTEL = "Graphics/Titles/TeaSentarse.png"
  SONIDO = "Exit Door"

  def self.tile(fila, col); return 384 + fila * 8 + col; end
  def self.en_mapa?; return $game_map && $game_map.map_id == MAPA; end

  #--- que hay en el mapa ---------------------------------------------------------
  def self.buscar
    return if !en_mapa? || @mapa_visto.equal?($game_map.data)
    @mapa_visto = $game_map.data
    @portones = []
    @barreras = []
    d = $game_map.data
    d.xsize.times do |x|
      d.ysize.times do |y|
        3.times do |z|
          @portones.push([x, y, z]) if d[x, y, z] == tile(PORTON, 0)
          @barreras.push([x, y, z, nil]) if d[x, y, z] == tile(BARRERA, 0)
        end
      end
    end
    @portones.each { |p| pintar_porton(p, abierto?(p)) }
    quitar_aparcados
    crear_coches
  end

  # los coches pintados en la calzada estorbarian: se quitan al cargar (los del parking, no)
  def self.quitar_aparcados
    d = $game_map.data
    d.xsize.times do |x|
      (24..28).each do |y|
        3.times do |z|
          i = d[x, y, z]
          d[x, y, z] = 0 if i >= 384 && (i - 384) / 8 >= 887 && (i - 384) / 8 <= 916
        end
      end
    end
  end

  def self.portones; buscar; return @portones || []; end
  def self.barreras; buscar; return @barreras || []; end

  #--- portones -------------------------------------------------------------------
  def self.guardados
    $PokemonGlobal.ost_portones ||= {}
    return $PokemonGlobal.ost_portones
  end

  def self.abierto?(p); return guardados[[p[0], p[1]]] == true; end

  def self.pintar_porton(p, abierto)
    fila = abierto ? PORTON_ABIERTO : PORTON
    3.times do |r|
      5.times { |c| $game_map.data[p[0] + c, p[1] + r, p[2]] = tile(fila + r, c) }
    end
  end

  def self.cambiar_porton(p)
    guardados[[p[0], p[1]]] = !abierto?(p)
    pintar_porton(p, abierto?(p))
    pbSEPlay(SONIDO, 70) rescue nil
  end

  # el porton que tiene delante, si no esta ella en medio (si no, se quedaria encerrada)
  def self.porton_delante
    x, y = delante
    px = $game_player.x
    py = $game_player.y
    portones.each do |p|
      next if py == p[1] + 2 && px >= p[0] && px < p[0] + 5
      return p if y == p[1] + 2 && x > p[0] && x < p[0] + 4
    end
    return nil
  end

  def self.delante
    d = $game_player.direction
    return [$game_player.x + (d == 6 ? 1 : d == 4 ? -1 : 0), $game_player.y + (d == 2 ? 1 : d == 8 ? -1 : 0)]
  end

  #--- barreras -------------------------------------------------------------------
  def self.barrera(i, abierta)
    b = barreras[i]
    return if !b
    x, y, z = b
    d = $game_map.data
    if abierta && !b[3]
      b[3] = []
      3.times do |r|
        4.times do |c|
          t = tile(BARRERA_ABIERTA + r, c)
          xx = x + c
          yy = y - 1 + r
          if r > 0
            d[xx, yy, z] = t
            next
          end
          next if $game_map.priorities[t] == 5    # vacia
          # el brazo sube sobre lo que haya detras (un coche aparcado): va en una capa libre
          zz = ([z] + (0...z).to_a.reverse).find { |k| d[xx, yy, k] == 0 }
          next if !zz
          d[xx, yy, zz] = t
          b[3].push([xx, yy, zz])
        end
      end
    elsif !abierta && b[3]
      b[3].each { |xx, yy, zz| d[xx, yy, zz] = 0 }
      4.times do |c|
        2.times { |r| d[x + c, y + r, z] = tile(BARRERA + r, c) }
      end
      b[3] = nil
    end
  end

  #--- bancos ---------------------------------------------------------------------
  # que parte de banco hay en una casilla: [columna en el banco, fila en el banco]
  def self.banco_en(x, y)
    return nil if !$game_map.valid?(x, y)
    2.downto(0) do |z|
      i = $game_map.data[x, y, z]
      next if i < 384
      f = (i - 384) / 8 - BANCO
      return [(i - 384) % 8, f] if f >= 0 && f < 3
    end
    return nil
  end

  # donde se sienta en el banco que tiene delante: [x, y, direccion, dx, dy]
  def self.asiento
    x, y = delante
    b = banco_en(x, y)
    return nil if !b
    c, f = b
    if c < 3                          # de frente: mira hacia abajo, sobre el asiento
      return [x, y + 2 - f, 2, 0, -8]
    elsif c < 6                       # de espaldas: mira hacia arriba, detras del respaldo
      return [x, y + 1 - f, 8, 0, 6]
    elsif c == 6                      # de lado, con el respaldo a la derecha
      return [x, y + 1 - f, 4, 2, -8]
    end
    return [x, y + 1 - f, 6, -2, -8]  # de lado, con el respaldo a la izquierda
  end

  def self.sentada?; return $PokemonGlobal && $PokemonGlobal.ost_banco != nil; end

  def self.girar(d)
    case d
    when 2 then $game_player.turn_down
    when 4 then $game_player.turn_left
    when 6 then $game_player.turn_right
    else        $game_player.turn_up
    end
  end

  def self.deslizar(dx, dy)
    x0 = $game_player.x_offset
    y0 = $game_player.y_offset
    18.times do |i|
      f = (i + 1) / 18.0
      $game_player.ost_ofs = [(x0 + (dx - x0) * f).round, (y0 + (dy - y0) * f).round]
      OstDlg.tick
    end
  end

  def self.sentarse(a)
    pl = $game_player
    x0 = pl.x
    y0 = pl.y
    d0 = pl.direction
    $PokemonGlobal.ost_banco = [x0, y0, d0]
    cartel(false)
    pl.moveto(a[0], a[1])
    pl.ost_ofs = [(x0 - a[0]) * 32, (y0 - a[1]) * 32]
    deslizar(a[3], a[4])
    girar(a[2])
  end

  def self.levantarse
    pl = $game_player
    x0, y0, d0 = $PokemonGlobal.ost_banco
    deslizar((x0 - pl.x) * 32, (y0 - pl.y) * 32)
    pl.moveto(x0, y0)
    pl.ost_ofs = nil
    girar(d0)
    $PokemonGlobal.ost_banco = nil
  end

  def self.pedir(que); @pedido = que; end

  #--- el cartel "ENTER SENTARSE" -------------------------------------------------
  def self.cartel(ver)
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
      @cartel.z = 2000
    end
    return if !@cartel.bitmap
    w = @cartel.bitmap.width / 3
    @cartel.src_rect = Rect.new(((Graphics.frame_count / 30) % 2) * w, 0, w, @cartel.bitmap.height)
    @cartel.x = $game_player.screen_x - w / 2
    @cartel.y = $game_player.screen_y - 64 - @cartel.bitmap.height
  end

  #--- coches --------------------------------------------------------------------
  # Las calles no caben dos coches de frente: todo es de sentido unico, por el
  # centro de la calle. Hay dos recorridos que no se tocan:
  #   la vuelta de la derecha (con atajo por el parking), que nunca acaba, y
  #   la calle de la izquierda: entra por abajo, se pierde al fondo y vuelve a entrar.
  # Un cruce solo lo usa un coche a la vez y cada uno guarda distancia con el de delante.
  CRUCES = {
    :fondo  => [9, 9],    :oeste  => [9, 27],   :sur    => [39, 27],  :fuera => [39, 45],
    :centro => [49, 27],  :parkin => [57, 27],  :este   => [65, 27],  :ne    => [65, 16],
    :parkno => [57, 16],  :no     => [49, 16]
  }
  RUTAS = {
    :fuera => [:sur], :sur => [:oeste], :oeste => [:fondo], :fondo => [],
    :centro => [:no], :no => [:parkno], :parkno => [:ne, :ne, :parkin], :ne => [:este],
    :este => [:parkin], :parkin => [:centro]
  }
  SALIDAS    = [[:centro, :no, 0.2], [:ne, :este, 0.3], [:este, :parkin, 0.1], [:fuera, :sur, 0.0], [:sur, :oeste, 0.2]]
  COCHES     = 5
  COLORES    = 7
  VELOCIDAD  = 1.5
  EN_CURVA   = 0.85
  ACELERA    = 0.03
  FRENA      = 0.07
  RADIO      = 44.0       # px que ocupa una curva antes y despues del cruce
  HUECO      = 112.0      # de centro a centro, entre dos coches parados
  AVISO      = 170.0      # a cuantos px de un cruce lo pide
  SUELTA     = 124.0      # px pasado el cruce a los que lo deja libre
  ESPERA     = 190.0      # donde espera si el cruce esta ocupado, antes de llegar
  CELDA      = [108, 104]
  LARGO      = { 2 => 45, 8 => 46, 4 => 47, 6 => 47 }   # media longitud de cada vista
  ANCHO      = { 2 => 25, 8 => 25, 4 => 26, 6 => 26 }   # medio ancho
  CUADRO     = { 2 => 0, 4 => 1, 6 => 2, 8 => 3 }
  BARRERA_X  = (54..59)   # casillas donde un coche abre las barreras
  BARRERA_Y  = 4          # a cuantas casillas
  PARA       = 130.0      # Kaia a menos de estos px del morro: se para
  SIGUE      = 200.0      # parado por ella, no arranca hasta que este a mas de estos px
  FRENA_KAIA = 260.0      # a menos de estos px ya va frenando
  INCLINA    = 0.2        # en la curva, cuanto gira cada vista (de los 90 grados del giro)
  ANGULO     = { 6 => 0, 8 => 90, 4 => 180, 2 => -90 }

  class Coche
    attr_accessor :x, :y, :dir, :de, :a, :sig, :s, :t, :v, :color, :espera, :alfa, :sprite, :sprite2, :kaia, :prisa
    def initialize(de, a, f, color)
      @de = de
      @a = a
      @color = color
      @espera = 0
      @alfa = 255
      @v = 0.0
      @t = nil
      @sprite = nil
      @sprite2 = nil
      @kaia = false
      @prisa = 0.85 + rand * 0.25    # no todos van igual de rapido
      @sig = OstCiudad.elegir(a)
      @s = OstCiudad.largo(de, a) * f
      OstCiudad.colocar(self)
    end
  end

  def self.px(c); return [CRUCES[c][0] * 32.0, CRUCES[c][1] * 32.0]; end
  def self.coches; return @coches || []; end

  def self.elegir(n)
    r = RUTAS[n]
    return r.empty? ? nil : r[rand(r.length)]
  end

  def self.largo(de, a)
    ax, ay = px(de)
    bx, by = px(a)
    return [(bx - ax).abs, (by - ay).abs].max
  end

  def self.rumbo(de, a)
    ax, ay = px(de)
    bx, by = px(a)
    return 6 if bx > ax
    return 4 if bx < ax
    return by > ay ? 2 : 8
  end

  def self.gira?(c); return c.sig != nil && rumbo(c.de, c.a) != rumbo(c.a, c.sig); end

  # donde esta y hacia donde mira, en la recta o en la curva del cruce
  def self.colocar(c)
    ax, ay = px(c.de)
    bx, by = px(c.a)
    l = largo(c.de, c.a)
    ux = (bx - ax) / l
    uy = (by - ay) / l
    if c.t
      nx, ny = px(c.sig)
      m = largo(c.a, c.sig)
      vx = (nx - bx) / m
      vy = (ny - by) / m
      i = c.t
      j = 1 - i
      x0 = bx - ux * RADIO
      y0 = by - uy * RADIO
      x2 = bx + vx * RADIO
      y2 = by + vy * RADIO
      c.x = j * j * x0 + 2 * j * i * bx + i * i * x2
      c.y = j * j * y0 + 2 * j * i * by + i * i * y2
      c.dir = i < 0.5 ? rumbo(c.de, c.a) : rumbo(c.a, c.sig)
    else
      c.x = ax + ux * c.s
      c.y = ay + uy * c.s
      c.dir = rumbo(c.de, c.a)
    end
  end

  def self.crear_coches
    soltar_coches
    @cruces = {}
    @coches = []
    colores = (0...COLORES).to_a.shuffle
    SALIDAS.first(COCHES).each_with_index do |e, i|
      c = Coche.new(e[0], e[1], e[2], colores[i % COLORES])
      c.espera = 300 if e[0] == :fuera
      @coches.push(c)
    end
  end

  def self.soltar_coches
    coches.each do |c|
      OstDlg.soltar(c.sprite) if c.sprite
      OstDlg.soltar(c.sprite2) if c.sprite2
    end
    @coches = nil
    @cruces = nil
    @vp_coches = nil
  end

  # Kaia cerca del morro (delante o al lado, en la calzada o en la acera): el coche
  # frena y se para, y no arranca hasta que ella se aleja (SIGUE > PARA). Si ya la
  # ha dejado atras, no le afecta. Devuelve los px que puede avanzar por ella, o nil.
  def self.por_kaia(c)
    pl = $game_player
    # su posicion de verdad (no la casilla a la que va): asi frena y arranca sin saltos al andar
    kx = pl.real_x.to_f / Game_Map::X_SUBPIXELS + 16
    ky = pl.real_y.to_f / Game_Map::Y_SUBPIXELS + 16
    ux = c.dir == 6 ? 1 : c.dir == 4 ? -1 : 0
    uy = c.dir == 2 ? 1 : c.dir == 8 ? -1 : 0
    if (kx - c.x) * ux + (ky - c.y) * uy < -LARGO[c.dir]
      c.kaia = false
      return nil
    end
    fx = c.x + ux * LARGO[c.dir]
    fy = c.y + uy * LARGO[c.dir]
    d = Math.sqrt((kx - fx) ** 2 + (ky - fy) ** 2)
    c.kaia = c.kaia ? d < SIGUE : d < PARA
    return 0.0 if c.kaia
    return d < FRENA_KAIA ? d - PARA : nil
  end

  # cuantos px puede avanzar antes de tener que estar parado
  def self.libre(c)
    l = largo(c.de, c.a)
    resto = c.t ? 0.0 : l - c.s
    g = 9999.0
    g = [g, resto].min if !c.sig
    if c.sig && !c.t
      @cruces[c.a] = c if resto < AVISO && !@cruces[c.a]
      g = [g, resto - ESPERA + 60].min if !@cruces[c.a].equal?(c)
    end
    coches.each do |o|
      next if o.equal?(c) || o.espera > 0
      if o.de == c.de && o.a == c.a && !c.t
        d = (o.t ? l : o.s) - c.s
        g = [g, d - HUECO].min if d > 0
      elsif c.sig && o.de == c.a && o.a == c.sig
        g = [g, resto + (o.t ? largo(o.de, o.a) : o.s) - HUECO].min
      end
    end
    k = por_kaia(c)
    g = [g, k].min if k
    return g
  end

  def self.soltar_cruce(c)
    n = c.de
    @cruces[n] = nil if @cruces[n].equal?(c) && !c.t && c.s > SUELTA
  end

  def self.mover_coches
    coches.each do |c|
      if c.espera > 0
        c.espera -= 1
        next
      end
      g = libre(c)
      tope = VELOCIDAD * c.prisa
      tope = EN_CURVA if c.t || (gira?(c) && largo(c.de, c.a) - c.s < 90)
      quiere = g <= 0 ? 0.0 : [tope, g * 0.035].min
      if quiere > c.v
        c.v = [c.v + ACELERA, quiere].min
      else
        c.v = [c.v - FRENA, quiere].max
      end
      c.v = 0.0 if g <= 0 && c.v < 0.2
      avanzar(c)
      soltar_cruce(c)
      c.alfa = c.a == :fondo ? [[(largo(c.de, c.a) - c.s) * 5, 255].min, 0].max.to_i : 255
    end
    barreras.each_with_index do |b, i|
      cerca = coches.any? do |c|
        c.espera == 0 && BARRERA_X.include?((c.x / 32).to_i) && ((c.y / 32).to_i - b[1]).abs <= BARRERA_Y
      end
      barrera(i, cerca)
    end
  end

  def self.avanzar(c)
    l = largo(c.de, c.a)
    if c.t
      c.t += c.v / (RADIO * 1.8)
      if c.t >= 1
        c.t = nil
        cambiar_tramo(c, RADIO)
      end
    else
      c.s += c.v
      if c.s >= l
        if c.sig
          cambiar_tramo(c, c.s - l)
        else
          volver(c)
          return
        end
      elsif gira?(c) && c.s >= l - RADIO
        c.t = 0.0
      end
    end
    colocar(c)
  end

  def self.cambiar_tramo(c, s)
    c.de, c.a = c.a, c.sig
    c.sig = elegir(c.a)
    c.s = s
  end

  # se ha perdido al fondo de la calle: vuelve a entrar por abajo al rato
  def self.volver(c)
    c.de = :fuera
    c.a = :sur
    c.sig = elegir(:sur)
    c.s = 0.0
    c.v = 0.0
    c.t = nil
    c.alfa = 255
    c.espera = 240 + rand(360)
    colocar(c)
  end

  # el jugador no se mete donde hay un coche
  def self.coche_en?(x, y)
    return false if !en_mapa?
    px_x = x * 32 + 16
    px_y = y * 32 + 16
    coches.any? do |c|
      next false if c.espera > 0
      lx = [2, 8].include?(c.dir) ? ANCHO[c.dir] : LARGO[c.dir]
      ly = [2, 8].include?(c.dir) ? LARGO[c.dir] : ANCHO[c.dir]
      (px_x - c.x).abs < lx + 12 && (px_y - c.y).abs < ly + 12
    end
  end

  def self.pintar_coches
    if !en_mapa?
      soltar_coches if @coches
      return
    end
    vp = (Spriteset_Map.viewport rescue nil)
    return if !vp || vp.disposed? || !@coches
    if @vp_coches != vp
      @coches.each do |c|
        c.sprite = nil
        c.sprite2 = nil
      end
      @vp_coches = vp
    end
    ox = $game_map.display_x.to_f / Game_Map::X_SUBPIXELS
    oy = $game_map.display_y.to_f / Game_Map::Y_SUBPIXELS
    @coches.each do |c|
      c.sprite = vista_coche(vp, c) if !c.sprite || c.sprite.disposed?
      c.sprite2 = vista_coche(vp, c) if !c.sprite2 || c.sprite2.disposed?
      # en la curva no cambia de vista de golpe: la vieja se inclina hacia el giro y la
      # nueva aparece encima, inclinada al reves, hasta quedar recta
      d1 = c.dir
      d2 = nil
      w = 0.0
      giro = 0
      if c.t && c.sig
        d1 = rumbo(c.de, c.a)
        d2 = rumbo(c.a, c.sig)
        w = [[(c.t - 0.2) / 0.6, 0.0].max, 1.0].min
        w = w * w * (3 - 2 * w)
        giro = (ANGULO[d2] - ANGULO[d1] + 540) % 360 - 180
      end
      alto = [2, 8].include?(c.dir) ? LARGO[c.dir] : ANCHO[c.dir]
      z = (c.y + alto - oy).round + 31
      [[c.sprite, d1, giro * INCLINA * w, c.alfa], [c.sprite2, d2, -giro * INCLINA * (1 - w), c.alfa * w]].each_with_index do |e, i|
        sp, d, ang, op = e
        sp.visible = c.espera == 0 && d != nil && op > 0
        next if !sp.visible
        sp.opacity = op.to_i
        sp.angle = ang
        sp.src_rect = Rect.new(CUADRO[d] * CELDA[0], 0, CELDA[0], CELDA[1])
        sp.x = (c.x - ox).round
        sp.y = (c.y - oy).round
        sp.z = z + i
      end
    end
  end

  def self.vista_coche(vp, c)
    sp = Sprite.new(vp)
    sp.bitmap = OstDlg.bmp("Graphics/Pictures/Coches/coche_#{c.color}.png")
    sp.ox = CELDA[0] / 2
    sp.oy = CELDA[1] / 2
    return sp
  end

  #--- cada fotograma -------------------------------------------------------------
  def self.comprobar
    if !en_mapa? || !$game_player
      cartel(false)
      soltar_coches if @coches
      @mapa_visto = nil
      return
    end
    return if @corriendo
    buscar
    mover_coches
    libre = !$game_player.moving? && !pbMapInterpreterRunning? &&
            !($game_temp && ($game_temp.message_window_showing || $game_temp.player_transferring ||
                             $game_temp.in_menu))
    que = @pedido
    @pedido = nil
    if sentada?
      cartel(false)
      que = :levantarse if libre && Input.trigger?(Input::USE)
      return if que != :levantarse || !libre
      correr { levantarse }
      return
    end
    a = libre ? asiento : nil
    cartel(a != nil)
    return if !libre || !Input.trigger?(Input::USE)
    if a
      correr { sentarse(a) }
    elsif (p = porton_delante)
      cambiar_porton(p)
    end
  end

  def self.correr
    @corriendo = true
    begin
      yield
    ensure
      @corriendo = false
    end
  end
end

class PokemonGlobalMetadata
  attr_accessor :ost_portones   # {[x, y] => true} los portones abiertos del mapa 19
  attr_accessor :ost_banco      # [x, y, direccion] de donde se levantara Kaia, o nil
end

class Game_Player
  # sentada en un banco no se anda: con una direccion, se levanta
  alias ostciu_update_command_new update_command_new
  def update_command_new
    if OstCiudad.sentada?
      OstCiudad.pedir(:levantarse) if Input.dir4 > 0
      return
    end
    ostciu_update_command_new
  end
end

class Game_Player
  alias ostciu_passable? passable?
  def passable?(x, y, dir, strict = false)
    nx = x + (dir == 6 ? 1 : dir == 4 ? -1 : 0)
    ny = y + (dir == 2 ? 1 : dir == 8 ? -1 : 0)
    return false if OstCiudad.coche_en?(nx, ny)
    return ostciu_passable?(x, y, dir, strict)
  end
end

class Scene_Map
  alias ostciu_update update
  def update
    ostciu_update
    OstCiudad.comprobar
  end

  alias ostciu_updateSpritesets updateSpritesets
  def updateSpritesets(*args)
    ostciu_updateSpritesets(*args)
    OstCiudad.pintar_coches
  end
end
