#===============================================================================
# Pokemon Ostinato - La funcion del Teatrinho de Villa Bambalina:
# "La primera nota" (version 6, 2026-10-12)
#
#   Es la intro del juego (la pelicula de marionetas) puesta en el escenario
#   del teatro, con la misma narracion palabra por palabra y con Pipo (el nino)
#   en lugar de Kaia al final: el nucleo, las seis esferas, los Resonantes
#   colgados de sus hilos, los primeros hombres y mujeres (marionetas de
#   madera), los Silenciadores, y la nota que no se calla.
#
#   Cuando Kaia y Lira se sientan (024_ButacasTeatro), la pantalla pasa a
#   1920x1080 y se ve el escenario de frente. El escenario es el del mapa 13
#   (Obra2/escenario.png) ampliado x3.75. Encima: el telon (dos mitades que se
#   recogen), los fondos pintados (cima de noche, monte), las estrellas, y los
#   actores, que son skins de 64x64 como la de Kaia, todos con sus hilos.
#
#   REGLA: nadie se pone delante de nadie. Cada actor tiene su marca (GENTE,
#   RESONANTES, SOMBRAS) y solo se mueve en vertical, colgado, o hasta su marca.
#
#   Al volver al mapa, Tacet se levanta de la primera fila: "Seis. Siempre
#   seis..." (TacTxt) y se va. Interruptores: 83 obra vista, 91 Tacet se ha ido.
#   Textos: recursos/guion_bambalina_teatro.txt (ObraTxt, ObraPub00, TeaTxt13-16,
#   TacTxt). Piezas: Graphics/Titles/Obra2 (de Descargas\obra2, por Claude).
#===============================================================================
module OstObra
  DIR      = "Graphics/Titles/Obra2/"
  VIEJO    = "Graphics/Titles/Obra/"
  PKS      = "Graphics/Characters/Followers/"
  TEXTOS   = "Graphics/Titles/"
  SW_VISTA = 83

  ESC     = 3.75          # pixel de skin -> pantalla
  SUELO   = 945           # pies en primer termino
  ATRAS   = 690           # pies junto al decorado (umbral de las puertas)
  TELON_Y = 851
  PUERTA  = { :izq => 544, :der => 1438 }
  TELON_IZQ = [94, 44]
  TELON_DER = [254, 44]
  CENEFA    = [94, 44]
  CIELO     = 590         # donde quedan los pies de los Resonantes, colgados
  ESC_RES   = 0.8         # tamano de los Resonantes (se igualan todos a una celda de 64)
  # el arco en que cuelgan: los del centro mas altos
  RES_Y     = [40, -5, -35, -35, -5, 40]
  ESC_MAR   = 4.4         # las marionetas: celda de 56 con mas detalle, a la altura de Kaia

  # las marcas: nadie se sale de la suya (x de la pantalla con la camara abierta)
  RESONANTES = [
    # Pokemon,   x,    color de su esfera
    ["CRESSELIA", 529,  [248, 132, 186]],   # amor
    ["DARKRAI",   695,  [160, 92, 220]],    # miedo
    ["ZAPDOS",    879,  [255, 214, 64]],    # alegria
    ["MEWTWO",    1045, [76, 146, 240]],    # calma
    ["YVELTAL",   1209, [236, 64, 56]],     # ira
    ["LUNALA",    1392, [88, 206, 100]]     # asombro
  ]
  NOTAS_RES = [1, 2, 3, 5, 6, 8]
  GENTE = { :mar0 => 490, :mar1 => 670, :pipo => 870, :pichu => 1030, :mar2 => 1230, :mar3 => 1430 }
  SOMBRAS = [345, 1575]          # a los lados, fuera de la fila de la gente

  # cuadros de las tiras
  M_QUIETO = 0; M_ARRIBA = 5; M_CAIDO = 6; M_ESPALDA = 7
  H_QUIETO = 0; H_ARRIBA = 1; H_SALTA = 2; H_BUSCA = 3; H_CAIDO = 4; H_SENTADO = 5; H_ABRAZA = 6

  SALA     = [0, 0, 0, 0]
  PENUMBRA = [-150, -150, -125, 70]
  VACIO    = [-170, -165, -110, 20]
  COSMOS   = [-120, -115, -60, 10]
  VALLE    = [-25, -35, -50, 0]
  CANTO    = [-10, -15, -35, 0]
  SILENCIO = [-90, -90, -80, 255]
  OSCURO   = [-150, -150, -125, 200]

  TACET_SKIN  = "villana"
  TACET_ARTES = { "izq" => ["DlgTacet.png", 40, 465, "DlgNomTacet"] }
  TACET_TEXTO = ["TacTxt00", "TacTxt01", "TacTxt02", "TacTxt03"]

  ARTES = {
    "izq" => ["DlgLira.png", 174, 465, "DlgNomLira"],
    "der" => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }

  #-----------------------------------------------------------------------------
  # La camara
  #-----------------------------------------------------------------------------
  class Camara
    attr_reader :z
    def initialize
      @cx = 960.0; @cy = 540.0; @z = 1.0
      @mov = nil; @temblor = 0.0; @dx = @dy = 0
    end

    def a(cx, cy, z, seg)
      @mov = [@cx, @cy, @z, cx.to_f, cy.to_f, z.to_f, 0, [(seg * 60).round, 1].max]
    end

    def temblar(fuerza); @temblor = fuerza.to_f; end
    def moviendo?; return !@mov.nil?; end

    def update
      if @mov
        x0, y0, z0, x1, y1, z1, t, n = @mov
        t += 1
        f = OstMini.suave(t.to_f / n)
        @cx = x0 + (x1 - x0) * f; @cy = y0 + (y1 - y0) * f; @z = z0 + (z1 - z0) * f
        @mov[6] = t
        @mov = nil if t >= n
      end
      mx = 960.0 / @z; my = 540.0 / @z
      @cx = [[@cx, mx].max, 1920 - mx].min
      @cy = [[@cy, my].max, 1080 - my].min
      @dx = @dy = 0
      if @temblor > 0.5
        @dx = (rand * 2 - 1) * @temblor; @dy = (rand * 2 - 1) * @temblor
        @temblor *= 0.88
      end
    end

    def x(wx); return ((wx - @cx) * @z + 960 + @dx).round; end
    def y(wy); return ((wy - @cy) * @z + 540 + @dy).round; end
  end

  #-----------------------------------------------------------------------------
  # Un actor: tira de cuadros (o dibujo suelto), anclado por los pies. Puede
  # llevar hilos de marioneta que suben hasta el techo.
  #-----------------------------------------------------------------------------
  class Actor
    attr_accessor :x, :y, :esc, :pose, :espejo, :op, :salto, :aleteo, :hilos, :tension, :luz_propia, :vaiven
    attr_reader :sprite, :cuadro

    def initialize(vp, ruta, cuadro = 64, escala = ESC, filas = 1)
      @sprite = Sprite.new(vp)
      @sprite.bitmap = OstMini.bmp(ruta)
      bm = @sprite.bitmap
      @w = cuadro ? cuadro : (bm ? bm.width : 1)
      @h = bm ? (filas > 1 ? bm.height / filas : bm.height) : 1
      @h = cuadro if cuadro && filas == 1 && bm && bm.height == cuadro
      @n = bm ? [bm.width / @w, 1].max : 1
      @escala = escala
      @sprite.ox = @w / 2
      @sprite.oy = cuadro ? [@h - 2, 1].max : @h
      @x = -999; @y = SUELO; @esc = 1.0; @pose = 0; @espejo = false
      @op = 0; @salto = 0; @t = rand(600)
      @mov = nil; @fade = nil; @bote = 0
      @aleteo = false; @hilos = 0; @tension = 1.0; @luz_propia = 0.0; @vaiven = 0.0
      @cuadro = 0
      @top = buscar_top(bm)
      @cuerdas = []
    end

    # la primera fila con algo dibujado del primer cuadro (para atar los hilos)
    def buscar_top(bm)
      return 0 if !bm
      @h.times do |yy|
        (0...@w).step(2) { |xx| return yy if bm.get_pixel(xx, yy).alpha > 0 }
      end
      return 0
    end

    def ir(x, y = nil, seg = nil, curva = :suave)
      y ||= @y
      seg ||= [((x - @x).abs + (y - @y).abs) / 260.0, 0.3].max
      @mov = [@x, @y, x.to_f, y.to_f, 0, [(seg * 60).round, 1].max, curva]
    end
    def parar; @mov = nil; end
    def fundir(op, seg = 0.4); @fade = [@op, op, 0, [(seg * 60).round, 1].max]; end
    def moviendo?; return !@mov.nil?; end
    def bote(px); @bote = px.to_f; end

    def update(cam, tono, vp)
      @t += 1
      if @mov
        x0, y0, x1, y1, t, n, curva = @mov
        t += 1
        f = t.to_f / n
        f = curva == :cae ? OstMini.rebote(f) : (curva == :lineal ? f : OstMini.suave(f))
        @x = x0 + (x1 - x0) * f; @y = y0 + (y1 - y0) * f
        @mov[4] = t
        @mov = nil if t >= n
      end
      if @fade
        o0, o1, t, n = @fade
        t += 1; @op = o0 + (o1 - o0) * t.to_f / n; @fade[2] = t
        @fade = nil if t >= n
      end
      if @bote > 0.5
        @salto = -@bote; @bote *= 0.8
      else
        @salto = 0
      end
      # flotar y balancearse colgado
      flota = @hilos > 0 ? Math.sin(@t / 40.0) * 3 * @tension : 0
      flota += Math.sin(@t / 25.0) * @vaiven
      c = @aleteo ? (@t / 9) % [@n, 4].min : @pose
      @cuadro = [[c, 0].max, @n - 1].min
      s = @sprite
      return if !s.bitmap
      s.update
      s.src_rect.set(@cuadro * @w, 0, @w, @h)
      s.mirror = @espejo
      s.x = cam.x(@x)
      s.y = cam.y(@y + (@salto + flota) * @esc)
      s.zoom_x = s.zoom_y = @escala * @esc * cam.z
      s.opacity = @op
      s.z = 100 + @y.round
      k = 1.0 - @luz_propia
      s.tone.set(tono[0] * k, tono[1] * k, tono[2] * k, tono[3] * k)
      cuerdas(cam, vp, flota)
    end

    # los hilos: del techo (fuera de la pantalla) a la cabeza y a las manos
    def cuerdas(cam, vp, flota)
      while @cuerdas.size < @hilos
        c = Sprite.new(vp); c.bitmap = OstObra.bmp_hilo
        @cuerdas.push(c)
      end
      return if @cuerdas.empty?
      e = @escala * @esc
      pies = @y + (@salto + flota) * @esc
      cabeza = pies - (@h - 2 - @top) * e
      sep = [@w * 0.22, 14].min * e
      @cuerdas.each_with_index do |c, i|
        visible = i < @hilos && @op > 0
        visible = false
        c.visible = visible
        next if !visible
        dx = @hilos == 1 ? 0 : (i == 0 ? -sep : sep)
        floja = (1.0 - @tension) * 18 * (i == 0 ? -1 : 1)
        top = cam.y(-400)
        c.x = cam.x(@x + dx + floja)
        c.y = top
        c.zoom_x = [cam.z * 1.5, 1].max
        c.zoom_y = [cam.y(cabeza + 6) - top, 1].max
        c.opacity = @op * (0.3 + 0.45 * @tension)
        c.z = 99 + @y.round
      end
    end

    def dispose
      OstMini.soltar(@sprite)
      @cuerdas.each { |c| begin; c.dispose; rescue; end }
    end
  end

  def self.bmp_hilo
    if !@bmp_hilo || @bmp_hilo.disposed?
      @bmp_hilo = Bitmap.new(1, 1); @bmp_hilo.set_pixel(0, 0, Color.new(232, 222, 196))
    end
    return @bmp_hilo
  end

  #-----------------------------------------------------------------------------
  # La funcion
  #-----------------------------------------------------------------------------
  def self.empezar
    return if $game_switches[SW_VISTA]
    $game_switches[SW_VISTA] = true
    begin
      OstMini.pantalla(nil) { |vp, telon| funcion(vp, telon) }
      tacet
    rescue StandardError => e
      echoln("OstObra: #{e.class}: #{e.message}\n#{e.backtrace[0, 5].join("\n")}") rescue nil
    end
  end

  #-----------------------------------------------------------------------------
  # Tacet, en la primera fila: la de esa butaca era ella todo el rato
  #-----------------------------------------------------------------------------
  def self.tacet
    return if $game_switches[OstButacas::SW_TACET]
    return if !$game_map || $game_map.map_id != OstButacas::MAPA
    k, j = OstButacas::TACET
    g = $game_map.events[OstButacas::ID_GENTE + k * 10 + j]
    return if !g
    g.character_name = TACET_SKIN
    OstDlg.esperar(0.8)
    x, y = OstButacas.butaca(k, j)
    g.ost_pasillo = true
    OstButacas.deslizar(g, 0, OstButacas.desfase(x, y), 0.35)
    g.ost_ofs = nil
    g.instance_variable_set(:@direction_fix, false)
    g.instance_variable_set(:@walk_anime, true)
    g.turn_down
    OstDlg.esperar(0.5)
    OstDlg.run(TACET_TEXTO.map { |c| [c, "izq"] }, TACET_ARTES)
    g.through = false
    pasos = OstMapa.camino(g, 14, 18) || []
    g.through = true
    OstinatoLaboratorio.mover(g, pasos + [PBMoveRoute::DOWN])
    $game_switches[OstButacas::SW_TACET] = true
    OstMapa.quitar(g)
  end

  def self.funcion(vp, telon)
    @vp = vp; @telon = telon
    @cam = Camara.new
    @tono = SALA.map(&:to_f); @tono_mov = nil
    @actores = []; @halos = []; @notas = []; @estrellas = []; @rayos = []
    @cada = nil
    @escenario = Sprite.new(vp)
    @escenario.bitmap = OstMini.bmp(DIR + "escenario.png")
    @escenario.z = 0
    @fondos = {}
    ["cosmos", "valle", "cima"].each do |n|
      s = Sprite.new(vp); s.bitmap = OstMini.bmp(DIR + "fondo_#{n}.png"); s.z = 1; s.opacity = 0
      @fondos[n] = [s, 0.0, 0.0]
    end
    # el vacio: el decorado del fondo pintado de negro azulado
    @vacio = Sprite.new(vp); @vacio.bitmap = OstMini.bmp(DIR + "fondo_cima.png"); @vacio.z = 2
    @vacio.color.set(6, 6, 18, 255); @vacio.opacity = 0; @vacio_op = 0.0; @vacio_obj = 0.0
    @tela = {}
    { :izq => TELON_IZQ, :der => TELON_DER }.each do |lado, pos|
      s = Sprite.new(vp); s.bitmap = OstMini.bmp(DIR + "telon_#{lado}.png")
      s.z = 100 + TELON_Y
      s.ox = lado == :izq ? 0 : s.bitmap.width
      @tela[lado] = [s, lado == :izq ? pos[0] : pos[0] + s.bitmap.width, pos[1]]
    end
    @abierto = 0.0; @telon_mov = nil
    @cenefa = Sprite.new(vp); @cenefa.bitmap = OstMini.bmp(DIR + "cenefa.png"); @cenefa.z = 1150
    @foco = Sprite.new(vp); @foco.bitmap = OstMini.bmp(VIEJO + "foco.png")
    @foco.ox = 480; @foco.oy = 270; @foco.z = 1500; @foco.opacity = 0
    @foco_a = nil; @foco_op = 0.0; @foco_mov = nil; @foco_esc = 1.0
    @cono = Sprite.new(vp); @cono.bitmap = bmp_cono; @cono.ox = 64; @cono.oy = 256; @cono.blend_type = 1; @cono.z = 1510; @cono.opacity = 0
    @vineta = Sprite.new(vp); @vineta.bitmap = bmp_vineta; @vineta.zoom_x = 20; @vineta.zoom_y = 20; @vineta.z = 1600
    # polvo que flota en la luz
    @polvo = []; @polvo_op = 0.0; @polvo_obj = 0.0
    40.times do
      s = Sprite.new(vp); s.bitmap = bmp_estrella; s.ox = 1; s.oy = 1; s.blend_type = 1; s.z = 1360; s.opacity = 0
      @polvo.push([s, 380 + rand(1160), 200 + rand(760), rand * 6.28, 0.2 + rand * 0.5])
    end
    @blanco = Sprite.new(vp); @blanco.bitmap = Bitmap.new(32, 32)
    @blanco.bitmap.fill_rect(0, 0, 32, 32, Color.new(255, 252, 240))
    @blanco.zoom_x = 60; @blanco.zoom_y = 34; @blanco.z = 1700; @blanco.opacity = 0; @blanco_op = 0.0
    @banda = Sprite.new(vp); @banda.bitmap = OstMini.bmp(VIEJO + "banda.png")
    @banda.y = 1080 - 230; @banda.z = 1800; @banda.opacity = 0
    @sub = Sprite.new(vp); @sub.z = 1810; @sub.opacity = 0
    @flecha = Sprite.new(vp); @flecha.bitmap = OstMini.bmp(TEXTOS + "DlgFlecha.png")
    @flecha.z = 1820; @flecha.opacity = 0
    if @flecha.bitmap
      @flecha.ox = @flecha.bitmap.width / 2; @flecha.oy = @flecha.bitmap.height / 2
      @flecha.zoom_x = @flecha.zoom_y = 0.8
    end
    begin; $game_system.bgm_memorize; rescue; end
    @telon.z = 3000
    @mus = nil
    @parts = []; @ondas = []
    montar
    montar_niebla
    tick
    obra
  ensure
    begin; $game_system.bgm_restore; rescue; end
    (@actores || []).each { |a| a.dispose }
    (@halos || []).each { |h| begin; h[0].dispose; rescue; end }
    (@parts || []).each { |p| begin; p[0].dispose; rescue; end }
    (@ondas || []).each { |o| begin; o[0].dispose; rescue; end }
    (@niebla || []).each { |n| begin; n[0].dispose; rescue; end }
    @parts = @ondas = @niebla = nil
    @bmp_confeti.dispose if @bmp_confeti && !@bmp_confeti.disposed?
    @bmp_confeti = nil
    (@polvo || []).each { |p| begin; p[0].dispose; rescue; end }
    [@cono, @vineta].each { |s| begin; s.dispose if s; rescue; end }
    [@bmp_glow, @bmp_cono].each { |b| b.dispose if b && !b.disposed? }
    @bmp_glow = @bmp_cono = nil
    (@notas || []).each { |n| OstMini.soltar(n[0]) }
    (@estrellas || []).each { |n| begin; n[0].dispose; rescue; end }
    (@rayos || []).each { |r| begin; r[0].dispose; rescue; end }
    (@fondos || {}).each_value { |f| OstMini.soltar(f[0]) }
    (@tela || {}).each_value { |t| OstMini.soltar(t[0]) }
    [@escenario, @vacio, @cenefa, @foco, @blanco, @banda, @sub, @flecha].each { |s| OstMini.soltar(s) }
    [@bmp_hilo, @bmp_estrella, @bmp_rayo].each { |b| b.dispose if b && !b.disposed? }
    @bmp_hilo = @bmp_estrella = @bmp_rayo = nil
    @cada = nil
  end

  def self.actor(ruta, cuadro = 64, escala = ESC)
    a = Actor.new(@vp, ruta, cuadro, escala)
    @actores.push(a)
    return a
  end

  # un halo de color pegado a un actor: [sprite, actor, opacidad, objetivo, dy, radio]
  def self.halo(a, rgb, radio, dy)
    h = Sprite.new(@vp); h.bitmap = bmp_glow; h.ox = h.oy = 64; h.blend_type = 1; h.opacity = 0
    h.color.set(rgb[0], rgb[1], rgb[2], 110)
    reg = [h, a, 0.0, 0.0, dy, radio]
    @halos.push(reg)
    return reg
  end

  def self.brillo_de(a, op)
    @halos.each { |h| h[3] = op.to_f if h[1].equal?(a) }
  end

  def self.montar
    # el nucleo y las esferas
    @nucleo = actor(DIR + "nucleo_a.png", nil, ESC * 0.9)
    @nucleo_roto = actor(DIR + "nucleo_b.png", nil, ESC * 0.9)
    [@nucleo, @nucleo_roto].each { |n| n.x = 960; n.y = 640; n.hilos = 1 }
    @h_nucleo = halo(@nucleo, [255, 236, 190], 330, -190)
    @esferas = RESONANTES.map do |_pk, _x, rgb|
      e = actor(DIR + "esfera.png", nil, ESC * 1.1)
      e.sprite.color.set(rgb[0], rgb[1], rgb[2], 150)
      e.hilos = 1
      halo(e, rgb, 90, -35)
      e
    end
    @gota = actor(DIR + "esfera.png", nil, ESC * 0.5)
    @h_gota = halo(@gota, [255, 255, 255], 70, -15)
    # los Resonantes, colgados
    @res = RESONANTES.map do |pk, x, rgb|
      bm = OstMini.bmp(PKS + pk + ".png")
      celda = bm ? bm.width / 4 : 64
      bm.dispose if bm
      k = 64.0 / celda * (celda > 64 ? 1.15 : 1.0)
      r = Actor.new(@vp, PKS + pk + ".png", celda, ESC * ESC_RES * k, 4)
      @actores.push(r)
      r.x = x; r.y = -200; r.aleteo = true; r.hilos = 2
      halo(r, rgb, 190, -75)
      r
    end
    # la gente: marionetas de madera, Pipo y Pichu
    @mar = (0..3).map { |i| actor(DIR + "mar#{i}.png", 56, ESC_MAR) }
    @pipo = actor(DIR + "heroe.png", 56, ESC_MAR)
    @pichu = actor(DIR + "pk_pichu.png")
    @gente = { :mar0 => @mar[0], :mar1 => @mar[1], :pipo => @pipo, :pichu => @pichu, :mar2 => @mar[2], :mar3 => @mar[3] }
    @gente.each { |k, a| a.x = GENTE[k]; a.y = SUELO; a.hilos = (k == :pichu ? 1 : 2) }
    @h_pipo = halo(@pipo, [255, 244, 210], 150, -110)
    destinos = [@mar[0], @mar[1], @pipo, @pichu, @mar[2], @mar[3]]
    destinos.each_with_index { |d, i| next if d.equal?(@pipo); halo(d, RESONANTES[i][2], 130, -90) }
    # los Silenciadores
    @sombras = SOMBRAS.map { |x| s = actor(DIR + "silenciador.png"); s.x = x; s.y = SUELO - 30; s.hilos = 2; s.vaiven = 6; s }
    # estrellas del fondo
    eb = bmp_estrella
    26.times do
      s = Sprite.new(@vp); s.bitmap = eb; s.ox = 1; s.oy = 1; s.z = 3; s.blend_type = 1; s.opacity = 0
      @estrellas.push([s, (100 + rand(320)) * ESC, (45 + rand(90)) * ESC, rand * 6.28])
    end
  end

  def self.bmp_estrella
    if !@bmp_estrella || @bmp_estrella.disposed?
      @bmp_estrella = Bitmap.new(3, 3)
      [[1, 0], [0, 1], [1, 1], [2, 1], [1, 2]].each { |x, y| @bmp_estrella.set_pixel(x, y, Color.new(255, 255, 255)) }
    end
    return @bmp_estrella
  end

  def self.ry(i); return CIELO + RES_Y[i]; end

  # halo suave: degradado radial de 128 (sin anillos)
  def self.bmp_glow
    if !@bmp_glow || @bmp_glow.disposed?
      @bmp_glow = Bitmap.new(128, 128)
      128.times do |x|
        128.times do |y|
          d = Math.sqrt((x - 63.5) ** 2 + (y - 63.5) ** 2) / 64.0
          next if d >= 1.0
          a = (1.0 - d) ** 2.2
          @bmp_glow.set_pixel(x, y, Color.new(255, 255, 255, (a * 255).round))
        end
      end
    end
    return @bmp_glow
  end

  # rayo con cuerpo: 32 de ancho, brillante en el centro y difuso a los lados
  def self.bmp_rayo
    if !@bmp_rayo || @bmp_rayo.disposed?
      @bmp_rayo = Bitmap.new(32, 8)
      32.times do |x|
        a = Math.exp(-((x - 15.5) / 6.0) ** 2)
        8.times { |y| @bmp_rayo.set_pixel(x, y, Color.new(255, 246, 220, (a * 255).round)) }
      end
    end
    return @bmp_rayo
  end

  # cono de foco: estrecho arriba, ancho abajo, se desvanece hacia los bordes
  def self.bmp_cono
    if !@bmp_cono || @bmp_cono.disposed?
      @bmp_cono = Bitmap.new(128, 256)
      256.times do |y|
        f = y / 255.0
        media = 10 + 54 * f
        128.times do |x|
          d = (x - 63.5).abs / media
          next if d >= 1.0
          a = (1.0 - d) ** 1.5 * (0.35 + 0.65 * f)
          @bmp_cono.set_pixel(x, y, Color.new(255, 244, 214, (a * 150).round))
        end
      end
    end
    return @bmp_cono
  end

  # vineta: los bordes de la pantalla un poco mas oscuros
  def self.bmp_vineta
    b = Bitmap.new(96, 54)
    96.times do |x|
      54.times do |y|
        dx = (x - 47.5) / 48.0; dy = (y - 26.5) / 27.0
        d = Math.sqrt(dx * dx + dy * dy)
        a = d < 0.6 ? 0 : [(d - 0.6) / 0.6, 1.0].min ** 1.6
        b.set_pixel(x, y, Color.new(8, 4, 14, (a * 230).round))
      end
    end
    return b
  end

  #-----------------------------------------------------------------------------
  # Cada fotograma
  #-----------------------------------------------------------------------------
  def self.tick
    @cada.call if @cada
    @cam.update
    if @tono_mov
      t0, t1, t, n = @tono_mov
      t += 1; f = OstMini.suave(t.to_f / n)
      @tono = (0...4).map { |i| t0[i] + (t1[i] - t0[i]) * f }
      @tono_mov[2] = t
      @tono_mov = nil if t >= n
    end
    z = @cam.z * ESC
    e = @escenario
    e.x = @cam.x(0); e.y = @cam.y(0); e.zoom_x = e.zoom_y = z
    e.tone.set(*@tono)
    @fondos.each_value do |f|
      s = f[0]; f[1] += (f[2] - f[1]) * 0.08
      s.x = e.x; s.y = e.y; s.zoom_x = s.zoom_y = z
      s.opacity = f[1]; s.tone.set(*@tono)
    end
    @vacio_op += (@vacio_obj - @vacio_op) * 0.08
    v = @vacio
    v.x = e.x; v.y = e.y; v.zoom_x = v.zoom_y = z; v.opacity = @vacio_op
    telon_tick(z)
    c = @cenefa
    c.x = @cam.x(CENEFA[0] * ESC); c.y = @cam.y(CENEFA[1] * ESC); c.zoom_x = c.zoom_y = z
    c.tone.set(*@tono)
    alumbra = @foco_a ? @foco_op / 255.0 * 0.85 : 0.0
    @actores.each do |a|
      lp = a.luz_propia
      a.luz_propia = [lp, alumbra].max if a.equal?(@foco_a)
      a.update(@cam, @tono, @vp)
      a.luz_propia = lp
    end
    halos
    notas
    particulas
    ondas
    niebla_tick
    rayos
    estrellas
    polvo
    foco
    musica_tick
    @blanco_op *= 0.93 if @blanco_op > 1
    @blanco.opacity = @blanco_op
    if @flecha.opacity > 0 || @esperando
      @flecha.opacity = @esperando ? 140 + 115 * Math.sin(Graphics.frame_count / 9.0).abs : 0
    end
    OstMini.tick
  end

  def self.esperar(seg)
    (seg * 60).round.times { tick }
  end

  def self.hasta_quietos(*quien)
    n = 0
    while (quien.any? { |a| a.moviendo? } || @cam.moviendo?) && n < 900
      tick; n += 1
    end
  end

  def self.luz(destino, seg)
    @tono_mov = [@tono.dup, destino.map(&:to_f), 0, [(seg * 60).round, 1].max]
  end

  def self.destello(op = 255)
    @blanco_op = op.to_f
  end

  #--- telon --------------------------------------------------------------------
  def self.telon(abierto, seg)
    @telon_mov = [@abierto, abierto.to_f, 0, [(seg * 60).round, 1].max]
  end

  def self.telon_tick(z)
    if @telon_mov
      a0, a1, t, n = @telon_mov
      t += 1; @abierto = a0 + (a1 - a0) * OstMini.suave(t.to_f / n); @telon_mov[2] = t
      @telon_mov = nil if t >= n
    end
    moviendo = !@telon_mov.nil?
    @tela.each do |lado, (s, bx, by)|
      s.x = @cam.x(bx * ESC); s.y = @cam.y(by * ESC)
      ancho = 1.0 - 0.88 * @abierto
      onda = moviendo ? 0.012 * Math.sin(Graphics.frame_count / 4.0 + (lado == :izq ? 0 : 1.5)) : 0
      s.zoom_x = z * (ancho + onda); s.zoom_y = z
      s.visible = @abierto < 0.995
      s.tone.set(*@tono.map { |v| v * 0.6 })
    end
  end

  def self.telon_quieto
    n = 0
    while @telon_mov && n < 900
      tick; n += 1
    end
  end

  def self.fondo(nombre)
    @fondos.each { |n, f| f[2] = (n == nombre) ? 255.0 : 0.0 }
  end

  #--- estrellas, halos, notas, rayos ---------------------------------------------
  def self.polvo
    @polvo_op += (@polvo_obj - @polvo_op) * 0.03
    @polvo.each do |p|
      s, x, y, fase, v = p
      p[2] = y - v; p[2] = 980 if p[2] < 150
      s.x = @cam.x(x + Math.sin(Graphics.frame_count / 50.0 + fase) * 30); s.y = @cam.y(p[2])
      s.zoom_x = s.zoom_y = 2.0 * @cam.z
      s.opacity = @polvo_op * (0.4 + 0.6 * (0.5 + 0.5 * Math.sin(Graphics.frame_count / 23.0 + fase)))
    end
  end

  def self.estrellas
    vis = [@fondos["cosmos"][1], @fondos["cima"][1]].max / 255.0
    @estrellas.each do |e|
      s, x, y, fase = e
      s.x = @cam.x(x); s.y = @cam.y(y); s.zoom_x = s.zoom_y = ESC * @cam.z * 0.6
      s.opacity = vis * (90 + 165 * (0.5 + 0.5 * Math.sin(Graphics.frame_count / 17.0 + fase)))
    end
  end

  def self.halos
    @halos.each do |h|
      s, a, op, obj, dy, radio = h
      op += (obj - op) * 0.06
      h[2] = op
      s.x = @cam.x(a.x); s.y = @cam.y(a.y + dy)
      late = 1.0 + 0.05 * Math.sin(Graphics.frame_count / 11.0 + a.x)
      s.zoom_x = s.zoom_y = (radio * 2.0 / s.bitmap.width) * @cam.z * late
      s.z = 99 + a.y.round
      s.opacity = op * (a.op / 255.0)
    end
  end

  def self.nota(x, y, rgb)
    bm = OstMini.bmp(VIEJO + "notas.png")
    return if !bm
    s = Sprite.new(@vp); s.bitmap = bm
    w = bm.width / 3
    s.src_rect.set(rand(3) * w, 0, w, bm.height)
    s.ox = w / 2; s.oy = bm.height / 2
    s.color.set(rgb[0], rgb[1], rgb[2], 150)
    s.z = 1400
    @notas.push([s, x + rand(40) - 20, y, 0, rand * 6.28])
  end

  def self.notas
    @notas.delete_if do |n|
      s, x, y, t, fase = n
      t += 1; n[3] = t
      wx = x + Math.sin(t / 12.0 + fase) * 26
      wy = y - t * 2.2
      s.x = @cam.x(wx); s.y = @cam.y(wy)
      s.zoom_x = s.zoom_y = @cam.z * (0.7 + t / 160.0)
      s.opacity = t < 15 ? t * 17 : 255 - (t - 15) * 4
      if t > 78
        OstMini.soltar(s)
        true
      else
        false
      end
    end
  end

  # un rayo de luz de (x0,y0) a (x1,y1) que crece, se queda y se apaga
  def self.rayo(x0, y0, x1, y1, rgb, vida = 150)
    s = Sprite.new(@vp); s.bitmap = bmp_rayo; s.blend_type = 1; s.z = 1350
    s.color.set(rgb[0], rgb[1], rgb[2], 140)
    @rayos.push([s, x0, y0, x1, y1, 0, vida])
  end

  def self.rayos
    @rayos.delete_if do |r|
      s, x0, y0, x1, y1, t, vida = r
      t += 1; r[5] = t
      sx0 = @cam.x(x0); sy0 = @cam.y(y0); sx1 = @cam.x(x1); sy1 = @cam.y(y1)
      dx = sx1 - sx0; dy = sy1 - sy0
      largo = Math.sqrt(dx * dx + dy * dy)
      s.x = sx0; s.y = sy0; s.ox = 16; s.oy = 0
      s.angle = -Math.atan2(dx, dy) * 180 / Math::PI
      s.zoom_x = (1.3 + 0.25 * Math.sin(t / 9.0)) * @cam.z; s.zoom_y = largo / 8.0 * [t / 20.0, 1.0].min
      s.opacity = t < vida - 30 ? 200 : 200 * (vida - t) / 30.0
      if t >= vida
        begin; s.dispose; rescue; end
        true
      else
        false
      end
    end
  end

  # la musica de la funcion (Audio/BGM/Obra *.mp3), si esta
  # la musica de la funcion (Audio/BGM/Obra *.mp3), con fundido cruzado: la que
  # suena baja en seg segundos y la nueva sube desde cero (lo lleva musica_tick)
  def self.musica(nombre, seg = 2.0, vol = 75)
    return if nombre && !OstMini.audio?("BGM", nombre)
    @mus ||= { :actual => nil, :vol => 0.0 }
    @mus[:siguiente] = nombre; @mus[:obj] = vol.to_f
    @mus[:paso] = 75.0 / [seg * 60, 1].max
  end

  def self.musica_tick
    m = @mus
    return if !m
    if m[:siguiente] != m[:actual] && m.key?(:siguiente)
      if m[:actual] && m[:vol] > 0
        m[:vol] = [m[:vol] - m[:paso], 0].max
      else
        m[:actual] = m[:siguiente]; m[:vol] = 0.0
        m.delete(:siguiente) if m[:actual].nil?
      end
    elsif m[:actual] && m[:vol] < m[:obj]
      m[:vol] = [m[:vol] + m[:paso], m[:obj]].min
    end
    m.delete(:siguiente) if m[:siguiente] == m[:actual]
    v = m[:vol].round
    return if v == m[:ultimo] && m[:sonando] == m[:actual]
    m[:ultimo] = v
    begin
      if m[:actual]
        Audio.bgm_play("Audio/BGM/" + m[:actual], [v, 1].max, 100) if m[:sonando] != m[:actual] || v % 3 == 0 || v >= m[:obj]
        m[:sonando] = m[:actual]
      else
        Audio.bgm_stop; m[:sonando] = nil
      end
    rescue
    end
  end

  def self.sonar(n, vol = 80, tono = 100)
    OstMini.se("Mudkip nota #{n}", nil, vol, tono)
  end

  #--- foco ---------------------------------------------------------------------
  def self.enfocar(quien, op = 235, seg = 0.8, esc = 1.0)
    @foco_a = quien if quien
    @foco_mov = [@foco_op, op.to_f, 0, [(seg * 60).round, 1].max]
    @foco_esc = esc
  end

  def self.foco
    if @foco_mov
      o0, o1, t, n = @foco_mov
      t += 1; @foco_op = o0 + (o1 - o0) * OstMini.suave(t.to_f / n); @foco_mov[2] = t
      @foco_mov = nil if t >= n
    end
    @foco.opacity = @foco_op
    @cono.opacity = @foco_a ? @foco_op * 0.75 : 0
    if @foco_a && @foco_op > 0
      @cono.x = @cam.x(@foco_a.x); @cono.y = @cam.y(@foco_a.y + 10)
      @cono.zoom_x = 2.4 * @cam.z * @foco_esc; @cono.zoom_y = [(@cam.y(@foco_a.y + 10) + 20) / 256.0, 0.5].max
    end
    return if !@foco_a || @foco_op <= 0
    a = @foco_a
    @foco.x = @cam.x(a.x); @foco.y = @cam.y(a.y - 110)
    @foco.zoom_x = @foco.zoom_y = 4.0 * @cam.z * @foco_esc
  end

  #--- subtitulos -----------------------------------------------------------------
  def self.di(codigo)
    ["", "b", "c", "d"].each do |suf|
      bm = OstMini.bmp(TEXTOS + codigo + suf + ".png")
      break if !bm
      OstMini.soltar(@sub); @sub = Sprite.new(@vp); @sub.z = 1810
      @sub.bitmap = bm; @sub.x = (1920 - bm.width) / 2; @sub.y = 1080 - 150
      @sub.opacity = 0
      @flecha.x = @sub.x + bm.width + 40; @flecha.y = @sub.y + 40
      12.times do
        @banda.opacity += 22; @sub.opacity += 22
        tick
      end
      @banda.opacity = 255; @sub.opacity = 255
      @esperando = true
      armado = false
      loop do
        tick
        armado = true if !Input.press?(Input::USE)
        break if armado && Input.trigger?(Input::USE)
      end
      @esperando = false; @flecha.opacity = 0
      8.times { @sub.opacity -= 33; tick }
      @sub.opacity = 0
    end
  end

  def self.callar
    while @banda.opacity > 0
      @banda.opacity -= 24; tick
    end
  end

  # una frase mientras pasa algo cada fotograma (k = fotogramas desde que salio)
  def self.di_con(codigo)
    k = 0
    antes = @cada
    @cada = proc { antes.call if antes; k += 1; yield k }
    begin
      di(codigo)
    ensure
      @cada = antes
    end
  end

  def self.plano(x, y, z, seg); @cam.a(x, y, z, seg); end
  def self.abrir_plano(seg = 1.2); @cam.a(960, 540, 1.0, seg); end

  #-----------------------------------------------------------------------------
  # LA OBRA
  #-----------------------------------------------------------------------------
  def self.obra
    OstMini.se("Obra murmullo", nil, 70)
    OstMini.fundir(@telon, 0, 10)
    esperar(0.8)
    OstMini.se("Obra shhh", nil, 80)
    di("ObraPub00")
    callar
    luz(PENUMBRA, 2.2)
    esperar(2.4)
    el_vacio
    los_resonantes
    los_primeros
    el_silencio
    la_nota
    saludo
  end

  #--- 1. la gota y el nucleo ------------------------------------------------------
  def self.el_vacio
    # una gota de luz cae del techo delante del telon cerrado
    @gota.x = 960; @gota.y = 120; @gota.op = 255
    brillo_de(@gota, 220)
    plano(960, 620, 1.5, 0.1)
    esperar(0.6)
    @gota.ir(960, SUELO - 30, 1.3, :lineal)
    hasta_quietos(@gota)
    sonar(1, 85); destello(200); @cam.temblar(4)
    @gota.op = 0; brillo_de(@gota, 0)
    esperar(0.5)
    di("ObraTxt00")
    callar
    # se abre el telon al vacio
    fondo("cosmos")
    musica("Obra cosmos")
    @polvo_obj = 120.0
    luz(COSMOS, 0.1)
    abrir_plano(2.5)
    telon(1.0, 3.0)
    telon_quieto
    # baja el nucleo
    @nucleo.y = 120; @nucleo.op = 255
    @nucleo.ir(960, 640, 3.0)
    brillo_de(@nucleo, 140)
    plano(960, 420, 1.3, 3.0)
    hasta_quietos(@nucleo)
    late_nucleo(2)
    # salen las esferas y giran a su alrededor
    di("ObraTxt01")
    salir_esferas
    @t_orb = 0
    @cada = proc { @t_orb += 1; orbita(@t_orb) }
    di("ObraTxt02")
    luz(COSMOS, 2.0)
    abrir_plano(2.0)
    di("ObraTxt03")
    di("ObraTxt04")
    callar
  end

  def self.late_nucleo(veces)
    veces.times do
      sonar(1, 60, 80)
      brillo_de(@nucleo, 255); @nucleo.bote(4)
      esperar(0.5)
      brillo_de(@nucleo, 140)
      esperar(0.5)
    end
  end

  def self.salir_esferas
    @esferas.each_with_index do |e, i|
      e.x = @nucleo.x; e.y = @nucleo.y - 170; e.op = 0; e.fundir(255, 0.4)
      brillo_de(e, 200)
      a = i * Math::PI / 3
      e.ir(@nucleo.x + Math.cos(a) * 340, @nucleo.y - 170 + Math.sin(a) * 120, 0.6)
      sonar(NOTAS_RES[i], 70)
      esperar(0.4)
    end
  end

  # las esferas dan vueltas alrededor del nucleo
  def self.orbita(k)
    @esferas.each_with_index do |e, i|
      next if e.moviendo?
      a = k / 90.0 + i * Math::PI / 3
      e.x = @nucleo.x + Math.cos(a) * 340
      e.y = @nucleo.y - 170 + Math.sin(a) * 120
    end
  end

  #--- 2. los Resonantes -------------------------------------------------------------
  def self.los_resonantes
    # el nucleo brilla hasta cegar
    brillo_de(@nucleo, 255)
    plano(960, 420, 1.15, 1.5)
    3.times { |i| sonar(1 + i * 2, 70 + i * 10); esperar(0.3) }
    destello(255); @cam.temblar(10)
    @nucleo_roto.y = @nucleo.y; @nucleo_roto.op = 255; @nucleo.op = 0
    @cada = nil
    esperar(0.8)
    di("ObraTxt05")
    di("ObraTxt06")
    callar
    # el nucleo roto sube; cada esfera va a su marca y baja su Resonante
    @nucleo_roto.ir(960, -260, 3.0)
    abrir_plano(1.5)
    @esferas.each_with_index { |e, i| e.ir(RESONANTES[i][1], ry(i) - 150, 1.0) }
    hasta_quietos(*@esferas)
    @res.each_with_index do |r, i|
      e = @esferas[i]
      r.y = -150; r.op = 255
      r.ir(r.x, ry(i), 1.3, :cae)
      plano(r.x, ry(i) - 150, 1.5, 0.6)
      esperar(0.8)
      e.fundir(0, 0.3); brillo_de(e, 0); destello(90)
      brillo_de(r, 120)
      OstMini.se("Cries/#{RESONANTES[i][0]}", nil, 50)
      sonar(NOTAS_RES[i], 75)
      esperar(0.6)
    end
    abrir_plano(1.2)
    esperar(0.6)
    di("ObraTxt07")
    di("ObraTxt08")
    di("ObraTxt09")
    callar
    # todos cantan a la vez: rayos de luz y acorde
    luz(CANTO, 1.0)
    @polvo_obj = 220.0
    6.times do |i|
      brillo_de(@res[i], 255); @res[i].bote(10)
      3.times { nota(RESONANTES[i][1], ry(i) - 140, RESONANTES[i][2]) }
      sonar(NOTAS_RES[i], 85)
      esperar(0.22)
    end
    destello(70)
    @cam.temblar(5)
    di("ObraTxt10")
    callar
    @res.each { |r| brillo_de(r, 70) }
  end

  #--- 3. los primeros hombres y mujeres ---------------------------------------------
  def self.los_primeros
    # la tierra se calma: el valle
    luz(VALLE, 2.5)
    fondo("valle")
    musica("Obra coro")
    di("ObraTxt11")
    # bajan las marionetas, una a una, cada una a su marca
    [:mar0, :mar3, :mar1, :mar2, :pipo, :pichu].each do |k|
      a = @gente[k]
      a.y = -100; a.op = 255; a.pose = 0
      a.ir(GENTE[k], SUELO, 1.2, :cae)
      esperar(0.45)
    end
    hasta_quietos(*@gente.values)
    di("ObraTxt12")
    plano(990, 760, 1.35, 1.6)
    di("ObraTxt13")
    callar
    # miran arriba y levantan los brazos
    @mar.each { |m| m.pose = M_ARRIBA; m.bote(8); esperar(0.2) }
    @pipo.pose = H_ARRIBA; @pipo.bote(10); @pichu.bote(12)
    OstMini.se("Cries/PICHU", nil, 60)
    abrir_plano(1.5)
    di("ObraTxt14")
    # bajan hilos de luz de cada Resonante a la gente
    destinos = [@mar[0], @mar[1], @pipo, @pichu, @mar[2], @mar[3]]
    6.times do |i|
      e = @esferas[i]; d = destinos[i]
      e.parar; e.hilos = 0
      e.x = RESONANTES[i][1]; e.y = ry(i) - 100; e.op = 0; e.fundir(255, 0.3); brillo_de(e, 200)
      e.ir(d.x, d.y - 170, 1.6)
      sonar(NOTAS_RES[i], 70)
      esperar(0.35)
    end
    hasta_quietos(*@esferas)
    6.times do |i|
      e = @esferas[i]; d = destinos[i]
      e.fundir(0, 0.4); brillo_de(e, 0)
      brillo_de(d, 170)
      d.bote(10)
      3.times { nota(d.x, d.y - 200, RESONANTES[i][2]) }
      esperar(0.15)
    end
    di_con("ObraTxt15") { |k| (i = k / 30 % 6; nota(destinos[i].x, SUELO - 230, RESONANTES[i][2])) if k % 30 == 0 }
    luz(CANTO, 1.0)
    di_con("ObraTxt16") do |k|
      if k % 26 == 0
        i = (k / 26) % 6
        sonar(NOTAS_RES[i], 60)
        destinos[i].bote(8); @res[i].bote(6)
      end
    end
    callar
  end

  #-----------------------------------------------------------------------------
  # Particulas: motas que vuelan (oscuras al silenciar, claras al liberar) y
  # confeti de la fiesta. Cada una: [sprite, x, y, vx, vy, t, vida, gravedad, gira]
  #-----------------------------------------------------------------------------
  def self.bmp_confeti
    if !@bmp_confeti || @bmp_confeti.disposed?
      @bmp_confeti = Bitmap.new(4, 2); @bmp_confeti.fill_rect(0, 0, 4, 2, Color.new(255, 255, 255))
    end
    return @bmp_confeti
  end

  def self.particula(x, y, vx, vy, rgb, vida, tipo = :luz, g = 0.0)
    @parts ||= []
    s = Sprite.new(@vp)
    if tipo == :confeti
      s.bitmap = bmp_confeti; s.ox = 2; s.oy = 1; s.z = 1450
      s.color.set(rgb[0], rgb[1], rgb[2], 255)
    else
      s.bitmap = bmp_glow; s.ox = s.oy = 64; s.z = 1440
      s.blend_type = tipo == :luz ? 1 : 0
      s.color.set(rgb[0], rgb[1], rgb[2], 255)
    end
    @parts.push([s, x.to_f, y.to_f, vx.to_f, vy.to_f, 0, vida, g, tipo, rand * 6.28])
  end

  def self.particulas
    return if !@parts
    @parts.delete_if do |p|
      s, x, y, vx, vy, t, vida, g, tipo, fase = p
      t += 1; p[5] = t
      vy += g; p[4] = vy
      x += vx + (tipo == :confeti ? Math.sin(t / 10.0 + fase) * 1.2 : 0); y += vy
      p[1] = x; p[2] = y
      s.x = @cam.x(x); s.y = @cam.y(y)
      f = t.to_f / vida
      if tipo == :confeti
        s.zoom_x = 3.5 * @cam.z * Math.cos(t / 6.0 + fase).abs + 0.5; s.zoom_y = 3.5 * @cam.z
        s.angle = (t * 7 + fase * 50) % 360
        s.opacity = f > 0.8 ? 255 * (1 - f) * 5 : 255
      else
        tam = tipo == :luz ? 0.22 : 0.30
        s.zoom_x = s.zoom_y = tam * @cam.z * (1.0 - f * 0.5)
        s.opacity = (f < 0.15 ? f / 0.15 : 1.0 - (f - 0.15) / 0.85) * (tipo == :luz ? 255 : 230)
      end
      if t >= vida
        begin; s.dispose; rescue; end
        true
      else
        false
      end
    end
  end

  # un chorro de motas de a hacia b
  def self.chorro(ax, ay, bx, by, rgb, n, tipo, seg = 0.9)
    vida = (seg * 60).round
    n.times do
      ox = ax + rand(60) - 30; oy = ay + rand(60) - 30
      particula(ox, oy, (bx - ox) / vida.to_f, (by - oy) / vida.to_f, rgb, vida + rand(10), tipo)
    end
  end

  # onda: un anillo de luz que se abre desde (x, y)
  def self.onda(x, y, rgb, radio_fin = 1400, seg = 1.0, oscura = false)
    @ondas ||= []
    s = Sprite.new(@vp); s.bitmap = bmp_glow; s.ox = s.oy = 64; s.z = 1455
    s.blend_type = oscura ? 0 : 1
    s.color.set(rgb[0], rgb[1], rgb[2], 255)
    @ondas.push([s, x, y, radio_fin, 0, (seg * 60).round])
  end

  def self.ondas
    return if !@ondas
    @ondas.delete_if do |o|
      s, x, y, r, t, n = o
      t += 1; o[4] = t
      f = OstMini.sale(t.to_f / n)
      s.x = @cam.x(x); s.y = @cam.y(y)
      s.zoom_x = s.zoom_y = (r * f / 64.0) * @cam.z
      s.opacity = 255 * (1.0 - t.to_f / n)
      if t >= n
        begin; s.dispose; rescue; end
        true
      else
        false
      end
    end
  end

  #--- la niebla oscura que sube del suelo ---------------------------------------------
  def self.montar_niebla
    @niebla = []
    20.times do |i|
      s = Sprite.new(@vp); s.bitmap = bmp_glow; s.ox = s.oy = 64; s.z = 1300
      c = [[58, 26, 82], [34, 14, 54], [76, 34, 96]][i % 3]
      s.color.set(c[0], c[1], c[2], 255); s.opacity = 0
      @niebla.push([s, 380 + i * 60 + rand(40), SUELO + 10 + rand(40), rand * 6.28, 1.2 + rand * 1.2])
    end
    @niebla_op = 0.0; @niebla_obj = 0.0; @niebla_alto = 0.0; @niebla_huye = 0.0
  end

  def self.niebla_tick
    return if !@niebla
    @niebla_op += (@niebla_obj - @niebla_op) * 0.025
    @niebla.each do |n|
      s, x, y, fase, tam = n
      t = Graphics.frame_count / 70.0 + fase
      dx = (x - 960) * @niebla_huye
      s.x = @cam.x(x + Math.sin(t) * 40 + dx)
      s.y = @cam.y(y - @niebla_alto * (0.6 + 0.4 * Math.sin(t * 0.7)) - @niebla_huye * 300)
      s.zoom_x = (tam * 2.2 + 0.3 * Math.sin(t * 1.3)) * @cam.z
      s.zoom_y = (tam * 1.3 + @niebla_alto / 160.0) * @cam.z
      s.opacity = @niebla_op * (0.75 + 0.25 * Math.sin(t * 1.7))
    end
  end

  #--- 4. los Silenciadores ----------------------------------------------------------
  def self.el_silencio
    # la musica se apaga despacio
    musica(nil, 3.0)
    esperar(0.6)
    luz([-50, -55, -50, 120], 2.5)
    di("ObraTxt17")
    callar
    # una niebla oscura sube del suelo
    @niebla_obj = 245.0
    plano(960, 760, 1.15, 3.0)
    OstMini.se("Vs flash", nil, 45, 40)
    150.times { |k| @niebla_alto = k * 1.3; tick }
    @cam.temblar(4)
    # de la niebla salen los Silenciadores, a los lados
    @sombras.each_with_index do |s, i|
      s.parar; s.x = SOMBRAS[i]; s.y = SUELO + 140; s.op = 0
      s.fundir(240, 1.2); s.ir(SOMBRAS[i], SUELO - 30, 1.6, :suave)
      onda(SOMBRAS[i], SUELO - 80, [20, 6, 30], 600, 1.2, true)
      chorro(SOMBRAS[i], SUELO + 40, SOMBRAS[i], SUELO - 200, [30, 10, 40], 14, :oscura, 1.2)
      OstMini.se("Vs flash", nil, 60, 35 + i * 10)
      esperar(0.9)
    end
    hasta_quietos(*@sombras)
    abrir_plano(1.5)
    di("ObraTxt18")
    callar
    # y van apagando a cada uno: su luz se la beben las sombras
    musica("Obra silencio", 3.0)
    @polvo_obj = 0.0
    luz(SILENCIO, 6.0)
    victimas = [@res[2], @mar[0], @res[0], @res[1], @mar[1], @res[3], @pichu, @res[4], @mar[2], @res[5], @mar[3]]
    victimas.each_with_index do |v, k|
      s = @sombras[v.x < 960 ? 0 : 1]
      silenciar(v, s)
      esperar(k < 3 ? 0.6 : 0.3)
    end
    @res.each_with_index { |r, i| r.parar; r.ir(r.x, ry(i) + 70, 1.0) }
    aflojar(1.0)
    di("ObraTxt19")
    @cam.temblar(10); onda(960, 600, [10, 4, 18], 1600, 1.6, true)
    di("ObraTxt20")
    callar
  end

  # una sombra le quita la luz a alguien
  def self.silenciar(v, sombra)
    brillo_de(v, 0)
    v.sprite.flash(Color.new(16, 4, 26, 230), 40)
    v.tension = 0.15; v.aleteo = false if @res.include?(v)
    v.pose = M_CAIDO if @mar.include?(v)
    hy = @res.include?(v) ? v.y - 80 : v.y - 120
    chorro(v.x, hy, sombra.x, sombra.y - 120, [26, 8, 36], 10, :oscura, 0.8)
    sombra.bote(6)
    OstMini.se("Vs flash", nil, 40, 30)
    @cam.temblar(3)
  end

  # f de 0 a 1: lo caidos que estan todos
  def self.aflojar(f)
    f = [[f, 0.0].max, 1.0].min
    (@mar + @res + [@pipo, @pichu]).each { |a| a.tension = 1.0 - f * 0.85 }
    if f >= 0.5
      @mar.each { |m| m.pose = M_CAIDO }
      @pipo.pose = H_QUIETO
    end
    @res.each { |r| r.aleteo = f < 0.5 }
  end

  #--- 5. la nota ----------------------------------------------------------------------
  def self.la_nota
    # oscuro: un solo foco, el nino
    luz(OSCURO, 2.0)
    enfocar(@pipo, 235, 2.0, 1.2)
    plano(@pipo.x + 40, SUELO - 140, 1.8, 2.5)
    esperar(2.5)
    @pipo.pose = H_BUSCA
    di("ObraTxt21")
    callar
    # se sienta, cierra los ojos y tararea: siempre la misma nota
    @pipo.pose = H_SENTADO
    @pipo.tension = 1.0
    esperar(0.8)
    @fuerza = 0.1; @k_tar = 0
    @cada = proc do
      @k_tar += 1
      if @k_tar % 50 == 0
        sonar(1, 30 + 45 * @fuerza, 100)
        (1 + (@fuerza * 3).round).times { nota(@pipo.x, SUELO - 160, [255, 244, 210]) }
        particula(@pipo.x, SUELO - 120, 0, -1.2, [255, 236, 190], 70, :luz) if @fuerza > 0.2
      end
    end
    esperar(2.0)
    @fuerza = 0.3
    di("ObraTxt22")
    # la nota llega a Pichu, luego a cada marioneta: la niebla retrocede
    plano(@pichu.x, SUELO - 150, 1.6, 1.0)
    despertar(@pichu)
    OstMini.se("Cries/PICHU", nil, 70)
    @fuerza = 0.5
    esperar(1.6)
    abrir_plano(2.0)
    [@mar[1], @mar[2], @mar[0], @mar[3]].each_with_index do |m, i|
      despertar(m)
      m.pose = M_QUIETO
      @fuerza = 0.6 + i * 0.1
      @niebla_alto = [@niebla_alto - 20, 0].max
      esperar(1.0)
    end
    @fuerza = 1.0
    # todos tararean: la luz crece
    enfocar(nil, 0, 2.0)
    luz([-60, -60, -50, 120], 3.0)
    @cam.a(960, 620, 1.1, 3.0)
    di("ObraTxt23")
    callar
    @cada = nil
    liberacion
    fiesta
  end

  # la nota del nino le llega a alguien y le devuelve la luz
  def self.despertar(a)
    chorro(@pipo.x, SUELO - 140, a.x, a.y - 120, [255, 236, 190], 10, :luz, 0.7)
    esperar(0.5)
    a.luz_propia = 0.8; a.tension = 1.0; a.bote(10)
    a.sprite.flash(Color.new(255, 244, 210, 200), 20)
    brillo_de(a, 120)
    nota(a.x, a.y - 220, [255, 244, 210])
  end

  #--- la liberacion: estalla la luz y los Silenciadores se deshacen ---------------
  def self.liberacion
    musica("Obra coro", 0.6)
    sonar(1, 100); sonar(5, 90); sonar(8, 90)
    @pipo.pose = H_ARRIBA; @pipo.bote(14)
    destello(255); @cam.temblar(16)
    onda(@pipo.x, SUELO - 140, [255, 240, 200], 2200, 1.4)
    onda(@pipo.x, SUELO - 140, [255, 255, 255], 1400, 0.9)
    luz(CANTO, 0.4)
    @polvo_obj = 240.0
    # la niebla sale despedida y las sombras suben y se deshacen
    60.times { |k| @niebla_huye = k / 60.0; @niebla_obj = 0.0; tick if k % 2 == 0 }
    @sombras.each_with_index do |s, i|
      s.ir(s.x + (i == 0 ? -160 : 160), -300, 2.2)
      s.fundir(0, 1.6)
      chorro(s.x, s.y - 120, s.x, -200, [40, 20, 60], 16, :oscura, 1.4)
    end
    # todos vuelven: los Resonantes en su sitio, cada uno con su luz
    (@mar + @res + [@pichu, @pipo]).each { |a| a.tension = 1.0; a.luz_propia = 0.0 }
    @mar.each { |m| m.pose = M_ARRIBA }
    @res.each_with_index do |r, i|
      r.parar; r.ir(r.x, ry(i), 0.8, :cae); r.aleteo = true
      brillo_de(r, 220)
      onda(r.x, ry(i) - 90, RESONANTES[i][2], 500, 1.0)
      chorro(r.x, ry(i) - 80, r.x, ry(i) - 80, RESONANTES[i][2], 8, :luz, 0.6)
    end
    (@mar + [@pichu]).each { |a| brillo_de(a, 150) }
    brillo_de(@pipo, 200)
    40.times { particula(400 + rand(1120), -20 - rand(200), rand * 2 - 1, 2 + rand * 2, RESONANTES[rand(6)][2], 260, :confeti, 0.02) }
    esperar(1.8)
  end

  #--- la fiesta: las marionetas tocan, todos bailan ---------------------------------
  def self.fiesta
    @mar.each { |m| m.pose = M_QUIETO }          # tambor, flauta... sus poses de tocar
    gente = @mar + [@pipo, @pichu]
    pulso = 0
    planos = [[960, 560, 1.0], [@mar[1].x, SUELO - 140, 1.7], [@mar[2].x, SUELO - 140, 1.7],
              [960, 470, 1.25], [@pipo.x + 60, SUELO - 140, 1.6], [960, 560, 1.0]]
    planos.each_with_index do |(x, y, z), p|
      @cam.a(x, y, z, 1.4)
      90.times do |k|
        if k % 30 == 0
          pulso += 1
          gente.each_with_index { |a, j| a.bote((pulso + j).even? ? 12 : 5) }
          @pipo.pose = pulso.even? ? H_SALTA : H_ARRIBA
          @mar[0].pose = pulso.even? ? M_ARRIBA : M_QUIETO
          @mar[3].pose = pulso.even? ? M_QUIETO : M_ARRIBA
          i = pulso % 6
          nota(@mar[1].x, SUELO - 200, RESONANTES[i][2])          # el tambor
          nota(@mar[2].x - 30, SUELO - 210, RESONANTES[(i + 3) % 6][2]) # la flauta
          @res[i].bote(8); brillo_de(@res[i], 255)
          @res[(i + 5) % 6].tap { |r| brillo_de(r, 170) }
          sonar(NOTAS_RES[i], 55)
          luz(pulso.even? ? CANTO : [-20, -30, -10, 0], 0.4)
        end
        particula(400 + rand(1120), -20, rand * 2 - 1, 2 + rand * 2, RESONANTES[rand(6)][2], 240, :confeti, 0.02) if k % 4 == 0
        tick
      end
    end
    # baja el telon con la fiesta
    telon(0.0, 3.5)
    k = 0
    while @telon_mov
      gente.each_with_index { |a, j| a.bote(10) if (k / 30 + j).even? && k % 30 == 0 }
      particula(400 + rand(1120), -20, rand * 2 - 1, 2 + rand * 2, RESONANTES[rand(6)][2], 240, :confeti, 0.02) if k % 5 == 0
      tick; k += 1
    end
    brillo_de(@pipo, 0)
    esperar(0.8)
  end

  #--- saludo y aplausos ---------------------------------------------------------------
  def self.saludo
    OstMini.fundir(@telon, 255, 4)
    esperar(1.5)
    OstMini.se("Obra aplausos", nil, 90)
    luz(SALA, 0.1)
    @halos.each { |h| h[3] = 0.0; h[2] = 0.0 }
    @niebla_obj = 0.0; @niebla_op = 0.0
    @sombras.each_with_index { |s, i| s.parar; s.x = SOMBRAS[i]; s.y = SUELO - 30; s.op = 255; s.tension = 1.0 }
    @mar.each { |m| m.pose = M_QUIETO }
    @pipo.pose = H_QUIETO
    @abierto = 1.0; @telon_mov = nil
    abrir_plano(0.1)
    esperar(0.2)
    OstMini.fundir(@telon, 0, 8)
    esperar(0.4)
    (@mar + [@pipo, @pichu] + @sombras).each { |a| a.bote(10); esperar(0.12) }
    esperar(2.0)
    OstDlg.run([["TeaTxt13", "der"], ["TeaTxt14", "izq"], ["TeaTxt15", "der"], ["TeaTxt16", "izq"]], ARTES)
    OstMini.fundir(@telon, 255, 10)
  end
end
