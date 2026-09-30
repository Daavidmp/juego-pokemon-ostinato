#===============================================================================
# Pokemon Ostinato - Minijuego de Fennekin: la cola entre los arbustos
#
#   Un prado con siete arbustos (tres al fondo, cuatro delante). Con el RATON
#   se mueve un martillo de juguete; al hacer clic da un golpe, como quien
#   clava un clavo. La cola de Fennekin sube de un arbusto, se menea un rato y
#   se vuelve a esconder; hay que darle. Cada vez asoma menos tiempo y algun
#   arbusto se mueve sin nada dentro para despistar. A la quinta, Fennekin
#   sale de un salto. No se puede perder: si no le das, asoma en otro.
#
#   El arte va en Graphics/Titles/MiniFennekin/ (fondo, arbusto, cola,
#   fennekin_sale, martillo, golpe, icono_llama), sacado de Firefly con
#   Downloads/mini_fennekin/proceso/procesar.py. Todo esta medido sobre el
#   lienzo de 1920x1080 (usa OstMini, del 011).
#===============================================================================
module OstinatoMiniFennekin
  DIR = "Graphics/Titles/MiniFennekin/"
  BGM = "Mini Fennekin"
  CAPTURAS = 5

  # x, y de la base de cada arbusto y su escala. Los de atras a 0,75: sus
  # pixeles de 8 quedan en 6 exactos, sin deformarse.
  ARBUSTOS = [
    [ 520, 830, 0.75], [ 960, 810, 0.75], [1400, 830, 0.75],
    [ 300, 1060, 1.0], [ 740, 1075, 1.0], [1180, 1075, 1.0], [1620, 1060, 1.0]
  ]
  ASOMA  = [1.80, 1.50, 1.25, 1.05, 0.90]   # segundos que se ve la cola, cada vez menos
  PAUSA  = [0.9, 1.6]                        # segundos entre una asomada y la siguiente
  SENUELO = 0.35                             # probabilidad de que otro arbusto se mueva a la vez
  GOLPE_F = 12                               # fotogramas que dura el golpe del martillo
  IMPACTO = 3                                # fotograma del golpe en el que cae la cabeza
  CABEZA_X = 0.584                           # centro de la cabeza del martillo en su dibujo (en
  CABEZA_Y = 0.490                           # fraccion del fotograma): el raton apunta ahi
  SUBE_F = 11                                # fotogramas que tarda la cola en salir
  BAJA_F = 9                                 # y en esconderse
  SUELO  = 1040                              # donde aterriza Fennekin al final

  def self.jugar
    ganado = false
    OstMini.pantalla(BGM) do |vp, telon|
      ganado = juego(vp, telon)
    end
    return ganado
  end

  def self.arte(nombre)
    return OstMini.bmp(DIR + nombre + ".png")
  end

  #-----------------------------------------------------------------------------
  def self.raton
    begin
      x = Input.mouse_x
      y = Input.mouse_y
      return [x, y] if x && y
    rescue
    end
    return [OstMini::ANCHO / 2, OstMini::ALTO / 2]
  end

  def self.clic?
    begin
      return true if Input.trigger?(Input::MOUSELEFT)
    rescue
    end
    return false
  end

  def self.segundos(s)
    return (s * Graphics.frame_rate).to_i
  end

  #-----------------------------------------------------------------------------
  # La cola de un arbusto: sube desde detras de las hojas, se menea, y baja.
  # Se dibuja desde su punta hacia abajo y se recorta antes del pie del arbusto,
  # asi nunca asoma por debajo.
  #-----------------------------------------------------------------------------
  class Cola
    attr_reader :estado, :sprite
    def initialize(vp, bmp, d, aw, ah, z)
      @b = bmp
      @cw = bmp.width / 3
      @ch = bmp.height
      @x, @base, @esc = d
      @s = Sprite.new(vp)
      @s.bitmap = bmp
      @s.ox = @cw / 2
      @s.oy = 0
      @s.x = @x
      @s.zoom_x = @esc
      @s.zoom_y = @esc
      @s.z = z
      @s.visible = false
      @arriba = @base - ah * @esc * 0.93             # la copa del arbusto
      @fuera = @base - ah * @esc * 0.72 - @ch * @esc  # punta de la cola, del todo fuera
      @corte = @base - ah * @esc * 0.60               # la cola no se dibuja por debajo de aqui
      @dentro = @arriba + 24 * @esc                   # punta de la cola, escondida
      @estado = nil
      @t = 0
      @p = 0.0
      @desde = 1.0
    end
    def sacar; @estado = :sube; @t = 0; end
    def esconder
      return if !@estado || @estado == :baja
      @desde = @p          # baja desde donde este, aunque no hubiera salido del todo
      @estado = :baja
      @t = 0
    end
    def golpear; @estado = :golpe; @t = 0; end
    def visible?; @estado == :fuera || (@estado == :sube && @t >= 3); end
    def fuera?; @estado == :fuera || @estado == :sube; end

    # la punta del martillo cae dentro de lo que se ve de la cola (con margen)
    def dentro?(px, py)
      return false if !visible?
      ancho = @cw * @esc * 0.5 + 30
      return false if px < @s.x - ancho || px > @s.x + ancho
      return py >= @s.y - 30 && py <= @arriba + 40
    end

    def update
      return if !@estado
      @t += 1
      f = 0
      zx = @esc
      zy = @esc
      case @estado
      when :sube
        p = OstMini.rebote(@t.to_f / SUBE_F)
        if @t >= SUBE_F
          @estado = :fuera
          @t = 0
        end
      when :fuera
        p = 1.0
        f = (@t < 6) ? 0 : [0, 1, 0, 2][(@t / 7) % 4]    # meneo: centro, izquierda, centro, derecha
      when :baja
        p = @desde * (1.0 - OstMini.entra(@t.to_f / BAJA_F))
        if @t >= BAJA_F
          @estado = nil
          @s.visible = false
          return
        end
      when :golpe
        # se aplasta con el golpe y se mete de golpe
        if @t <= 4
          p = 1.0
          zx = @esc * 1.25
          zy = @esc * 0.72
        else
          p = 1.0 - OstMini.sale((@t - 4) / 7.0)
        end
        if @t >= 11
          @estado = nil
          @s.visible = false
          return
        end
      end
      @p = p
      top = @dentro + (@fuera - @dentro) * p
      top += (@esc - zy) * @ch          # aplastada, la punta baja
      hvis = [[(@corte - top) / zy, @ch].min, 0].max.to_i
      @s.zoom_x = zx
      @s.zoom_y = zy
      @s.y = top.round
      @s.src_rect = Rect.new(f * @cw, 0, @cw, hvis)
      @s.visible = true
    end
    def dispose; @s.dispose if !@s.disposed?; end
  end

  #-----------------------------------------------------------------------------
  def self.juego(vp, telon)
    begin
      Graphics.show_cursor = false
    rescue
    end

    fondo = OstMini.fondo(vp, DIR + "fondo.png")

    ab = arte("arbusto")
    aw = ab.width / 3
    ah = ab.height
    cola_b = arte("cola")
    sombra_b = OstMini.bmp(OstMini::COMUN + "sombra.png")

    # cada arbusto: su sombra, la cola detras y el arbusto delante
    matas = []
    colas = []
    sombras = []
    ARBUSTOS.each_with_index do |d, i|
      sb = Sprite.new(vp)
      sb.bitmap = sombra_b
      sb.ox = sombra_b.width / 2
      sb.oy = sombra_b.height / 2
      sb.x = d[0]
      sb.y = d[1] - (14 * d[2]).to_i
      sb.zoom_x = d[2]
      sb.zoom_y = d[2]
      sb.z = 5
      sombras.push(sb)
      colas.push(Cola.new(vp, cola_b, d, aw, ah, 10 + i * 2))
      s = Sprite.new(vp)
      s.bitmap = ab
      s.src_rect = Rect.new(0, 0, aw, ah)
      s.ox = aw / 2
      s.oy = ah
      s.x = d[0]
      s.y = d[1]
      s.zoom_x = d[2]
      s.zoom_y = d[2]
      s.z = 11 + i * 2
      matas.push(s)
    end

    martillo = Sprite.new(vp)
    mb = arte("martillo")
    mw = mb.width / 3
    martillo.bitmap = mb
    martillo.src_rect = Rect.new(0, 0, mw, mb.height)
    martillo.ox = (mw * CABEZA_X).to_i
    martillo.oy = (mb.height * CABEZA_Y).to_i
    martillo.z = 600

    golpe = Sprite.new(vp)
    gb = arte("golpe")
    gw = gb.width / 4
    golpe.bitmap = gb
    golpe.src_rect = Rect.new(0, 0, gw, gb.height)
    golpe.ox = gw / 2
    golpe.oy = gb.height / 2
    golpe.z = 590
    golpe.visible = false

    # las cinco llamitas del progreso, arriba a la derecha
    llamas = []
    CAPTURAS.times do |i|
      llamas.push(OstMini::Icono.new(vp, DIR + "icono_llama.png", 1580 + i * 62, 30))
    end

    chispas = OstMini::Chispas.new(vp, 595)
    viento = OstMini::Ambiente.new(vp, 500, [0, 1, 1, 0, 1])
    cartel = OstMini.cartel(vp, "MiniFenTxt00")

    pillados = 0
    t = 0
    meneo = Array.new(ARBUSTOS.length, 0)    # fotogramas que le quedan de sacudida a cada arbusto
    fuerza = Array.new(ARBUSTOS.length, 1)   # y con cuantos empezo (para que se vaya calmando)
    donde = -1                              # arbusto con la cola fuera (-1: ninguno)
    ultimo = -1
    queda = segundos(PAUSA[0])              # fotogramas hasta el siguiente cambio
    golpeando = 0
    golpe_t = -1
    quitar_cartel = false

    menear = proc do |i, n|
      meneo[i] = n
      fuerza[i] = n
    end

    # lo que se mueve solo en cada fotograma: arbustos, colas, martillo, efectos
    mover = proc do
      OstMini.tick
      t += 1
      mx, my = raton
      martillo.x = mx
      martillo.y = my
      # quietos respiran un poco de lado a lado; sacudidos alternan sus dos poses con hojas
      matas.each_with_index do |s, i|
        d = ARBUSTOS[i]
        if meneo[i] > 0
          r = meneo[i].to_f / fuerza[i]
          s.src_rect = Rect.new((1 + (meneo[i] / 4) % 2) * aw, 0, aw, ah)
          s.x = d[0] + (Math.sin(meneo[i] * 1.4) * 8 * d[2] * r).round
          meneo[i] -= 1
        else
          s.src_rect = Rect.new(0, 0, aw, ah)
          s.x = d[0] + (Math.sin(t * 0.03 + i * 1.7) * 2).round
        end
      end
      colas.each { |c| c.update }
      if golpe_t >= 0
        golpe.src_rect = Rect.new([golpe_t / 3, 3].min * gw, 0, gw, gb.height)
        golpe_t += 1
        if golpe_t > 12
          golpe.visible = false
          golpe_t = -1
        end
      end
      chispas.update
      llamas.each { |l| l.update }
      viento.update
      OstMini.temblor(vp)
      if quitar_cartel
        cartel.each { |c| c.opacity = [c.opacity - 18, 0].max }
      end
    end

    OstMini.fundir(telon, 0, 20) { viento.update }

    while pillados < CAPTURAS
      mover.call
      mx, my = raton

      # la cola
      queda -= 1
      if donde >= 0
        if queda <= 0 && colas[donde].fuera?
          colas[donde].esconder
          menear.call(donde, 10)
          donde = -1
          queda = segundos(PAUSA[0] + rand * (PAUSA[1] - PAUSA[0]))
        end
      elsif queda <= 0
        opciones = (0...ARBUSTOS.length).to_a - [ultimo]
        donde = opciones[rand(opciones.length)]
        ultimo = donde
        colas[donde].sacar
        menear.call(donde, 16)
        OstMini.se("Arbusto crujido", "GUI sel cursor", 70, 100)
        if rand < SENUELO * (pillados + 1) / CAPTURAS.to_f + 0.1
          otro = ((0...ARBUSTOS.length).to_a - [donde])
          menear.call(otro[rand(otro.length)], 22)
        end
        queda = segundos(ASOMA[pillados])
      end

      # el martillo: se inclina, cae (y se aplasta la cabeza) y vuelve a subir
      if golpeando > 0
        golpeando -= 1
        paso = GOLPE_F - golpeando
        f = (paso < IMPACTO) ? 1 : ((paso < IMPACTO + 5) ? 2 : ((paso < IMPACTO + 8) ? 1 : 0))
        martillo.src_rect = Rect.new(f * mw, 0, mw, mb.height)
        martillo.y = my + ((paso >= IMPACTO && paso < IMPACTO + 3) ? 6 : 0)
        if paso == IMPACTO
          if donde >= 0 && colas[donde].dentro?(mx, my)
            pillados += 1
            OstMini.se("Martillo pi", "Mining hammer", 90, 130)
            begin
              GameData::Species.play_cry_from_species(:FENNEKIN, 0, 85, 100)
            rescue
            end
            llamas[pillados - 1].encender
            chispas.lanzar(llamas[pillados - 1].x, llamas[pillados - 1].y, 0.5)
            chispas.lanzar(mx, my - 40)
            OstMini.temblar(7)
            quitar_cartel = true
            colas[donde].golpear
            menear.call(donde, 18)
            donde = -1
            queda = segundos(PAUSA[0] + rand * (PAUSA[1] - PAUSA[0]))
            golpe.zoom_x = golpe.zoom_y = 1.0
            golpe.opacity = 255
          else
            OstMini.se("Martillo pof", "Mining pick", 70, 90)
            golpe.zoom_x = golpe.zoom_y = 0.5
            golpe.opacity = 190
          end
          golpe.x = mx
          golpe.y = my
          golpe.src_rect = Rect.new(0, 0, gw, gb.height)
          golpe.visible = true
          golpe_t = 0
        end
      elsif clic?
        golpeando = GOLPE_F
        OstMini.se("Martillo zas", nil, 60, 100)
      else
        martillo.src_rect = Rect.new(0, 0, mw, mb.height)
      end
    end

    # --- el final: Fennekin sale de un salto del ultimo arbusto -----------------
    quitar_cartel = true
    colas.each { |c| c.esconder if c.estado }
    martillo.src_rect = Rect.new(0, 0, mw, mb.height)
    base = ARBUSTOS[ultimo]
    # primero el arbusto se sacude con ganas
    menear.call(ultimo, 26)
    OstMini.se("Arbusto crujido", "GUI sel cursor", 80, 90)
    26.times { |k| mover.call; OstMini.se("Arbusto crujido", "GUI sel cursor", 70, 110) if k == 12 }

    sale = Sprite.new(vp)
    sale.bitmap = arte("fennekin_sale")
    sale.ox = sale.bitmap.width / 2
    sale.oy = sale.bitmap.height - 4
    sale.z = matas[ultimo].z - 1
    sombra = Sprite.new(vp)
    sombra.bitmap = sombra_b
    sombra.ox = sombra_b.width / 2
    sombra.oy = sombra_b.height / 2
    sombra.x = 960
    sombra.y = SUELO - 8
    sombra.z = 390
    sombra.opacity = 0
    menear.call(ultimo, 20)
    begin
      GameData::Species.play_cry_from_species(:FENNEKIN, 0, 90, 100)
    rescue
    end
    y_ini = base[1] - ah * base[2] * 0.35
    n = 48
    n.times do |k|
      mover.call
      u = (k + 1).to_f / n
      sale.z = 400 if k == 8        # ya ha salido de entre las hojas: por delante de todo
      # sube estirado, se queda un instante arriba y cae delante, en el centro
      sale.x = (base[0] + (960 - base[0]) * OstMini.suave(u)).to_i
      sale.y = (y_ini + (SUELO - y_ini) * u - 440 * Math.sin(u * Math::PI)).to_i
      esc = base[2] + (1.0 - base[2]) * u
      estira = 0.16 * (1 - u) ** 2 + 0.08 * OstMini.entra(u)   # al salir y al llegar abajo
      sale.zoom_x = esc * (1.0 - estira * 0.5)
      sale.zoom_y = esc * (1.0 + estira)
      sombra.opacity = (255 * OstMini.entra(u)).to_i
      sombra.zoom_x = 0.6 + 0.4 * u
      sombra.zoom_y = sombra.zoom_x
    end
    sale.y = SUELO
    OstMini.se("Martillo pi", "Mining hammer", 90, 150)
    chispas.lanzar(960, SUELO - sale.bitmap.height / 2)
    OstMini.temblar(8)
    OstinatoMiniSprigatito.brincar(sale, sombra, mover, [0.22, 0.10], [64, 26])
    30.times { mover.call }
    OstMini.fundir(telon, 255, 10) { viento.update }

    begin
      Graphics.show_cursor = true
    rescue
    end
    [fondo, martillo, golpe, sale].each { |s| OstMini.soltar(s) }
    sombra.dispose if !sombra.disposed?
    (matas + sombras).each { |s| s.dispose if s && !s.disposed? }
    colas.each { |c| c.dispose }
    [ab, cola_b, sombra_b].each { |b| b.dispose if !b.disposed? }
    llamas.each { |l| l.dispose }
    [chispas, viento].each { |o| o.dispose }
    cartel.each { |c| OstMini.soltar(c) }
    return true
  end
end
