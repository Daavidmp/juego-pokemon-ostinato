#===============================================================================
# Pokemon Ostinato - Minijuego de Fennekin: la cola entre los arbustos
#
#   Un prado con siete arbustos (tres al fondo, cuatro delante) que se mecen.
#   Con el RATON se mueve un martillo de juguete; al hacer clic da un golpe,
#   como quien clava un clavo. La cola de Fennekin asoma de un arbusto un rato
#   y hay que darle. Cada vez asoma menos tiempo y algun arbusto se mueve sin
#   nada dentro para despistar. A la quinta, Fennekin sale de un salto.
#   No se puede perder: si no le das, asoma en otro arbusto.
#
#   El arte va en Graphics/Titles/MiniFennekin/ (fondo, arbusto, cola,
#   fennekin_sale, martillo, golpe). Mientras falte alguna pieza se dibuja una
#   provisional por codigo, asi que el juego ya se puede probar.
#   Todo esta medido sobre el lienzo de 1920x1080 (usa OstMini, del 011).
#===============================================================================
module OstinatoMiniFennekin
  DIR = "Graphics/Titles/MiniFennekin/"
  BGM = "Mini Fennekin"
  CAPTURAS = 5

  # x, y de la base de cada arbusto y su escala: los de atras, mas pequenos
  ARBUSTOS = [
    [ 520, 600, 0.80], [ 960, 580, 0.80], [1400, 600, 0.80],
    [ 300, 900, 1.00], [ 740, 920, 1.00], [1180, 920, 1.00], [1620, 900, 1.00]
  ]
  ASOMA  = [1.80, 1.50, 1.25, 1.05, 0.90]   # segundos que se ve la cola, cada vez menos
  PAUSA  = [0.9, 1.6]                        # segundos entre una asomada y la siguiente
  SENUELO = 0.35                             # probabilidad de que otro arbusto se mueva a la vez
  GOLPE_F = 14                               # fotogramas que dura el golpe del martillo
  CABEZA_X = 0.47                            # centro de la cabeza del martillo en su dibujo (en fraccion del
  CABEZA_Y = 0.22                            # fotograma): el raton apunta ahi, y ahi cae el golpe

  def self.jugar
    ganado = false
    OstMini.pantalla(BGM) do |vp, telon|
      ganado = juego(vp, telon)
    end
    return ganado
  end

  #-----------------------------------------------------------------------------
  # Arte (o su provisional)
  #-----------------------------------------------------------------------------
  def self.arte(nombre)
    b = OstMini.bmp(DIR + nombre + ".png")
    return b if b
    return provisional(nombre)
  end

  def self.mancha(b, cx, cy, rx, ry, color)
    y = -ry
    while y <= ry
      ancho = (rx * Math.sqrt([1.0 - (y.to_f / ry) ** 2, 0.0].max)).to_i
      b.fill_rect(cx - ancho, cy + y, ancho * 2, 1, color)
      y += 1
    end
  end

  def self.provisional(nombre)
    case nombre
    when "fondo"
      b = Bitmap.new(OstMini::ANCHO, OstMini::ALTO)
      b.fill_rect(0, 0, OstMini::ANCHO, 380, Color.new(150, 205, 240))
      b.fill_rect(0, 300, OstMini::ANCHO, 120, Color.new(70, 140, 80))
      b.fill_rect(0, 420, OstMini::ANCHO, 660, Color.new(120, 190, 90))
      b.fill_rect(0, 700, OstMini::ANCHO, 380, Color.new(105, 175, 80))
      return b
    when "arbusto"      # 3 fotogramas de 260x220, meciendose
      b = Bitmap.new(780, 220)
      3.times do |k|
        dx = k * 260 + (k - 1) * 6
        mancha(b, dx + 130, 150, 125, 70, Color.new(40, 90, 45))
        mancha(b, dx + 90, 110, 70, 60, Color.new(60, 130, 60))
        mancha(b, dx + 170, 105, 70, 62, Color.new(60, 130, 60))
        mancha(b, dx + 130, 85, 60, 55, Color.new(80, 160, 75))
      end
      return b
    when "cola"         # 3 fotogramas de 120x140: asomando, meneandose, del todo
      b = Bitmap.new(360, 140)
      3.times do |k|
        dx = k * 120
        alto = [60, 95, 120][k]
        mancha(b, dx + 60, 140 - alto / 2, 26, alto / 2, Color.new(235, 150, 60))
        mancha(b, dx + 60 + (k - 1) * 6, 140 - alto + 16, 20, 20, Color.new(250, 230, 200))
      end
      return b
    when "fennekin_sale"
      b = Bitmap.new(300, 300)
      mancha(b, 150, 200, 90, 80, Color.new(240, 180, 90))
      mancha(b, 150, 110, 70, 65, Color.new(250, 200, 110))
      mancha(b, 95, 50, 22, 45, Color.new(230, 140, 60))
      mancha(b, 205, 50, 22, 45, Color.new(230, 140, 60))
      return b
    when "martillo"     # 3 fotogramas de 160x160: en alto, bajando, golpe
      b = Bitmap.new(480, 160)
      3.times do |k|
        dx = k * 160
        caida = [0, 20, 42][k]
        b.fill_rect(dx + 70, 40 + caida / 2, 18, 110 - caida / 2, Color.new(150, 100, 50))
        b.fill_rect(dx + 20, 10 + caida, 110, 50, Color.new(230, 70, 70))
        b.fill_rect(dx + 20, 10 + caida, 110, 12, Color.new(250, 140, 140))
      end
      return b
    when "golpe"        # 4 fotogramas de 200x200: estrellitas que se abren
      b = Bitmap.new(800, 200)
      4.times do |k|
        r = 30 + k * 20
        8.times do |i|
          a = i * Math::PI / 4
          x = k * 200 + 100 + (Math.cos(a) * r).to_i
          y = 100 + (Math.sin(a) * r).to_i
          b.fill_rect(x - 7, y - 7, 14, 14, Color.new(255, 240, 120))
        end
      end
      return b
    end
    return Bitmap.new(8, 8)
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
  def self.juego(vp, telon)
    begin
      Graphics.show_cursor = false
    rescue
    end

    fondo = Sprite.new(vp)
    fondo.bitmap = arte("fondo")
    fondo.z = 0

    ab = arte("arbusto")
    aw = ab.width / 3
    ah = ab.height
    cola_b = arte("cola")
    cw = cola_b.width / 3
    ch = cola_b.height

    # cada arbusto: su sprite y, detras, el de la cola (que asoma por arriba)
    matas = []
    colas = []
    ARBUSTOS.each_with_index do |d, i|
      c = Sprite.new(vp)
      c.bitmap = cola_b
      c.src_rect = Rect.new(0, 0, cw, ch)
      c.ox = cw / 2
      c.oy = ch
      c.x = d[0] + (aw * d[2] * 0.18).to_i
      c.y = d[1] - (ah * d[2] * 0.62).to_i
      c.zoom_x = d[2]
      c.zoom_y = d[2]
      c.z = 10 + i * 2
      c.visible = false
      colas.push(c)
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
      l = Sprite.new(vp)
      l.bitmap = Bitmap.new(40, 48)
      dibujar_llama(l.bitmap, false)
      l.x = 1590 + i * 56
      l.y = 36
      l.z = 700
      llamas.push(l)
    end

    cartel = OstMini.cartel(vp, "MiniFenTxt00")

    pillados = 0
    t = 0
    meneo = Array.new(ARBUSTOS.length, 0)    # fotogramas que le quedan de sacudida a cada arbusto
    donde = -1                              # arbusto con la cola fuera (-1: ninguno)
    ultimo = -1
    queda = segundos(PAUSA[0])              # fotogramas hasta el siguiente cambio
    golpeando = 0
    golpe_t = -1

    OstMini.fundir(telon, 0, 20)

    while pillados < CAPTURAS
      OstMini.tick
      t += 1
      mx, my = raton
      martillo.x = mx
      martillo.y = my

      # los arbustos se mecen solos, y mas si hay algo moviendose dentro
      matas.each_with_index do |s, i|
        f = (t / 16 + i) % 3
        if meneo[i] > 0
          f = (t / 3) % 3
          meneo[i] -= 1
        end
        s.src_rect = Rect.new(f * aw, 0, aw, ah)
      end

      # la cola
      queda -= 1
      if donde >= 0
        edad = segundos(ASOMA[pillados]) - queda
        colas[donde].src_rect = Rect.new(((edad < 8) ? 0 : ((edad / 10) % 2 + 1)) * cw, 0, cw, ch)
        if queda <= 0
          esconder(colas, donde, matas, meneo)
          donde = -1
          queda = segundos(PAUSA[0] + rand * (PAUSA[1] - PAUSA[0]))
        end
      elsif queda <= 0
        opciones = (0...ARBUSTOS.length).to_a - [ultimo]
        donde = opciones[rand(opciones.length)]
        ultimo = donde
        colas[donde].visible = true
        colas[donde].src_rect = Rect.new(0, 0, cw, ch)
        meneo[donde] = 18
        OstMini.se("Arbusto crujido", "GUI sel cursor", 70, 100)
        if rand < SENUELO * (pillados + 1) / CAPTURAS.to_f + 0.1
          otro = ((0...ARBUSTOS.length).to_a - [donde])
          meneo[otro[rand(otro.length)]] = 22
        end
        queda = segundos(ASOMA[pillados])
      end

      # el martillo
      if golpeando > 0
        golpeando -= 1
        paso = GOLPE_F - golpeando
        f = (paso < 4) ? 1 : ((paso < 9) ? 2 : 0)
        martillo.src_rect = Rect.new(f * mw, 0, mw, mb.height)
        if paso == 4
          px = mx
          py = my
          if donde >= 0 && dentro?(colas[donde], px, py, cw, ch)
            pillados += 1
            OstMini.se("Martillo pi", "Mining hammer", 90, 130)
            begin
              GameData::Species.play_cry_from_species(:FENNEKIN, 0, 85, 100)
            rescue
            end
            dibujar_llama(llamas[pillados - 1].bitmap, true)
            cartel.each { |c| c.opacity = 0 } if pillados == 1
            esconder(colas, donde, matas, meneo)
            donde = -1
            queda = segundos(PAUSA[0] + rand * (PAUSA[1] - PAUSA[0]))
          else
            OstMini.se("Martillo pof", "Mining pick", 70, 90)
          end
          golpe.x = px
          golpe.y = py
          golpe.visible = true
          golpe_t = 0
        end
      elsif clic?
        golpeando = GOLPE_F
        OstMini.se("Martillo zas", nil, 60, 100)
      else
        martillo.src_rect = Rect.new(0, 0, mw, mb.height)
      end
      if golpe_t >= 0
        golpe.src_rect = Rect.new([golpe_t / 3, 3].min * gw, 0, gw, gb.height)
        golpe_t += 1
        if golpe_t > 12
          golpe.visible = false
          golpe_t = -1
        end
      end
    end

    # --- el final: Fennekin sale de un salto del ultimo arbusto -----------------
    OstMini.opacidad(cartel, 0)
    colas.each { |c| c.visible = false }
    base = ARBUSTOS[ultimo]
    sale = Sprite.new(vp)
    sale.bitmap = arte("fennekin_sale")
    sale.ox = sale.bitmap.width / 2
    sale.oy = sale.bitmap.height
    sale.x = base[0]
    sale.z = 400
    meneo[ultimo] = 30
    begin
      GameData::Species.play_cry_from_species(:FENNEKIN, 0, 90, 100)
    rescue
    end
    n = 50
    n.times do |k|
      OstMini.tick
      mx, my = raton
      martillo.x = mx
      martillo.y = my
      matas.each_with_index do |s, i|
        f = meneo[i] > 0 ? (k / 3) % 3 : (k / 16 + i) % 3
        meneo[i] -= 1 if meneo[i] > 0
        s.src_rect = Rect.new(f * aw, 0, aw, ah)
      end
      u = (k + 1).to_f / n
      # sube, se queda un instante arriba y cae delante, en el centro
      sale.x = (base[0] + (960 - base[0]) * u).to_i
      sale.y = (base[1] - 60 - 420 * Math.sin(u * Math::PI) + (1020 - base[1]) * u).to_i
      sale.zoom_x = base[2] + (1.3 - base[2]) * u
      sale.zoom_y = sale.zoom_x
    end
    OstMini.se("Martillo pi", "Mining hammer", 90, 150)
    40.times do |k|
      OstMini.tick
      sale.y = 1020 - (Math.sin(k * Math::PI / 20.0).abs * 36).to_i
    end
    OstMini.fundir(telon, 255, 10)

    begin
      Graphics.show_cursor = true
    rescue
    end
    [fondo, martillo, golpe, sale].each { |s| OstMini.soltar(s) }
    (matas + colas).each { |s| s.dispose if s && !s.disposed? }
    ab.dispose if !ab.disposed?
    cola_b.dispose if !cola_b.disposed?
    llamas.each { |l| OstMini.soltar(l) }
    cartel.each { |c| OstMini.soltar(c) }
    return true
  end

  def self.esconder(colas, i, matas, meneo)
    colas[i].visible = false
    meneo[i] = 12
  end

  # la cola se da por golpeada si la punta del martillo cae dentro de su dibujo
  # (con un poco de margen, que el martillo es grande)
  def self.dentro?(cola, px, py, cw, ch)
    return false if !cola.visible
    ancho = cw * cola.zoom_x * 0.5 + 30
    arriba = cola.y - ch * cola.zoom_y - 30
    return false if px < cola.x - ancho || px > cola.x + ancho
    return false if py < arriba || py > cola.y + 30
    return true
  end

  def self.dibujar_llama(b, encendida)
    b.clear
    fuera = encendida ? Color.new(240, 120, 40) : Color.new(90, 70, 60, 150)
    dentro = encendida ? Color.new(255, 220, 110) : Color.new(120, 100, 90, 150)
    [[18, 0, 4], [14, 6, 12], [10, 12, 20], [6, 18, 28], [4, 24, 32], [4, 30, 32], [6, 36, 28], [10, 42, 20]].each do |x, y, w|
      b.fill_rect(x, y, w, 6, fuera)
    end
    [[16, 24, 8], [12, 30, 16], [14, 36, 12]].each do |x, y, w|
      b.fill_rect(x, y, w, 6, dentro)
    end
  end
end
