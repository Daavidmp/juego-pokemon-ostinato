#===============================================================================
# Pokemon Ostinato - La obra del teatro de Villa Bambalina: "La plaza callada"
#
#   Cuando Kaia y Lira se sientan (024_ButacasTeatro), la pantalla pasa a
#   1920x1080 y se ve el escenario de frente, como desde la butaca. El plano
#   es siempre el mismo dibujo (Obra/escenario.png); lo que cambia es la
#   camara (se acerca a quien habla), la luz (sala, dia, noche, foco) y los
#   actores, que entran y salen por las dos puertas del decorado.
#
#   Lo que dicen sale como subtitulo abajo ("Narradora: ...") y se pasa con
#   Enter. Al acabar, Kaia y Lira hablan con su cuadro de siempre y se vuelve
#   al mapa. Interruptor 83 = obra vista.
#
#   Las piezas salen de recursos/obra/construir.py (Graphics/Titles/Obra/) y
#   los textos de recursos/guion_bambalina_teatro.txt (ObraTxt, ObraPub,
#   TeaTxt13-16) con textos_guion.ps1. Los sonidos que aun faltan suenan
#   solo cuando existan: Audio/SE/Obra murmullo, Obra shhh, Obra risas,
#   Obra aplausos y Obra golpe.
#
#   Medidas en el mundo de la obra, que es el escenario a 1920x1080: la x es
#   la de la pantalla con la camara abierta y la y es la de los pies.
#===============================================================================
module OstObra
  DIR      = "Graphics/Titles/Obra/"
  TEXTOS   = "Graphics/Titles/"
  SW_VISTA = 83

  SUELO  = 895            # pies en primer termino
  FONDO  = 842            # pies de la fila de las luces, al fondo
  LEJOS  = 0.86           # lo que encoge quien esta al fondo
  PUERTA = { :izq => 436, :der => 1540 }
  PUERTA_Y = 830          # pies en el umbral de las puertas del decorado

  # sitios en el escenario
  NARR     = 330
  NINO     = 760
  VECINA   = 1120
  PANADERO = 1270
  PUESTO   = [1330, 891]
  ARBOL    = [1690, 897]
  SENORA   = 930
  FILA     = [470, 600, 730, 860, 990, 1120]      # las luces, al fondo

  POSES = { "narradora" => 4, "panadero" => 4, "vecina" => 4, "nino" => 5,
            "senora" => 4, "luz" => 4 }
  # poses: narradora 0 presenta 1 presenta (otro lado) 2 reverencia 3 quieta
  #        panadero  0 con el pan 1 ofrece el pan 2 sorprendido 3 da la mano
  #        vecina    0 con el pan 1 mano al pecho 2 enfadada 3 da la mano
  #        nino      0 grita 1 sentado 2 rie 3 rie con los brazos arriba 4 asustado
  #        luz       0 quieta 1 brilla 2 canta 3 callada
  #        senora    0 quieta 1 mano al pecho 2 pide 3 cuelga el farol
  # donde queda la luz del farol de cada pose de las luces, desde los pies
  FAROL = [[0, -80], [0, -80], [-47, -166], [-25, -20]]
  FAROL_SENORA = [-95, -32]

  # las luces: color, nota de la marimba y por que puerta entran
  LUCES = [
    ["amarilla", [255, 214, 64], 1, :izq],
    ["roja",     [236, 64, 56],  2, :der],
    ["morada",   [160, 92, 220], 3, :izq],
    ["rosa",     [248, 132, 186], 5, :der],
    ["verde",    [88, 206, 100], 6, :izq],
    ["azul",     [76, 146, 240], 8, :der]
  ]

  # luz de toda la escena (rojo, verde, azul, gris)
  SALA   = [0, 0, 0, 0]
  PENUMBRA = [-150, -150, -125, 70]
  DIA    = [0, 0, 0, 0]
  NOCHE  = [-105, -92, -18, 30]
  DUELO  = [-150, -140, -95, 90]
  FIESTA = [-55, -45, 0, 10]

  ARTES = {
    "izq" => ["DlgLira.png", 174, 465, "DlgNomLira"],
    "der" => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }

  #-----------------------------------------------------------------------------
  # La camara: mira al punto (cx, cy) del mundo con un zoom. Con zoom 1 se ve
  # el escenario entero. Nunca ensena lo que hay fuera del dibujo.
  #-----------------------------------------------------------------------------
  class Camara
    attr_reader :z
    def initialize
      @cx = 960.0; @cy = 540.0; @z = 1.0
      @mov = nil
      @temblor = 0.0
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

    # del mundo a la pantalla
    def x(wx); return ((wx - @cx) * @z + 960 + @dx).round; end
    def y(wy); return ((wy - @cy) * @z + 540 + @dy).round; end
  end

  #-----------------------------------------------------------------------------
  # Un actor (o una pieza de atrezo): un dibujo con varias poses, anclado por
  # los pies. Anda dando saltitos, como en las escenas de los juegos.
  #-----------------------------------------------------------------------------
  class Actor
    attr_accessor :x, :y, :esc, :pose, :espejo, :op, :angulo, :salto
    attr_reader :sprite, :ancho

    def initialize(vp, archivo, poses = 1)
      @sprite = Sprite.new(vp)
      @sprite.bitmap = OstMini.bmp(DIR + archivo + ".png")
      @poses = poses
      @ancho = @sprite.bitmap ? @sprite.bitmap.width / poses : 1
      @alto  = @sprite.bitmap ? @sprite.bitmap.height : 1
      @sprite.ox = @ancho / 2
      @sprite.oy = @alto
      @x = -999; @y = SUELO; @esc = 1.0; @pose = 0; @espejo = false
      @op = 0; @angulo = 0; @salto = 0
      @mov = nil; @fade = nil; @giro = nil; @bote = 0
    end

    # anda hasta (x, y) con escala e; botes = saltitos por segundo (0 = desliza)
    def ir(x, y = nil, e = nil, seg = nil, botes = 3.0)
      y ||= @y; e ||= @esc
      seg ||= [((x - @x).abs + (y - @y).abs * 3) / 330.0, 0.25].max
      @mov = [@x, @y, @esc, x.to_f, y.to_f, e.to_f, 0, [(seg * 60).round, 1].max, botes]
      @espejo = (x < @x) if (x - @x).abs > 4 && @espeja_al_andar
    end

    def espeja_al_andar=(v); @espeja_al_andar = v; end

    # otro dibujo de una sola pose, anclado por abajo en el centro
    def dibujo=(bm)
      @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
      @sprite.bitmap = bm; @poses = 1
      @ancho = bm.width; @alto = bm.height
      @sprite.ox = @ancho / 2; @sprite.oy = @alto
    end
    def fundir(op, seg = 0.4); @fade = [@op, op, 0, [(seg * 60).round, 1].max]; end
    def girar(a, seg); @giro = [@angulo, a, 0, [(seg * 60).round, 1].max]; end
    def moviendo?; return !@mov.nil?; end
    def bote(px); @bote = px.to_f; end      # un saltito de alegria o de susto

    # luz: de 0 a 1, lo que le alumbra el foco (le quita la oscuridad de la escena)
    def update(cam, tono, luz = 0.0)
      if @mov
        x0, y0, e0, x1, y1, e1, t, n, botes = @mov
        t += 1
        f = OstMini.suave(t.to_f / n)
        @x = x0 + (x1 - x0) * f; @y = y0 + (y1 - y0) * f; @esc = e0 + (e1 - e0) * f
        @salto = botes > 0 ? -(Math.sin(t / 60.0 * Math::PI * botes).abs * 14) : 0
        @mov[6] = t
        if t >= n
          @mov = nil; @salto = 0
        end
      end
      if @fade
        o0, o1, t, n = @fade
        t += 1; @op = o0 + (o1 - o0) * t.to_f / n; @fade[2] = t
        @fade = nil if t >= n
      end
      if @giro
        a0, a1, t, n = @giro
        t += 1; @angulo = a0 + (a1 - a0) * OstMini.entra(t.to_f / n); @giro[2] = t
        @giro = nil if t >= n
      end
      if @bote > 0.5
        @salto = -@bote; @bote *= 0.8
      elsif !@mov
        @salto = 0
      end
      s = @sprite
      return if !s.bitmap
      s.src_rect.set(@pose * @ancho, 0, @ancho, @alto)
      s.mirror = @espejo
      s.x = cam.x(@x)
      s.y = cam.y(@y + @salto * @esc)
      s.zoom_x = s.zoom_y = @esc * cam.z
      s.angle = @angulo
      s.opacity = @op
      s.z = 100 + @y.round
      k = 1.0 - luz
      s.tone.set(tono[0] * k, tono[1] * k, tono[2] * k, tono[3] * k)
    end

    def dispose; OstMini.soltar(@sprite); end
  end

  #-----------------------------------------------------------------------------
  # La funcion
  #-----------------------------------------------------------------------------
  def self.empezar
    return if $game_switches[SW_VISTA]
    $game_switches[SW_VISTA] = true
    begin
      OstMini.pantalla(nil) { |vp, telon| funcion(vp, telon) }
    rescue StandardError => e
      echoln("OstObra: #{e.class}: #{e.message}\n#{e.backtrace[0, 5].join("\n")}") rescue nil
    end
  end

  def self.funcion(vp, telon)
    @vp = vp; @telon = telon
    @cam = Camara.new
    @tono = SALA.map(&:to_f); @tono_mov = nil
    @actores = []; @halos = []; @notas = []
    @escenario = Sprite.new(vp)
    @escenario.bitmap = OstMini.bmp(DIR + "escenario.png")
    @escenario.z = 0
    @foco = Sprite.new(vp); @foco.bitmap = OstMini.bmp(DIR + "foco.png")
    @foco.ox = 480; @foco.oy = 270; @foco.z = 1500; @foco.opacity = 0
    @foco_a = nil; @foco_op = 0.0; @foco_mov = nil; @foco_esc = 1.0
    @banda = Sprite.new(vp); @banda.bitmap = OstMini.bmp(DIR + "banda.png")
    @banda.y = 1080 - 230; @banda.z = 1800; @banda.opacity = 0
    @sub = Sprite.new(vp); @sub.z = 1810; @sub.opacity = 0
    @flecha = Sprite.new(vp); @flecha.bitmap = OstMini.bmp(TEXTOS + "DlgFlecha.png")
    @flecha.z = 1820; @flecha.opacity = 0
    if @flecha.bitmap
      @flecha.ox = @flecha.bitmap.width / 2; @flecha.oy = @flecha.bitmap.height / 2
      @flecha.zoom_x = @flecha.zoom_y = 0.8
    end
    @telon.z = 3000           # el negro tapa tambien a los actores
    montar
    tick
    obra
  ensure
    (@actores || []).each { |a| a.dispose }
    (@halos || []).each { |h| OstMini.soltar(h[0]) }
    (@notas || []).each { |n| OstMini.soltar(n[0]) }
    [@escenario, @foco, @banda, @sub, @flecha].each { |s| OstMini.soltar(s) }
  end

  def self.actor(archivo, poses = 1)
    a = Actor.new(@vp, archivo, poses)
    @actores.push(a)
    return a
  end

  def self.montar
    @puesto = actor("puesto"); @puesto.x, @puesto.y = PUESTO; @puesto.op = 255
    @arbol = actor("arbol"); @arbol.x, @arbol.y = ARBOL; @arbol.op = 255
    @narr = actor("narradora", 4); @narr.pose = 3
    @pan = actor("panadero", 4)
    @vec = actor("vecina", 4)
    @nino = actor("nino", 5)
    @luces = LUCES.map { |c, _rgb, _n, _p| actor("luz_" + c, 4) }
    @luces.each { |l| l.esc = LEJOS }
    @senora = actor("senora", 4)
    @farol = actor("farol")
    # el farol cuelga de una cuerda que baja del techo del escenario
    @cuerda = actor("farol")
    hilo = Bitmap.new(4, 700)
    hilo.fill_rect(0, 0, 4, 700, Color.new(40, 30, 34))
    @cuerda.dibujo = hilo
    # el brillo de cada luz: el del farol y el que tine el escenario
    @luces.each_with_index do |l, i|
      rgb = LUCES[i][1]
      cerca = OstMini.halo(@vp, 120, 0); cerca.color.set(rgb[0], rgb[1], rgb[2], 255)
      bano  = OstMini.halo(@vp, 330, 0); bano.color.set(rgb[0], rgb[1], rgb[2], 255)
      @halos.push([cerca, l, 0.0, 0.0, :farol])     # sprite, actor, opacidad, objetivo
      @halos.push([bano, l, 0.0, 0.0, :bano])
    end
  end

  #-----------------------------------------------------------------------------
  # Lo que pasa cada fotograma
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
    e = @escenario
    e.x = @cam.x(0); e.y = @cam.y(0); e.zoom_x = e.zoom_y = @cam.z
    e.tone.set(*@tono)
    alumbra = @foco_a ? @foco_op / 255.0 * 0.85 : 0.0
    @actores.each { |a| a.update(@cam, @tono, a.equal?(@foco_a) ? alumbra : 0.0) }
    halos
    notas
    foco
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

  #--- foco: oscurece todo menos un circulo que sigue a alguien ------------------
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
    return if !@foco_a || @foco_op <= 0
    a = @foco_a
    alto = a.is_a?(Actor) ? 120 * a.esc : 0
    @foco.x = @cam.x(a.x); @foco.y = @cam.y(a.y - alto)
    @foco.zoom_x = @foco.zoom_y = 4.0 * @cam.z * @foco_esc
  end

  #--- brillos de las luces --------------------------------------------------------
  # que: :farol / :bano; op de 0 a 255
  def self.brillo(i, que, op)
    @halos.each { |h| h[3] = op.to_f if h[1] == @luces[i] && h[4] == que }
  end

  def self.halos
    @halos.each do |h|
      s, a, op, obj, que = h
      op += (obj - op) * 0.06
      h[2] = op
      if que == :farol
        fx, fy = FAROL[a.pose] || [0, -80]
        fx = -fx if a.espejo
        s.x = @cam.x(a.x + fx * a.esc); s.y = @cam.y(a.y + (fy + a.salto) * a.esc)
        late = 1.0 + 0.06 * Math.sin(Graphics.frame_count / 11.0 + a.x)
        s.zoom_x = s.zoom_y = (240.0 / s.bitmap.width) * a.esc * @cam.z * late
        s.z = 101 + a.y.round
      else
        s.x = @cam.x(a.x); s.y = @cam.y(a.y - 90)
        s.zoom_x = s.zoom_y = (660.0 / s.bitmap.width) * @cam.z
        s.z = 5
        op *= 0.45
      end
      s.opacity = op * (a.op / 255.0)
    end
  end

  #--- notas musicales que salen de un farol ---------------------------------------
  def self.nota(i)
    l = @luces[i]
    bm = OstMini.bmp(DIR + "notas.png")
    return if !bm
    s = Sprite.new(@vp); s.bitmap = bm
    w = bm.width / 3
    s.src_rect.set(rand(3) * w, 0, w, bm.height)
    s.ox = w / 2; s.oy = bm.height / 2
    rgb = LUCES[i][1]
    s.color.set(rgb[0], rgb[1], rgb[2], 150)
    s.z = 1400
    fx, fy = FAROL[l.pose]
    @notas.push([s, l.x + fx * l.esc + rand(30) - 15, l.y + fy * l.esc, 0, rand * 6.28])
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

  # una luz canta su nota (con tono < 100, desafina: la que no encaja)
  def self.cantar(i, notas = 5, volumen = 90, tono = 100)
    OstMini.se("Mudkip nota #{LUCES[i][2]}", nil, volumen, tono)
    notas.times { |k| nota(i) if k == 0 || rand < 0.8 }
  end

  #-----------------------------------------------------------------------------
  # Subtitulos
  #-----------------------------------------------------------------------------
  def self.di(codigo)
    ["", "b", "c", "d"].each do |suf|
      bm = OstMini.bmp(TEXTOS + codigo + suf + ".png")
      break if !bm
      OstMini.soltar(@sub) ; @sub = Sprite.new(@vp); @sub.z = 1810
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

  # quita la banda cuando no se habla durante un rato
  def self.callar
    while @banda.opacity > 0
      @banda.opacity -= 24; tick
    end
  end

  #-----------------------------------------------------------------------------
  # Entradas y salidas por las puertas del decorado
  #-----------------------------------------------------------------------------
  def self.entrar(a, lado, x, y = SUELO, esc = 1.0, seg = nil)
    a.x = PUERTA[lado]; a.y = PUERTA_Y; a.esc = esc * 0.92; a.op = 0
    a.espeja_al_andar = false
    a.fundir(255, 0.3)
    a.ir(PUERTA[lado], y, esc, 0.45, 2.5)
    hasta_quietos(a)
    a.espejo = (x < a.x)
    a.ir(x, y, esc, seg)
  end

  def self.salir(a, lado, seg = nil)
    a.espejo = (PUERTA[lado] < a.x)
    a.ir(PUERTA[lado], a.y, a.esc, seg)
    hasta_quietos(a)
    a.ir(PUERTA[lado], PUERTA_Y, a.esc * 0.92, 0.4, 2.5)
    a.fundir(0, 0.4)
    hasta_quietos(a)
    a.espejo = false
  end

  # la camara a la cara de alguien (z = cuanto se acerca)
  def self.mirar(a, z = 1.6, seg = 0.9, dy = -120)
    @cam.a(a.x, a.y + dy * a.esc, z, seg)
  end

  def self.abrir(seg = 1.2); @cam.a(960, 540, 1.0, seg); end

  def self.risas
    OstMini.se("Obra risas", nil, 80)
  end

  #-----------------------------------------------------------------------------
  # LA OBRA
  #-----------------------------------------------------------------------------
  def self.obra
    # la sala con luz y el publico murmurando
    OstMini.se("Obra murmullo", nil, 70)
    OstMini.fundir(@telon, 0, 10)
    esperar(0.8)
    OstMini.se("Obra shhh", nil, 80)
    di("ObraPub00")
    callar
    luz(PENUMBRA, 2.2)
    esperar(2.4)

    #--- PROLOGO: la Narradora sola, con un foco ---------------------------------
    @narr.op = 0
    @cam.a(PUERTA[:izq], 640, 1.5, 0.1)
    esperar(0.2)
    entrar(@narr, :izq, NARR)
    enfocar(@narr, 235, 1.0)
    mirar(@narr, 1.6, 1.4)
    hasta_quietos(@narr)
    @narr.pose = 0
    di("ObraTxt00")
    mirar(@narr, 1.8, 3.0)
    di("ObraTxt01")
    @narr.pose = 3
    di("ObraTxt02")
    di("ObraTxt03")
    callar

    #--- ESCENA I: la manana -------------------------------------------------------
    enfocar(nil, 0, 1.4)
    luz(DIA, 1.6)
    abrir(1.6)
    esperar(1.0)
    entrar(@pan, :der, PANADERO)
    hasta_quietos(@pan)
    entrar(@vec, :izq, VECINA - 140)
    @vec.pose = 1
    @cam.a(1170, 660, 1.45, 1.6)
    hasta_quietos(@vec)
    @vec.espejo = false; @pan.espejo = false
    di("ObraTxt04")
    di("ObraTxt05")
    enfocar(@narr, 200, 0.6, 1.3)
    mirar(@narr, 1.5)
    di("ObraTxt06")
    enfocar(nil, 0, 0.6)
    @cam.a(1170, 660, 1.45, 1.0)
    @pan.pose = 1
    esperar(0.5)
    @vec.ir(VECINA, nil, nil, 0.6)
    hasta_quietos(@vec)
    @vec.pose = 0; @pan.pose = 0
    esperar(0.3)
    di("ObraTxt07")
    mirar(@pan, 1.75, 0.6)
    di("ObraTxt08")
    @vec.pose = 1
    mirar(@vec, 1.75, 0.6)
    di("ObraTxt09")
    mirar(@pan, 1.6, 0.6)
    di("ObraTxt10")
    @vec.pose = 0
    callar
    # entra el Nino corriendo, grita y no le sale nada
    abrir(0.8)
    @nino.pose = 0
    entrar(@nino, :izq, NINO, SUELO, 1.0, 0.7)
    hasta_quietos(@nino)
    @cam.a(NINO, 690, 1.8, 0.5)
    esperar(0.6)
    @nino.bote(10)
    esperar(1.4)
    @nino.pose = 1
    esperar(0.8)
    enfocar(@narr, 200, 0.6, 1.3)
    mirar(@narr, 1.5)
    di("ObraTxt11")
    callar

    #--- ESCENA II: la noche de las luces ----------------------------------------
    enfocar(nil, 0, 1.0)
    abrir(2.0)
    luz(NOCHE, 2.5)
    esperar(1.8)
    OstMini.se("Mudkip nota 1", nil, 35, 100)     # una nota a lo lejos
    esperar(1.0)
    di("ObraTxt12")
    di("ObraTxt13")
    callar
    # la amarilla
    llegar_luz(0)
    di("ObraTxt14")
    di("ObraTxt15")
    @nino.pose = 2; @nino.bote(16); risas
    mirar(@nino, 1.7, 0.5)
    di_con("ObraTxt16") { |k| @nino.pose = (k / 18) % 2 == 0 ? 2 : 3 }
    @nino.pose = 3
    # la roja
    llegar_luz(1)
    di("ObraTxt17")
    di("ObraTxt18")
    @vec.pose = 2; @vec.bote(10)
    @cam.a(1190, 680, 1.6, 0.5)
    @cam.temblar(4)
    di("ObraTxt19")
    @pan.pose = 2; @pan.bote(12)
    di("ObraTxt20")
    @cam.temblar(7)
    di("ObraTxt21")
    @vec.pose = 0; @pan.pose = 0
    # la morada: el Nino estaba en el borde y se echa atras
    @nino.pose = 0
    @nino.ir(NINO + 20, SUELO + 6, nil, 0.4, 0)
    llegar_luz(2)
    @nino.pose = 4
    @nino.ir(NINO - 90, SUELO - 8, nil, 0.5, 0)
    di("ObraTxt22")
    di("ObraTxt23")
    # la rosa
    llegar_luz(3)
    di("ObraTxt24")
    di("ObraTxt25")
    @cam.a(1190, 680, 1.7, 0.8)
    @pan.pose = 1
    di("ObraTxt26")
    @vec.pose = 1
    esperar(0.6)
    @vec.pose = 3; @pan.pose = 3
    di("ObraTxt27")
    # la verde, y se cae el arbol
    llegar_luz(4)
    di("ObraTxt28")
    callar
    @cam.a(ARBOL[0] - 200, 700, 1.5, 0.4)
    esperar(0.3)
    @arbol.girar(88, 0.55)
    esperar(0.55)
    OstMini.se("Obra golpe", nil, 95)
    @cam.temblar(16)
    [@nino, @vec, @pan].each { |a| a.bote(18) }
    esperar(0.9)
    mirar(@luces[4], 1.6, 0.6)
    di("ObraTxt29")
    # la azul llega mirando el arbol
    llegar_luz(5, true)
    di("ObraTxt30")
    di("ObraTxt31")
    risas
    callar

    #--- ESCENA III: el primer coro --------------------------------------------------
    @cam.a(960, 600, 1.15, 2.0)
    di("ObraTxt32")
    di("ObraTxt33")
    callar
    coro
    di("ObraTxt34")
    callar

    #--- ESCENA IV: la senora de negro -------------------------------------------
    @luces.each { |l| l.pose = 0 }
    @nino.pose = 1; @vec.pose = 1; @pan.pose = 0
    @cam.temblar(0)
    esperar(0.4)
    luz(DUELO, 3.0)
    6.times { |i| brillo(i, :farol, 120); brillo(i, :bano, 60) }
    @senora.pose = 0
    entrar(@senora, :der, SENORA, SUELO, 1.0, 4.0)
    @cam.a(SENORA, 660, 1.45, 4.0)
    hasta_quietos(@senora)
    enfocar(@senora, 160, 1.5, 1.6)
    di("ObraTxt35")
    mirar(@senora, 1.7, 1.2)
    di("ObraTxt36")
    di("ObraTxt37")
    callar
    # las luces bajan la voz
    @luces.each { |l| l.pose = 3 }
    6.times { |i| brillo(i, :farol, 60); brillo(i, :bano, 20) }
    esperar(1.5)
    @senora.pose = 1
    mirar(@senora, 1.85, 1.0)
    di("ObraTxt38")
    di("ObraTxt39")
    @senora.pose = 2
    mirar(@senora, 1.5, 0.8, -150)
    di("ObraTxt40")
    callar
    # cada luz prueba su nota; ninguna encaja
    @cam.a(800, 620, 1.2, 1.0)
    6.times do |i|
      l = @luces[i]
      l.pose = 2; brillo(i, :farol, 200)
      cantar(i, 2, 65, 82)
      esperar(1.1)
      l.pose = 3; brillo(i, :farol, 25); brillo(i, :bano, 0)
      esperar(0.35)
    end
    esperar(3.0)                              # el silencio largo
    enfocar(@narr, 200, 1.0, 1.3)
    mirar(@narr, 1.5)
    di("ObraTxt41")
    callar
    enfocar(@senora, 170, 1.0, 1.6)
    # cuelga el farol alli mismo, delante de la fila de las luces, y se va
    @cam.a(@senora.x - 60, 620, 1.55, 1.5)
    hasta_quietos(@senora)
    @senora.espejo = false
    @senora.pose = 3
    esperar(1.0)
    fx, fy = FAROL_SENORA
    @farol.x = @senora.x + fx * @senora.esc
    @farol.y = @senora.y + fy * @senora.esc
    @farol.esc = @senora.esc
    @cuerda.x = @farol.x; @cuerda.y = @farol.y - 70 * @farol.esc; @cuerda.esc = 1.0
    @farol.op = 255; @cuerda.op = 255
    @senora.pose = 1
    esperar(1.0)
    di("ObraTxt42")
    callar
    salir(@senora, :der, 3.5)
    enfocar(@farol, 210, 1.5, 0.8)
    @cam.a(@farol.x, @farol.y - 60, 1.8, 2.5)
    esperar(1.5)
    di("ObraTxt43")
    callar
    # oscuro, silencio y despues los aplausos
    OstMini.fundir(@telon, 255, 4)
    esperar(2.5)
    OstMini.se("Obra aplausos", nil, 90)
    enfocar(nil, 0, 0.1)
    luz(SALA, 0.1)
    6.times { |i| brillo(i, :farol, 0); brillo(i, :bano, 0) }
    @senora.op = 0
    @arbol.angulo = 0          # en el oscuro, los tramoyistas lo levantan
    @farol.op = 0; @cuerda.op = 0
    # todos a saludar en primera fila
    saludo = [[@narr, 300], [@nino, 470], [@vec, 640]] + @luces.each_with_index.map { |l, i| [l, 810 + i * 120] } + [[@pan, 1560]]
    saludo.each { |a, x| a.x = x; a.y = SUELO; a.esc = 1.0; a.espejo = false; a.op = 255; a.pose = a == @nino ? 3 : 0 }
    @luces.each { |l| l.esc = 0.95; l.y = SUELO - 6 }
    @cam.a(960, 540, 1.0, 0.1)
    esperar(0.2)
    OstMini.fundir(@telon, 0, 8)
    @narr.pose = 2
    esperar(0.6)
    di("ObraTxt44")
    callar
    esperar(0.6)
    # Kaia y Lira, con la sala encendida
    OstDlg.run([["TeaTxt13", "der"], ["TeaTxt14", "izq"], ["TeaTxt15", "der"], ["TeaTxt16", "izq"]], ARTES)
    OstMini.fundir(@telon, 255, 10)
  end

  # una frase mientras pasa algo cada fotograma (k = fotogramas desde que salio)
  def self.di_con(codigo)
    k = 0
    @cada = proc { k += 1; yield k }
    begin
      di(codigo)
    ensure
      @cada = nil
    end
  end

  # una luz baja del monte: entra por su puerta, va a su sitio en la fila de
  # atras, se enciende y canta
  def self.llegar_luz(i, mirando_arbol = false)
    l = @luces[i]
    callar
    l.pose = 0
    entrar(l, LUCES[i][3], FILA[i], FONDO, LEJOS)
    brillo(i, :farol, 150)
    @cam.a(FILA[i], 640, 1.45, 1.2)
    hasta_quietos(l)
    l.espejo = mirando_arbol
    l.pose = 2
    brillo(i, :farol, 255); brillo(i, :bano, 170)
    cantar(i)
    esperar(0.9)
    l.pose = mirando_arbol ? 3 : 1
    mirar(l, 1.65, 0.7)
  end

  # todas cantan juntas y la gente baila
  def self.coro
    luz(FIESTA, 1.5)
    @luces.each { |l| l.pose = 2 }
    6.times { |i| brillo(i, :farol, 255); brillo(i, :bano, 200) }
    melodia = [0, 1, 2, 3, 4, 5, 4, 2, 0, 2, 4, 5]
    @cam.a(960, 560, 1.08, 6.0)
    melodia.each_with_index do |i, k|
      cantar(i, 2)
      [@nino, @vec, @pan].each_with_index { |a, j| a.bote(14) if (k + j) % 2 == 0 }
      @nino.pose = k % 2 == 0 ? 2 : 3
      @luces[i].bote(10)
      esperar(0.42)
    end
    # y el acorde final, todas a la vez
    6.times { |i| cantar(i, 3, 70) }
    @cam.temblar(3)
    esperar(1.6)
  end
end
