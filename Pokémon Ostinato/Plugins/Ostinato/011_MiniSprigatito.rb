#===============================================================================
# Pokemon Ostinato - Minijuegos de los iniciales: la base comun y el columpio
#
#   OstMini es lo que comparten los tres: pantalla a 1920x1080 (OstinatoHD),
#   fundidos a negro, el cuadro de instrucciones con el pergamino, la musica y
#   los efectos (con sonido de repuesto mientras falten los definitivos).
#
#   El columpio de Sprigatito se ve DESDE DETRAS: Kaia esta de pie detras del
#   columpio y lo empuja. El asiento se aleja (sube y se hace pequeno) y vuelve
#   hacia ella (baja y crece). Hay que pulsar ESPACIO justo cuando vuelve, que
#   es cuando se empuja. Cinco empujones buenos y Sprigatito salta.
#
#   Todo esta medido sobre el lienzo de 1920x1080 del arte
#   (Graphics/Titles/MiniSprigatito/, sacado de Firefly con
#   Downloads/mini_sprigatito/proceso/procesar.py).
#===============================================================================
module OstMini
  ANCHO = 1920
  ALTO  = 1080

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

  def self.negro(vp, z = 900)
    s = Sprite.new(vp)
    s.z = z
    s.bitmap = Bitmap.new(ANCHO, ALTO)
    s.bitmap.fill_rect(0, 0, ANCHO, ALTO, Color.new(0, 0, 0))
    return s
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
    caja.x = (ANCHO - (caja.bitmap ? caja.bitmap.width : 933)) / 2
    caja.y = y
    txt = Sprite.new(vp)
    txt.z = 801
    txt.bitmap = bmp("Graphics/Titles/" + texto_png + ".png")
    txt.x = caja.x + 139
    txt.y = caja.y + 74
    return [caja, txt]
  end

  def self.opacidad(sprites, o)
    sprites.each { |s| s.opacity = o if s && !s.disposed? }
  end

  # Un bitmap de circulo suave para brillos y halos
  def self.circulo(radio, color)
    b = Bitmap.new(radio * 2, radio * 2)
    r = radio
    while r > 0
      a = (color.alpha * (1.0 - r.to_f / radio) ** 0.6).to_i
      c = Color.new(color.red, color.green, color.blue, a)
      paso = [r / 12, 1].max
      y = -r
      while y <= r
        ancho = Math.sqrt(r * r - y * y).to_i
        b.fill_rect(radio - ancho, radio + y, ancho * 2, paso, c)
        y += paso
      end
      r -= [radio / 10, 1].max
    end
    return b
  end

  # Entra en la pantalla del minijuego y vuelve al mapa al acabar. El bloque
  # recibe el viewport a 1920x1080 y hace el juego.
  def self.pantalla(bgm = nil)
    sonaba = false
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
  ASIENTO  = 816        # fila del columpio.png donde empieza el asiento
  CULO     = 64         # cuanto se hunde Sprigatito en el asiento
  FOCAL    = 4000.0     # cuanto se nota la profundidad (mas = menos efecto)

  PERIODO   = 2.2       # segundos que tarda una ida y vuelta
  AMP_MIN   = 0.12      # radianes: el balanceo con el que empieza
  AMP_PASO  = 0.14      # lo que sube con cada empujon bueno
  AMP_FALLO = 0.05      # lo que baja si se empuja a destiempo
  EMPUJES   = 5
  VENTANA   = [0.20, 0.18, 0.16, 0.15, 0.14]   # segundos de margen, cada vez menos

  # true si se ha completado (siempre se completa: fallar solo alarga el juego)
  def self.jugar
    ganado = false
    OstMini.pantalla(BGM) do |vp, telon|
      ganado = juego(vp, telon)
    end
    return ganado
  end

  def self.juego(vp, telon)
    fondo = Sprite.new(vp)
    fondo.bitmap = OstMini.bmp(DIR + "fondo.png")
    fondo.z = 0

    halo = Sprite.new(vp)
    halo.bitmap = OstMini.circulo(260, Color.new(255, 250, 210, 150))
    halo.ox = 260
    halo.oy = 260
    halo.z = 5
    halo.blend_type = 1
    halo.opacity = 0

    columpio = Sprite.new(vp)
    columpio.bitmap = OstMini.bmp(DIR + "columpio.png")
    columpio.ox = columpio.bitmap ? columpio.bitmap.width / 2 : 0
    columpio.oy = 0
    columpio.x = PIVOTE_X
    columpio.y = PIVOTE_Y
    columpio.z = 10
    largo = columpio.bitmap ? columpio.bitmap.height : 992

    gato = Sprite.new(vp)
    gato_bmp = OstMini.bmp(DIR + "sprigatito.png")
    gato.bitmap = gato_bmp
    fw = gato.bitmap ? gato.bitmap.width / 3 : 352
    fh = gato.bitmap ? gato.bitmap.height : 432
    gato.src_rect = Rect.new(0, 0, fw, fh)
    gato.ox = fw / 2
    gato.oy = fh
    gato.z = 11

    salto = OstMini.bmp(DIR + "sprigatito_salta.png")

    # la tecla ESPACIO, abajo a la derecha, que se enciende en el momento justo
    tecla = Sprite.new(vp)
    tecla.bitmap = Bitmap.new(300, 110)
    tecla.ox = 150
    tecla.oy = 55
    tecla.x = 1620
    tecla.y = 960
    tecla.z = 700
    brillo = Sprite.new(vp)
    brillo.bitmap = OstMini.circulo(170, Color.new(255, 240, 150, 220))
    brillo.ox = 170
    brillo.oy = 170
    brillo.x = tecla.x
    brillo.y = tecla.y
    brillo.z = 699
    brillo.blend_type = 1
    brillo.opacity = 0
    dibujar_tecla(tecla.bitmap, false)

    # los cinco empujones, arriba a la derecha: hojitas que se van encendiendo
    hojas = []
    EMPUJES.times do |i|
      h = Sprite.new(vp)
      h.bitmap = Bitmap.new(40, 40)
      dibujar_hoja(h.bitmap, false)
      h.x = 1600 + i * 52
      h.y = 40
      h.z = 700
      hojas.push(h)
    end

    chispa = Sprite.new(vp)
    chispa.bitmap = OstMini.circulo(220, Color.new(255, 255, 255, 230))
    chispa.ox = 220
    chispa.oy = 220
    chispa.z = 12
    chispa.blend_type = 1
    chispa.opacity = 0

    cartel = OstMini.cartel(vp, "MiniSprTxt00")

    fase = 0.0          # 0..2pi: sin(fase) > 0 se aleja, < 0 vuelve hacia Kaia
    amp = AMP_MIN
    buenos = 0
    ya_empujado = false  # un solo empujon por vuelta
    w = 2.0 * Math::PI / (PERIODO * Graphics.frame_rate)
    cerca = 1.5 * Math::PI   # la fase en la que el columpio esta mas cerca
    tono = 100
    chirrio = false      # el chirrido suena una vez por vuelta, en lo mas lejos

    colocar = proc do
      th = amp * Math.sin(fase)
      z = largo * Math.sin(th)
      s = FOCAL / (FOCAL + z)
      cs = Math.cos(th)
      columpio.zoom_x = s
      columpio.zoom_y = s * cs
      gato.zoom_x = s
      gato.zoom_y = s
      gato.x = PIVOTE_X
      gato.y = PIVOTE_Y + (ASIENTO * cs + CULO) * s
      # alejandose se echa hacia delante; volviendo, quieto; muy cerca te mira
      velocidad = Math.cos(fase)
      pose = (velocidad > 0.15) ? 1 : 0
      pose = 2 if Math.sin(fase) < -0.75
      gato.src_rect = Rect.new(pose * fw, 0, fw, fh)
      halo.x = gato.x
      halo.y = gato.y - fh * s * 0.45
      halo.zoom_x = s
      halo.zoom_y = s
    end
    colocar.call

    OstMini.fundir(telon, 0, 20) { fase += w; colocar.call }

    # --- el juego ---------------------------------------------------------------
    while buenos < EMPUJES
      OstMini.tick
      fase += w
      fase -= 2.0 * Math::PI if fase >= 2.0 * Math::PI
      colocar.call
      margen = VENTANA[[buenos, VENTANA.length - 1].min] * 2.0 * Math::PI / PERIODO
      dist = (fase - cerca).abs
      en_ventana = dist <= margen
      ya_empujado = false if dist > margen * 2.5
      # la tecla y el halo se van encendiendo al acercarse el momento
      luz = 1.0 - [dist / (margen * 2.5), 1.0].min
      luz = 0.0 if ya_empujado
      brillo.opacity = (luz * luz * 255).to_i
      halo.opacity = (luz * luz * 170).to_i
      tecla.zoom_x = 1.0 + 0.10 * luz
      tecla.zoom_y = tecla.zoom_x
      chispa.opacity = [chispa.opacity - 14, 0].max
      chispa.zoom_x += 0.03
      chispa.zoom_y = chispa.zoom_x
      if pulsado?
        if en_ventana && !ya_empujado
          buenos += 1
          ya_empujado = true
          amp += AMP_PASO
          tono += 8
          OstMini.se("Columpio empuje", "Player jump", 70, 110)
          OstMini.se("Columpio acierto", "Mining ping", 90, tono)
          chispa.x = gato.x
          chispa.y = gato.y - fh * gato.zoom_y * 0.5
          chispa.zoom_x = 0.4
          chispa.zoom_y = 0.4
          chispa.opacity = 255
          dibujar_hoja(hojas[buenos - 1].bitmap, true)
          if buenos == 1
            cartel.each { |c| c.opacity = 0 }
          end
        elsif !ya_empujado
          amp = [amp - AMP_FALLO, AMP_MIN].max
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
    OstMini.opacidad(cartel, 0)
    # espera a que el columpio llegue a lo mas lejos
    loop do
      OstMini.tick
      fase += w
      fase -= 2.0 * Math::PI if fase >= 2.0 * Math::PI
      colocar.call
      chispa.opacity = [chispa.opacity - 14, 0].max
      break if (fase - 0.5 * Math::PI).abs < w * 1.5
    end
    # al saltar suena su grito de siempre, sin mas efecto encima
    begin
      GameData::Species.play_cry_from_species(:SPRIGATITO, 0, 90, 100)
    rescue
    end
    sj = salto ? salto.width / 2 : fw
    gato.bitmap = salto if salto
    gato.src_rect = Rect.new(0, 0, sj, salto ? salto.height : fh)
    gato.ox = sj / 2
    gato.oy = salto ? salto.height : fh
    x0 = gato.x
    y0 = gato.y
    s0 = gato.zoom_x
    n = 42
    n.times do |k|
      OstMini.tick
      fase += w
      amp = [amp * 0.985, AMP_MIN].max
      colocar_vacio(columpio, largo, amp, fase)
      t = (k + 1).to_f / n
      gato.bitmap = salto if salto
      gato.src_rect = Rect.new(0, 0, sj, salto ? salto.height : fh)
      gato.x = x0
      gato.y = y0 - 520 * t + 380 * t * t     # parabola: sube y empieza a caer
      gato.zoom_x = s0 * (1.0 - 0.45 * t)
      gato.zoom_y = gato.zoom_x
    end

    # destello blanco y cae delante, de frente, contento
    blanco = Sprite.new(vp)
    blanco.bitmap = Bitmap.new(OstMini::ANCHO, OstMini::ALTO)
    blanco.bitmap.fill_rect(0, 0, OstMini::ANCHO, OstMini::ALTO, Color.new(255, 255, 255))
    blanco.z = 850
    blanco.opacity = 0
    OstMini.fundir(blanco, 255, 40)
    gato.src_rect = Rect.new(sj, 0, sj, salto ? salto.height : fh)
    gato.x = 960
    gato.y = 1000
    gato.zoom_x = 1.25
    gato.zoom_y = 1.25
    gato.z = 20
    columpio.zoom_x = 1.0
    columpio.zoom_y = 1.0
    OstMini.se("Columpio acierto", "Mining ping", 90, 140)
    OstMini.fundir(blanco, 0, 16)
    # un saltito de alegria y un momento para verlo
    60.times do |k|
      OstMini.tick
      gato.y = 1000 - (Math.sin(k * Math::PI / 30.0).abs * 40).to_i
    end
    OstMini.fundir(telon, 255, 10)

    [fondo, halo, columpio, gato, tecla, brillo, chispa, blanco].each { |s| OstMini.soltar(s) }
    hojas.each { |h| OstMini.soltar(h) }
    cartel.each { |c| OstMini.soltar(c) }
    salto.dispose if salto && !salto.disposed?
    gato_bmp.dispose if gato_bmp && !gato_bmp.disposed?
    return true
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

  def self.dibujar_tecla(b, encendida)
    b.clear
    borde = Color.new(52, 36, 24)
    cara = encendida ? Color.new(255, 244, 200) : Color.new(247, 236, 208)
    b.fill_rect(6, 10, 288, 94, borde)
    b.fill_rect(10, 6, 280, 94, borde)
    b.fill_rect(12, 12, 276, 80, Color.new(214, 202, 176))
    b.fill_rect(12, 12, 276, 70, cara)
    begin
      b.font.name = "Cambria"
    rescue
    end
    b.font.size = 44
    b.font.bold = true
    b.font.color = Color.new(59, 50, 38)
    b.draw_text(0, 14, 300, 66, "ESPACIO", 1)
  end

  def self.dibujar_hoja(b, llena)
    b.clear
    borde = Color.new(40, 70, 30)
    relleno = llena ? Color.new(120, 200, 90) : Color.new(70, 90, 60, 150)
    [[16, 2, 8], [10, 8, 20], [6, 14, 28], [4, 20, 32], [6, 26, 28], [10, 32, 20], [16, 36, 8]].each do |x, y, w|
      b.fill_rect(x, y, w, 4, relleno)
    end
    b.fill_rect(19, 6, 2, 30, borde)
  end
end
