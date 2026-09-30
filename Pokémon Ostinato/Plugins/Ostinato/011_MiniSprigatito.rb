#===============================================================================
# Pokemon Ostinato - Minijuegos de los iniciales: la base comun y el columpio
#
#   OstMini es lo que comparten los tres: pantalla a 1920x1080 (OstinatoHD),
#   fundidos a negro, el cuadro de instrucciones con el pergamino, la musica y
#   los efectos (con sonido de repuesto mientras falten los definitivos), y lo
#   que hace que se mueva con soltura: curvas de aceleracion, destellos,
#   temblor de pantalla y hojitas que cruzan la escena.
#
#   El columpio de Sprigatito se ve DESDE DETRAS: Kaia esta de pie detras del
#   columpio y lo empuja. El asiento se aleja (sube y se hace pequeno) y vuelve
#   hacia ella (baja y crece). Hay que pulsar ESPACIO justo cuando vuelve, que
#   es cuando se empuja. Cinco empujones buenos y Sprigatito salta.
#
#   Todo esta medido sobre el lienzo de 1920x1080 del arte
#   (Graphics/Titles/MiniSprigatito/, sacado de Firefly con
#   Downloads/mini_sprigatito/proceso/procesar.py; las piezas de interfaz de
#   Graphics/Titles/MiniComun/ salen de Downloads/mini_comun/ui.py).
#===============================================================================
module OstMini
  ANCHO = 1920
  ALTO  = 1080
  COMUN = "Graphics/Titles/MiniComun/"

  def self.bmp(path)
    begin
      return Bitmap.new(path)
    rescue
      return nil
    end
  end

  def self.soltar(s)
    return if !s || s.disposed?
    b = s.bitmap
    s.dispose
    b.dispose if b && !b.disposed?
  end

  def self.tick
    Graphics.update
    Input.update
  end

  #-----------------------------------------------------------------------------
  # Curvas de aceleracion (t de 0 a 1)
  #-----------------------------------------------------------------------------
  def self.lim(t)
    return [[t.to_f, 0.0].max, 1.0].min
  end

  def self.suave(t)          # arranca y frena
    t = lim(t)
    return t * t * (3 - 2 * t)
  end

  def self.sale(t)           # sale deprisa y frena
    t = lim(t)
    return 1 - (1 - t) ** 3
  end

  def self.entra(t)          # arranca despacio y acelera (como al caer)
    t = lim(t)
    return t * t
  end

  def self.rebote(t)         # se pasa un poco y vuelve
    t = lim(t)
    u = t - 1
    return 1 + 2.70158 * u ** 3 + 1.70158 * u ** 2
  end

  #-----------------------------------------------------------------------------
  # Sonido
  #-----------------------------------------------------------------------------
  def self.audio?(carpeta, nombre)
    [".ogg", ".wav", ".mp3", ".mid"].each do |ext|
      return true if FileTest.exist?("Audio/" + carpeta + "/" + nombre + ext)
    end
    return false
  end

  # Un efecto: el definitivo si esta, si no el de repuesto (o nada)
  def self.se(nombre, repuesto = nil, volumen = 90, tono = 100)
    fichero = audio?("SE", nombre) ? nombre : repuesto
    return if !fichero
    begin
      pbSEPlay(fichero, volumen, tono)
    rescue
    end
  end

  # La musica del minijuego, si ya existe. Si no, sigue sonando la del mapa.
  def self.musica(nombre)
    return false if !audio?("BGM", nombre)
    begin
      $game_system.bgm_memorize
      pbBGMPlay(nombre, 90)
      return true
    rescue
      return false
    end
  end

  def self.devolver_musica
    begin
      $game_system.bgm_restore
    rescue
    end
  end

  #-----------------------------------------------------------------------------
  # Piezas comunes
  #-----------------------------------------------------------------------------
  def self.negro(vp, z = 900)
    s = Sprite.new(vp)
    s.z = z
    s.bitmap = Bitmap.new(ANCHO, ALTO)
    s.bitmap.fill_rect(0, 0, ANCHO, ALTO, Color.new(0, 0, 0))
    return s
  end

  # El fondo lleva 8 px de margen alrededor para que el temblor no ensene negro
  def self.fondo(vp, path)
    s = Sprite.new(vp)
    s.bitmap = bmp(path)
    s.x = -(s.bitmap.width - ANCHO) / 2
    s.y = -(s.bitmap.height - ALTO) / 2
    s.z = 0
    return s
  end

  # Halo de luz (anillos de pixel) de un radio dado, para mezcla aditiva
  def self.halo(vp, radio, z)
    s = Sprite.new(vp)
    s.bitmap = bmp(COMUN + "brillo.png")
    s.ox = s.bitmap.width / 2
    s.oy = s.bitmap.height / 2
    s.zoom_x = radio * 2.0 / s.bitmap.width
    s.zoom_y = s.zoom_x
    s.z = z
    s.blend_type = 1
    s.opacity = 0
    return s
  end

  # Icono de progreso (2 fotogramas: apagado y encendido) que salta al encenderse
  class Icono
    def initialize(vp, path, x, y)
      @s = Sprite.new(vp)
      @s.bitmap = OstMini.bmp(path)
      @w = @s.bitmap.width / 2
      @s.src_rect = Rect.new(0, 0, @w, @s.bitmap.height)
      @s.ox = @w / 2
      @s.oy = @s.bitmap.height / 2
      @s.x = x + @w / 2
      @s.y = y + @s.bitmap.height / 2
      @s.z = 700
      @t = -1
    end
    def x; @s.x; end
    def y; @s.y; end
    def encender
      @s.src_rect = Rect.new(@w, 0, @w, @s.bitmap.height)
      @t = 0
    end
    def update
      return if @t < 0
      @t += 1
      z = 1.7 - 0.7 * OstMini.rebote(@t / 16.0)
      @s.zoom_x = z
      @s.zoom_y = z
      if @t >= 16
        @s.zoom_x = 1.0
        @s.zoom_y = 1.0
        @t = -1
      end
    end
    def dispose; OstMini.soltar(@s); end
  end

  # Destellos de chispas (4 fotogramas); varios a la vez si hace falta
  class Chispas
    def initialize(vp, z, cuantas = 4)
      @b = OstMini.bmp(COMUN + "destello.png")
      @w = @b.width / 4
      @s = []
      @t = []
      cuantas.times do
        s = Sprite.new(vp)
        s.bitmap = @b
        s.ox = @w / 2
        s.oy = @b.height / 2
        s.z = z
        s.blend_type = 1
        s.visible = false
        @s.push(s)
        @t.push(-1)
      end
    end
    def lanzar(x, y, zoom = 1.0)
      i = @t.index(-1) || @t.each_with_index.max[1]
      s = @s[i]
      s.x = x
      s.y = y
      s.zoom_x = zoom
      s.zoom_y = zoom
      s.src_rect = Rect.new(0, 0, @w, @b.height)
      s.visible = true
      @t[i] = 0
    end
    def update
      @s.each_with_index do |s, i|
        next if @t[i] < 0
        f = @t[i] / 5
        if f > 3
          s.visible = false
          @t[i] = -1
          next
        end
        s.src_rect = Rect.new(f * @w, 0, @w, @b.height)
        @t[i] += 1
      end
    end
    def dispose
      @s.each { |s| s.dispose if !s.disposed? }
      @b.dispose if !@b.disposed?
    end
  end

  # Petalos y hojitas que cruzan la escena con el viento (tipos: 0 petalo, 1 hoja)
  class Ambiente
    def initialize(vp, z, tipos)
      @b = OstMini.bmp(COMUN + "particulas.png")
      @c = @b.height
      @p = []
      tipos.each_with_index do |tipo, i|
        s = Sprite.new(vp)
        s.bitmap = @b
        s.ox = @c / 2
        s.oy = @c / 2
        s.z = z
        @p.push([s, tipo, rand * ANCHO, rand * ALTO, -0.7 - rand * 0.9, 0.45 + rand * 0.5,
                 rand * 6.3, 0.04 + rand * 0.05])
      end
      @t = 0
    end
    def update
      @t += 1
      @p.each do |q|
        s, tipo, x, y, vx, vy, fase, giro = q
        x += vx + Math.sin(@t * 0.021 + fase) * 0.9
        y += vy + Math.cos(@t * 0.017 + fase) * 0.4
        if x < -40 || y > ALTO + 40
          x = ANCHO * (0.3 + rand * 0.9)
          y = -40
        end
        q[2] = x
        q[3] = y
        f = tipo * 2 + ((Math.sin(@t * giro + fase) > 0) ? 0 : 1)
        s.src_rect = Rect.new(f * @c, 0, @c, @c)
        s.x = x.round
        s.y = y.round
      end
    end
    def dispose
      @p.each { |q| q[0].dispose if !q[0].disposed? }
      @b.dispose if !@b.disposed?
    end
  end

  # Temblor de pantalla: se da un golpe y se va apagando solo
  def self.temblar(fuerza)
    @temblor = [@temblor.to_f, fuerza.to_f].max
  end

  def self.temblor(vp)
    t = @temblor.to_f
    if t < 0.6
      vp.ox = 0
      vp.oy = 0
      @temblor = 0
      return
    end
    vp.ox = ((rand * 2 - 1) * t).round
    vp.oy = ((rand * 2 - 1) * t).round
    @temblor = t * 0.78
  end

  def self.fundir(sprite, hasta, paso)
    loop do
      o = sprite.opacity
      break if o == hasta
      o = (o < hasta) ? [o + paso, hasta].min : [o - paso, hasta].max
      sprite.opacity = o
      yield if block_given?
      tick
    end
  end

  # El pergamino neutro con una frase de instrucciones (un PNG de textos.ps1)
  def self.cartel(vp, texto_png, y = 24)
    caja = Sprite.new(vp)
    caja.z = 800
    caja.bitmap = bmp("Graphics/Titles/DlgCuadroN.png")
    # el pergamino dibujado empieza a 83 px del borde de su PNG: centrado lo que se ve, y el texto en el
    caja.x = (ANCHO - (caja.bitmap ? caja.bitmap.width : 933) - 83) / 2
    caja.y = y
    txt = Sprite.new(vp)
    txt.z = 801
    txt.bitmap = bmp("Graphics/Titles/" + texto_png + ".png")
    txt.x = caja.x + 180
    txt.y = caja.y + 74
    return [caja, txt]
  end

  def self.opacidad(sprites, o)
    sprites.each { |s| s.opacity = o if s && !s.disposed? }
  end

  # Entra en la pantalla del minijuego y vuelve al mapa al acabar. El bloque
  # recibe el viewport a 1920x1080 y hace el juego.
  def self.pantalla(bgm = nil)
    sonaba = false
    @temblor = 0
    # primero el mapa se va a negro, todavia a su resolucion
    vp0 = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp0.z = 99999
    antes = Sprite.new(vp0)
    antes.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    antes.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    antes.opacity = 0
    fundir(antes, 255, 24)
    OstinatoHD.con do
      vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
      vp.z = 99999
      telon = negro(vp)
      telon.opacity = 255
      sonaba = musica(bgm) if bgm
      begin
        yield vp, telon
      ensure
        soltar(telon)
        begin; vp.dispose; rescue; end
      end
    end
    devolver_musica if sonaba
    # y al volver, el mapa aparece desde negro
    antes.bitmap.dispose
    antes.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    antes.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    antes.opacity = 255
    fundir(antes, 0, 20)
    soltar(antes)
    begin; vp0.dispose; rescue; end
  end
