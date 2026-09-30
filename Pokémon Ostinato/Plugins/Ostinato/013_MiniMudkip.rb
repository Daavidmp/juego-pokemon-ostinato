#===============================================================================
# Pokemon Ostinato - Minijuego de Mudkip: la fuente
#
#   Mudkip esta sentado en el borde de la fuente de Pueblo Preludio. Sobre el
#   agua aparecen circulos con una tecla dentro (A, S, D o F) y una onda que se
#   va cerrando sobre cada uno. Hay que pulsar su tecla justo cuando la onda lo
#   toca: suena una nota, salpica y Mudkip da un saltito. Las notas caen en el
#   pulso de la musica de base. No se puede perder: la que se falla vuelve un
#   poco mas tarde. Al acertarlas todas, Mudkip lo celebra y la fuente salpica.
#
#   Arte en Graphics/Titles/MiniMudkip/ (fondo, circulo, anillo, acierto x5,
#   fallo x2, tecla_a/s/d/f x3), sacado de Firefly midiendo su rejilla de
#   pixel (5,73 px) y ampliado un numero entero de veces. Las teclas se hacen
#   a partir de la tecla ESPACIO del columpio. Mudkip: mudkip.png y mudkip_contento.png (o EscMudkip.png si faltan).
#   Musica: "Mini Mudkip base" (100,09 bpm, 48 pulsos exactos: da la vuelta sin
#   descuadrar el pulso). Notas: "Mudkip nota 1".."8",
#   una marimba en la pentatonica de Do, que es la tonalidad de la base.
#   Todo medido sobre el lienzo de 1920x1080 (usa OstMini, del 011).
#===============================================================================
module OstinatoMiniMudkip
  DIR = "Graphics/Titles/MiniMudkip/"
  BGM_BASE     = "Mini Mudkip base"

  PULSO    = 60.0 / 100.09   # segundos por pulso de la base
  LLEGADA  = 2               # pulsos que tarda la onda en cerrarse
  VENTANA  = 0.14            # segundos de margen para acertar
  AJUSTE   = 0.0             # retraso del audio, si hiciera falta afinar
  TECLAS   = [:A, :S, :D, :F]
  NOMBRES  = ["a", "s", "d", "f"]

  # En que pulso cae cada nota: primero una cada dos, luego mas seguidas
  NOTAS = [
    8, 10, 12, 14, 16, 18, 20, 22,
    24, 25, 26, 28, 29, 30, 32, 33, 34, 36, 37, 38,
    40, 41, 42, 43, 44, 46, 47, 48, 50, 51, 52, 54
  ]
  # Que nota suena en cada acierto (1..8, de grave a agudo): una frase que sube y baja
  MELODIA = [1, 2, 3, 5, 3, 2, 3, 1, 3, 5, 6, 5, 3, 5, 6, 8, 6, 5, 3, 2,
             5, 6, 8, 6, 5, 3, 5, 6, 8, 7, 6, 8]

  # Sitios del agua donde pueden salir los circulos (centro): todos en la
  # franja de Mudkip, a su altura, a izquierda y derecha de el (sin taparlo)
  SITIOS = [
    [200, 700], [370, 750], [530, 705], [690, 760],
    [1230, 760], [1390, 705], [1550, 750], [1720, 700]
  ]

  MUDKIP_X = 960           # Mudkip en medio, de pie en el borde (centro abajo)
  MUDKIP_Y = 985
  # Dibujo de Mudkip: mudkip.png (3 fotogramas quieto) y mudkip_contento.png
  # (2 fotogramas: el salto y la alegria), ya ampliados. Si aun no estan, se
  # usa EscMudkip.png a pixel de 2.

  def self.jugar
    ganado = false
    OstMini.pantalla(nil) do |vp, telon|
      ganado = juego(vp, telon)
    end
    return ganado
  end

  def self.arte(nombre)
    return OstMini.bmp(DIR + nombre + ".png")
  end

  def self.reloj
    begin
      return System.uptime
    rescue
      return Time.now.to_f
    end
  end

  def self.pulsada?(i)
    begin
      return Input.triggerex?(TECLAS[i])
    rescue
      return false
    end
  end

  #-----------------------------------------------------------------------------
  # Un circulo en el agua: el disco, la tecla dentro y la onda que se cierra
  #-----------------------------------------------------------------------------
  class Circulo
    attr_reader :pulso, :tecla, :x, :y, :estado
    def initialize(vp, bmps, pulso, tecla, x, y)
      @pulso = pulso
      @tecla = tecla
      @x = x
      @y = y
      @estado = :viene
      @t = 0
      @disco = Sprite.new(vp)
      @disco.bitmap = bmps[:circulo]
      @disco.ox = @disco.bitmap.width / 2
      @disco.oy = @disco.bitmap.height / 2
      @disco.x = x
      @disco.y = y
      @disco.z = 100
      @onda = Sprite.new(vp)
      @onda.bitmap = bmps[:anillo]
      @onda.ox = @onda.bitmap.width / 2
      @onda.oy = @onda.bitmap.height / 2
      @onda.x = x
      @onda.y = y
      @onda.z = 102
      @fin_onda = @disco.bitmap.width.to_f / @onda.bitmap.width   # la onda acaba justo en el borde
      @tec = Sprite.new(vp)
      @tec.bitmap = bmps[("tecla_" + NOMBRES[tecla]).to_sym]
      @tw = @tec.bitmap.width / 3
      @tec.src_rect = Rect.new(0, 0, @tw, @tec.bitmap.height)
      @tec.ox = @tw / 2
      @tec.oy = @tec.bitmap.height / 2
      @tec.x = x
      @tec.y = y
      @tec.z = 101
      [@disco, @onda, @tec].each { |s| s.opacity = 0 }
    end

    def momento
      return @pulso * PULSO
    end

    # t = segundos de musica
    def update(t)
      @t += 1
      case @estado
      when :viene
        falta = momento - t
        u = 1.0 - falta / (LLEGADA * PULSO)          # 0 al aparecer, 1 al llegar
        u = [[u, 0.0].max, 1.2].min
        entra = OstMini.sale([u / 0.18, 1.0].min)     # aparece rapido
        z = 0.7 + 0.3 * OstMini.rebote([u / 0.25, 1.0].min)
        @disco.opacity = (255 * entra).to_i
        @tec.opacity = @disco.opacity
        @disco.zoom_x = @disco.zoom_y = z
        @tec.zoom_x = @tec.zoom_y = z
        zo = @fin_onda * (1.0 + 1.4 * (1.0 - [u, 1.0].min))
        @onda.zoom_x = @onda.zoom_y = zo
        @onda.opacity = (230 * OstMini.suave([u / 0.5, 1.0].min)).to_i
        cerca = (t - momento).abs < 0.22
        @tec.src_rect = Rect.new((cerca ? 1 : 0) * @tw, 0, @tw, @tec.bitmap.height)
      when :bien
        # se hunde en el agua mientras salpica
        v = [@t / 10.0, 1.0].min
        @tec.src_rect = Rect.new(2 * @tw, 0, @tw, @tec.bitmap.height)
        [@disco, @tec].each { |s| s.opacity = (255 * (1 - v)).to_i; s.zoom_x = s.zoom_y = 1.0 + 0.25 * v }
        @onda.opacity = 0
        @estado = :fuera if v >= 1.0
      when :mal
        v = [@t / 18.0, 1.0].min
        [@disco, @tec, @onda].each { |s| s.opacity = (170 * (1 - v)).to_i }
        @disco.tone = Tone.new(0, 0, 0, 200)
        @tec.tone = Tone.new(0, 0, 0, 200)
        @estado = :fuera if v >= 1.0
      end
    end

    def acertar; @estado = :bien; @t = 0; end
    def fallar;  @estado = :mal;  @t = 0; end
    def fuera?;  @estado == :fuera; end
    def dispose; [@disco, @onda, @tec].each { |s| s.dispose if !s.disposed? }; end
  end

  #-----------------------------------------------------------------------------
  # Salpicaduras (acierto: 5 fotogramas; fallo: 2 fotogramas grises)
  #-----------------------------------------------------------------------------
  class Salpica
    def initialize(vp, bmp, frames, z, cuantas = 5)
      @b = bmp
      @n = frames
      @w = bmp.width / frames
      @s = []
      @t = []
      cuantas.times do
        s = Sprite.new(vp)
        s.bitmap = bmp
        s.ox = @w / 2
        s.oy = bmp.height - 30
        s.z = z
        s.visible = false
        @s.push(s)
        @t.push(-1)
      end
    end
    def lanzar(x, y, zoom = 1.0)
      i = @t.index(-1) || 0
      @s[i].x = x
      @s[i].y = y
      @s[i].zoom_x = @s[i].zoom_y = zoom
      @s[i].visible = true
      @s[i].opacity = 255
      @t[i] = 0
    end
    def update
      @s.each_with_index do |s, i|
        next if @t[i] < 0
        f = @t[i] / 5
        if f >= @n
          s.visible = false
          @t[i] = -1
          next
        end
        s.src_rect = Rect.new(f * @w, 0, @w, @b.height)
        s.opacity = 255 - [(@t[i] - (@n - 1) * 5) * 40, 0].max
        @t[i] += 1
      end
    end
    def dispose; @s.each { |s| s.dispose if !s.disposed? }; end
  end

  #-----------------------------------------------------------------------------
  # La barra de progreso, arriba a la derecha, en pixel de 8 como las teclas
  #-----------------------------------------------------------------------------
  def self.barra(vp)
    b = Bitmap.new(416, 48)
    borde = Color.new(52, 36, 24)
    papel = Color.new(247, 236, 208)
    b.fill_rect(8, 0, 400, 48, borde)
    b.fill_rect(0, 8, 416, 32, borde)
    b.fill_rect(8, 8, 400, 32, papel)
    s = Sprite.new(vp)
    s.bitmap = b
    s.x = 1440
    s.y = 32
    s.z = 700
    relleno = Sprite.new(vp)
    relleno.bitmap = Bitmap.new(400, 32)
    relleno.bitmap.fill_rect(0, 0, 400, 32, Color.new(79, 196, 196))
    relleno.bitmap.fill_rect(0, 0, 400, 8, Color.new(150, 232, 224))
    relleno.x = 1448
    relleno.y = 40
    relleno.z = 701
    relleno.src_rect = Rect.new(0, 0, 0, 32)
    return [s, relleno]
  end

  #-----------------------------------------------------------------------------
  def self.juego(vp, telon)
    fondo = OstMini.fondo(vp, DIR + "fondo.png")
    bmps = {}
    ["circulo", "anillo", "acierto", "fallo", "tecla_a", "tecla_s", "tecla_d", "tecla_f"].each do |n|
      bmps[n.to_sym] = arte(n)
    end

    # Mudkip en medio, en el borde de la fuente
    quieto = arte("mudkip")
    contento = arte("mudkip_contento")
    mud = Sprite.new(vp)
    if quieto
      mw = quieto.width / 3
      mh = quieto.height
      mud_n = 0
      mud.bitmap = quieto
    else
      contento.dispose if contento
      contento = nil
      mud.bitmap = OstMini.bmp("Graphics/Titles/EscMudkip.png")
      mw = 176
      mh = 196
      mud_n = [(mud.bitmap.width / mw) * (mud.bitmap.height / mh), 76].min
      mud.zoom_x = mud.zoom_y = 2.0
    end
    mud.src_rect = Rect.new(0, 0, mw, mh)
    mud.ox = mw / 2
    mud.oy = mh
    mud.x = MUDKIP_X
    mud.y = MUDKIP_Y
    mud.z = 300
    # que fotograma toca: quieto respira 0-1-2-1; al saltar, contento 0 y luego 1
    pose = proc do |f, alegre|
      if !quieto
        mud.src_rect = Rect.new(((f / 4) % mud_n % 10) * mw, (((f / 4) % mud_n) / 10) * mh, mw, mh)
      elsif alegre && contento
        cw = contento.width / 2
        mud.bitmap = contento
        mud.src_rect = Rect.new((alegre == 1 ? cw : 0), 0, cw, contento.height)
        mud.ox = cw / 2
        mud.oy = contento.height
      else
        mud.bitmap = quieto
        mud.src_rect = Rect.new([0, 1, 2, 1][(f / 12) % 4] * mw, 0, mw, mh)
        mud.ox = mw / 2
        mud.oy = mh
      end
    end
    sombra = Sprite.new(vp)
    sombra.bitmap = OstMini.bmp(OstMini::COMUN + "sombra.png")
    sombra.ox = sombra.bitmap.width / 2
    sombra.oy = sombra.bitmap.height / 2
    sombra.x = MUDKIP_X
    sombra.y = MUDKIP_Y - 10
    sombra.zoom_x = sombra.zoom_y = 1.3
    sombra.z = 299

    bien = Salpica.new(vp, bmps[:acierto], 5, 120)
    mal  = Salpica.new(vp, bmps[:fallo], 2, 120)
    chispas = OstMini::Chispas.new(vp, 595, 6)
    ambiente = OstMini::Ambiente.new(vp, 500, [0, 1, 0, 1])
    cartel = OstMini.cartel(vp, "MiniMudTxt00")
    progreso = barra(vp)

    # las notas pendientes: [pulso, tecla, nota]
    pendientes = []
    ultima_tecla = -1
    NOTAS.each_with_index do |p, i|
      opciones = (0...4).to_a - [ultima_tecla]
      tecla = opciones[rand(opciones.length)]
      ultima_tecla = tecla
      pendientes.push([p, tecla, MELODIA[i % MELODIA.length]])
    end
    total = pendientes.length
    aciertos = 0
    activos = []            # Circulo en pantalla, con su nota
    ultimo_sitio = []
    fotograma = 0
    salto = 0
    quitar_cartel = false

    # lo que se mueve solo en cada fotograma
    mover = proc do |t|
      OstMini.tick
      fotograma += 1
      if salto > 0
        salto -= 1
        u = 1.0 - salto / 12.0
        mud.y = MUDKIP_Y - (26 * Math.sin(u * Math::PI)).to_i
        pose.call(fotograma, salto >= 5 ? 0 : 1)
      else
        mud.y = MUDKIP_Y
        pose.call(fotograma, nil)
      end
      activos.each { |c| c[0].update(t) }
      bien.update
      mal.update
      chispas.update
      ambiente.update
      OstMini.temblor(vp)
      if quitar_cartel
        cartel.each { |c| c.opacity = [c.opacity - 12, 0].max }
      end
    end

    OstMini.fundir(telon, 0, 20) { ambiente.update }
    $game_system.bgm_memorize
    begin
      pbBGMPlay(BGM_BASE, 90)
    rescue
    end
    t0 = reloj

    # --- el juego ---------------------------------------------------------------
    while aciertos < total
      t = reloj - t0 - AJUSTE
      quitar_cartel = true if t > 6 * PULSO
      # aparecen los que ya tienen que venir
      while pendientes.length > 0 && pendientes[0][0] * PULSO - LLEGADA * PULSO <= t
        p, tecla, nota = pendientes.shift
        libres = SITIOS.each_index.to_a - ultimo_sitio
        libres = libres.select do |k|
          activos.all? { |c| (SITIOS[k][0] - c[0].x).abs + (SITIOS[k][1] - c[0].y).abs > 300 }
        end
        libres = SITIOS.each_index.to_a - ultimo_sitio if libres.empty?
        k = libres[rand(libres.length)]
        ultimo_sitio = (ultimo_sitio + [k]).last(3)
        activos.push([Circulo.new(vp, bmps, p, tecla, SITIOS[k][0], SITIOS[k][1]), nota])
      end
      # teclas: acierta el circulo de esa tecla que mas cerca este de su momento
      4.times do |i|
        next if !pulsada?(i)
        mejor = nil
        activos.each do |c|
          next if c[0].estado != :viene || c[0].tecla != i
          d = (t - c[0].momento).abs
          mejor = c if d <= VENTANA && (!mejor || d < (t - mejor[0].momento).abs)
        end
        next if !mejor
        mejor[0].acertar
        aciertos += 1
        OstMini.se("Mudkip nota " + mejor[1].to_s, "Mining ping", 90, 100)
        bien.lanzar(mejor[0].x, mejor[0].y + 70)
        chispas.lanzar(mejor[0].x, mejor[0].y - 40, 0.8)
        salto = 12
        OstMini.temblar(3)
        progreso[1].src_rect = Rect.new(0, 0, (400 * aciertos / total / 8) * 8, 32)
      end
      # los que se han pasado: fallo, y la nota vuelve mas adelante
      activos.each do |c|
        next if c[0].estado != :viene || t <= c[0].momento + VENTANA
        c[0].fallar
        OstMini.se("Mudkip fallo", "GUI sel buzzer", 70, 100)
        mal.lanzar(c[0].x, c[0].y + 70)
        ultimo = pendientes.length > 0 ? pendientes[-1][0] : (t / PULSO).ceil
        nuevo = [ultimo + 2, (t / PULSO).ceil + LLEGADA + 2].max
        pendientes.push([nuevo, c[0].tecla, c[1]])
      end
      activos.each { |c| c[0].dispose if c[0].fuera? }
      activos.reject! { |c| c[0].fuera? }
      mover.call(t)
    end

    # --- el final: la base se apaga, Mudkip grita contento y la fuente salpica --
    30.times { mover.call(reloj - t0) }
    begin
      pbBGMFade(1.5)
    rescue
    end
    begin
      GameData::Species.play_cry_from_species(:MUDKIP, 0, 90, 100)
    rescue
    end
    fin = reloj
    siguiente = 0.0
    while reloj - fin < 2.6
      u = reloj - fin
      if u >= siguiente
        s = SITIOS[rand(SITIOS.length)]
        bien.lanzar(s[0], s[1] + 70, 0.8 + rand * 0.4)
        chispas.lanzar(s[0], s[1] - 30, 0.7)
        salto = 12 if salto <= 0
        siguiente += PULSO
      end
      mover.call(reloj - t0)
    end
    OstMini.fundir(telon, 255, 8) { ambiente.update }
    $game_system.bgm_restore

    activos.each { |c| c[0].dispose }
    [bien, mal, chispas, ambiente].each { |o| o.dispose }
    [fondo, mud, sombra].each { |s| OstMini.soltar(s) }
    [quieto, contento].each { |b| b.dispose if b && !b.disposed? }
    progreso.each { |s| OstMini.soltar(s) }
    cartel.each { |c| OstMini.soltar(c) }
    bmps.each_value { |b| b.dispose if b && !b.disposed? }
    return true
  end
end