end


module OstinatoMiniSprigatito
  DIR = "Graphics/Titles/MiniSprigatito/"
  BGM = "Mini Sprigatito"

  PIVOTE_X = 960        # donde se cuelgan las cadenas: la barra de arriba
  PIVOTE_Y = 58
  ASIENTO  = 812        # fila del columpio.png donde empieza el asiento
  CULO     = 64         # cuanto se hunde Sprigatito en el asiento
  FOCAL    = 4000.0     # cuanto se nota la profundidad (mas = menos efecto)

  PERIODO   = 2.2       # segundos que tarda una ida y vuelta
  AMP_MIN   = 0.12      # radianes: el balanceo con el que empieza
  AMP_PASO  = 0.14      # lo que sube con cada empujon bueno
  AMP_FALLO = 0.05      # lo que baja si se empuja a destiempo
  AMP_SIGUE = 0.05      # que parte de lo que falta se gana cada fotograma (el empujon no da tirones)
  EMPUJES   = 5
  VENTANA   = [0.20, 0.18, 0.16, 0.15, 0.14]   # segundos de margen, cada vez menos
  SUELO     = 1075      # donde aterriza Sprigatito al saltar, delante del columpio
  CERCA     = 1.5       # su tamano ahi: el salto esta a pixel de 4, asi queda a pixel de 6 exacto

  # true si se ha completado (siempre se completa: fallar solo alarga el juego)
  def self.jugar
    ganado = false
    OstMini.pantalla(BGM) do |vp, telon|
      ganado = juego(vp, telon)
    end
    return ganado
  end

  def self.juego(vp, telon)
    fondo = OstMini.fondo(vp, DIR + "fondo.png")
    halo = OstMini.halo(vp, 260, 5)

    columpio = Sprite.new(vp)
    columpio.bitmap = OstMini.bmp(DIR + "columpio.png")
    columpio.ox = columpio.bitmap.width / 2
    columpio.oy = 0
    columpio.x = PIVOTE_X
    columpio.y = PIVOTE_Y
    columpio.z = 10
    largo = columpio.bitmap.height

    gato = Sprite.new(vp)
    gato_bmp = OstMini.bmp(DIR + "sprigatito.png")
    gato.bitmap = gato_bmp
    fw = gato_bmp.width / 3
    fh = gato_bmp.height
    gato.src_rect = Rect.new(0, 0, fw, fh)
    gato.ox = fw / 2
    gato.oy = fh
    gato.z = 11

    salto = OstMini.bmp(DIR + "sprigatito_salta.png")
    sombra = Sprite.new(vp)
    sombra.bitmap = OstMini.bmp(OstMini::COMUN + "sombra.png")
    sombra.ox = sombra.bitmap.width / 2
    sombra.oy = sombra.bitmap.height / 2
    sombra.x = 960
    sombra.y = SUELO - 6
    sombra.z = 9
    sombra.opacity = 0

    # la tecla ESPACIO, abajo a la derecha: normal, encendida y pulsada
    tecla = Sprite.new(vp)
    tecla.bitmap = OstMini.bmp(DIR + "tecla.png")
    tw = tecla.bitmap.width / 3
    tecla.src_rect = Rect.new(0, 0, tw, tecla.bitmap.height)
    tecla.ox = tw / 2
    tecla.oy = tecla.bitmap.height / 2
    tecla.x = 1620
    tecla.y = 960
    tecla.z = 700
    brillo = OstMini.halo(vp, 170, 699)
    brillo.x = tecla.x
    brillo.y = tecla.y

    # los cinco empujones, arriba a la derecha: hojitas que se van encendiendo
    hojas = []
    EMPUJES.times do |i|
      hojas.push(OstMini::Icono.new(vp, DIR + "icono_hoja.png", 1590 + i * 60, 36))
    end

    chispas = OstMini::Chispas.new(vp, 750)
    viento = OstMini::Ambiente.new(vp, 30, [1, 0, 1, 1, 0, 1])
    cartel = OstMini.cartel(vp, "MiniSprTxt00")

    fase = 0.0          # 0..2pi: sin(fase) > 0 se aleja, < 0 vuelve hacia Kaia
    amp = AMP_MIN
    amp_obj = AMP_MIN   # a donde va el balanceo; amp lo sigue sin saltos
    buenos = 0
    ya_empujado = false  # un solo empujon por vuelta
    w = 2.0 * Math::PI / (PERIODO * Graphics.frame_rate)
    cerca = 1.5 * Math::PI   # la fase en la que el columpio esta mas cerca
    tono = 100
    chirrio = false      # el chirrido suena una vez por vuelta, en lo mas lejos
    aplaste = 0.0        # Sprigatito se achucha un poco al recibir el empujon
    pulsada = 0          # fotogramas que la tecla se ve hundida
    quitar_cartel = false

    colocar = proc do
      th = amp * Math.sin(fase)
      z = largo * Math.sin(th)
      s = FOCAL / (FOCAL + z)
      cs = Math.cos(th)
      columpio.zoom_x = s
      columpio.zoom_y = s * cs
      gato.zoom_x = s * (1.0 + aplaste * 0.6)
      gato.zoom_y = s * (1.0 - aplaste)
      gato.x = PIVOTE_X
      gato.y = PIVOTE_Y + (ASIENTO * cs + CULO) * s
      # alejandose se echa hacia delante; volviendo, quieto; muy cerca te mira
      velocidad = Math.cos(fase)
      pose = (velocidad > 0.15) ? 1 : 0
      pose = 2 if Math.sin(fase) < -0.75
      gato.src_rect = Rect.new(pose * fw, 0, fw, fh)
      halo.x = gato.x
      halo.y = gato.y - fh * s * 0.45
      halo.zoom_x = s * 520.0 / halo.bitmap.width
      halo.zoom_y = halo.zoom_x
    end

    # lo que se mueve solo en cada fotograma, juegue o no
    paso = proc do
      OstMini.tick
      fase += w
      fase -= 2.0 * Math::PI if fase >= 2.0 * Math::PI
      amp += (amp_obj - amp) * AMP_SIGUE
      aplaste *= 0.86
      colocar.call
      viento.update
      chispas.update
      hojas.each { |h| h.update }
      OstMini.temblor(vp)
      if quitar_cartel
        cartel.each { |c| c.opacity = [c.opacity - 18, 0].max }
      end
    end

    colocar.call
    OstMini.fundir(telon, 0, 20) { fase += w; colocar.call; viento.update }

    # --- el juego ---------------------------------------------------------------
    while buenos < EMPUJES
      paso.call
      margen = VENTANA[[buenos, VENTANA.length - 1].min] * 2.0 * Math::PI / PERIODO
      dist = (fase - cerca).abs
      en_ventana = dist <= margen
      ya_empujado = false if dist > margen * 2.5
      # la tecla y el halo se van encendiendo al acercarse el momento
      luz = 1.0 - [dist / (margen * 2.5), 1.0].min
      luz = 0.0 if ya_empujado
      brillo.opacity = (luz * luz * 255).to_i
      halo.opacity = (luz * luz * 170).to_i
      pulsada -= 1 if pulsada > 0
      f = (pulsada > 0) ? 2 : ((luz > 0.35) ? 1 : 0)
      tecla.src_rect = Rect.new(f * tw, 0, tw, tecla.bitmap.height)
      if pulsado?
        pulsada = 8
        if en_ventana && !ya_empujado
          buenos += 1
          ya_empujado = true
          amp_obj += AMP_PASO
          aplaste = 0.10
          tono += 8
          OstMini.se("Columpio empuje", "Player jump", 70, 110)
          OstMini.se("Columpio acierto", "Mining ping", 90, tono)
          chispas.lanzar(gato.x, (gato.y - fh * gato.zoom_y * 0.55).to_i)
          hojas[buenos - 1].encender
          chispas.lanzar(hojas[buenos - 1].x, hojas[buenos - 1].y, 0.5)
          OstMini.temblar(4)
          quitar_cartel = true
        elsif !ya_empujado
          amp_obj = [amp_obj - AMP_FALLO, AMP_MIN].max
          OstMini.se("Columpio fallo", "GUI sel buzzer", 60, 80)
          ya_empujado = true
        end
      end
      if Math.sin(fase) > 0.97
        OstMini.se("Columpio chirrido", nil, 45, 100) if !chirrio
        chirrio = true
      elsif Math.sin(fase) < 0
        chirrio = false
      end
    end

    # --- el final: en lo mas alto, salta ------------------------------------------
    brillo.opacity = 0
    halo.opacity = 0
    quitar_cartel = true
    tecla.src_rect = Rect.new(0, 0, tw, tecla.bitmap.height)
    # espera a que el columpio vaya llegando a lo mas lejos y se agacha para coger impulso
    loop do
      paso.call
      break if (fase - 0.5 * Math::PI).abs < w * 1.5 + 0.35
    end
    8.times do |k|
      paso.call
      aplaste = 0.14 * OstMini.suave((k + 1) / 8.0)
      colocar.call
    end
    aplaste = 0.0
    # al saltar suena su grito de siempre, sin mas efecto encima
    begin
      GameData::Species.play_cry_from_species(:SPRIGATITO, 0, 90, 100)
    rescue
    end
    sj = salto.width / 2
    sh = salto.height
    gato.bitmap = salto
    gato.src_rect = Rect.new(0, 0, sj, sh)
    gato.ox = sj / 2
    gato.oy = sh
    x0 = gato.x
    y0 = gato.y
    s0 = gato.zoom_x
    # sube y se aleja (de espaldas), y arriba del todo se da la vuelta en el aire
    solo = proc do
      OstMini.tick
      fase += w
      amp_obj = AMP_MIN
      amp += (amp_obj - amp) * 0.02
      OstinatoMiniSprigatito.colocar_vacio(columpio, largo, amp, fase)
      viento.update
      chispas.update
      hojas.each { |h| h.update }
      OstMini.temblor(vp)
      cartel.each { |c| c.opacity = [c.opacity - 18, 0].max }
    end
    n = 34
    arriba = [y0 - 330, 120].max      # que no se salga por arriba
    n.times do |k|
      solo.call
      t = (k + 1).to_f / n
      u = OstMini.sale(t)
      esc = s0 * (1.0 - 0.42 * u)
      estira = 0.16 * (1 - t) ** 2
      giro = (k >= n - 8) ? Math.cos((k - (n - 8) + 1) / 8.0 * Math::PI / 2) : 1.0
      gato.x = x0
      gato.y = (y0 - arriba * u).to_i
      gato.zoom_x = esc * (1.0 - estira * 0.5) * giro
      gato.zoom_y = esc * (1.0 + estira)
    end
    # ya de frente, cae hacia Kaia, delante del columpio, y su sombra aparece en el suelo
    gato.src_rect = Rect.new(sj, 0, sj, sh)
    gato.z = 20
    ya = y0 - arriba
    ea = s0 * 0.58
    n = 38
    n.times do |k|
      solo.call
      t = (k + 1).to_f / n
      giro = (k < 8) ? Math.sin((k + 1) / 8.0 * Math::PI / 2) : 1.0
      esc = ea + (CERCA - ea) * OstMini.entra(t)
      gato.x = (x0 + (960 - x0) * OstMini.suave(t)).to_i
      gato.y = (ya + (SUELO - ya) * OstMini.entra(t) - 70 * Math.sin(t * Math::PI)).to_i
      gato.zoom_x = esc * giro
      gato.zoom_y = esc * (1.0 + 0.08 * OstMini.entra(t))
      sombra.opacity = (255 * t).to_i
      sombra.zoom_x = (0.5 + 0.5 * t) * CERCA
      sombra.zoom_y = sombra.zoom_x
    end
    # aterriza: se aplasta, chispas, y un par de saltitos de alegria cada vez mas bajos
    OstMini.se("Columpio acierto", "Mining ping", 90, 140)
    chispas.lanzar(960, SUELO - sh / 2)
    OstMini.temblar(8)
    sombra.zoom_x = sombra.zoom_y = CERCA
    brincar(gato, sombra, solo, [0.20, 0.10], [70, 30], CERCA)
    30.times { solo.call }
    OstMini.fundir(telon, 255, 10) { viento.update }

    [fondo, halo, columpio, gato, tecla, brillo, sombra].each { |s| OstMini.soltar(s) }
    hojas.each { |h| h.dispose }
    [chispas, viento].each { |o| o.dispose }
    cartel.each { |c| OstMini.soltar(c) }
    salto.dispose if !salto.disposed?
    gato_bmp.dispose if !gato_bmp.disposed?
    return true
  end

  # Al tocar el suelo: se aplasta y recupera; luego brinca con las alturas dadas.
  # Termina quieto a la escala e, con el pixel limpio. (Tambien lo usa Fennekin.)
  def self.brincar(sp, sombra, paso, aplastes, alturas, e = 1.0)
    suelo = sp.y
    alturas.each_with_index do |alto, i|
      a = aplastes[i]
      10.times do |k|
        paso.call
        r = 1.0 - OstMini.sale((k + 1) / 10.0)
        sp.zoom_x = e * (1.0 + a * 0.7 * r)
        sp.zoom_y = e * (1.0 - a * r)
      end
      n = (alto * 0.45).to_i + 12
      n.times do |k|
        paso.call
        t = (k + 1).to_f / n
        sp.y = (suelo - alto * Math.sin(t * Math::PI)).to_i
        estira = 0.06 * Math.cos(t * Math::PI)
        sp.zoom_x = e * (1.0 - estira * 0.5)
        sp.zoom_y = e * (1.0 + estira)
        if sombra
          sombra.zoom_x = e * (1.0 - 0.25 * Math.sin(t * Math::PI))
          sombra.zoom_y = sombra.zoom_x
        end
      end
    end
    8.times do |k|
      paso.call
      r = 1.0 - OstMini.sale((k + 1) / 8.0)
      sp.zoom_x = e * (1.0 + 0.05 * r)
      sp.zoom_y = e * (1.0 - 0.07 * r)
    end
    sp.y = suelo
    sp.zoom_x = e
    sp.zoom_y = e
    sombra.zoom_x = sombra.zoom_y = e if sombra
  end

  def self.pulsado?
    return true if Input.triggerex?(:SPACE)
    return true if Input.trigger?(Input::USE)
    return false
  end

  def self.colocar_vacio(columpio, largo, amp, fase)
    th = amp * Math.sin(fase)
    s = FOCAL / (FOCAL + largo * Math.sin(th))
    columpio.zoom_x = s
    columpio.zoom_y = s * Math.cos(th)
  end
end
