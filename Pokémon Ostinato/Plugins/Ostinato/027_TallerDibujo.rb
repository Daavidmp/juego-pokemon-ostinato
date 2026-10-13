#===============================================================================
# Pokemon Ostinato - El taller de dibujo de Villa Bambalina
#
#   La pintora (evento "Pintora" del mapa 12, en la puerta de la casa de abajo
#   a la izquierda) saluda (TalTxt00-01) y abre el taller a 1920x1080:
#     - un menu con 8 lienzos (marcos con la miniatura de lo que haya pintado);
#     - al elegir uno, la vista del atril delante del taller: a la izquierda la
#       paleta (13 colores) y los tres grosores, a la derecha las herramientas
#       (lapiz, pincel, cubo, goma y borrar todo).
#   Se pinta con el raton (o con las flechas y Enter). Esc guarda y vuelve al
#   menu; Esc en el menu sale y la pintora se despide (TalTxt02).
#
#   El lienzo es de 264x176 pixeles grandes (x3 en pantalla), como el resto
#   del juego. Los cuadros se guardan como PNG en la carpeta de partidas
#   (Taller/lienzo1..8.png) y siguen ahi al volver.
#   Piezas: Graphics/Titles/Taller (de Descargas\taller_dibujo, por Claude).
#   Musica: Audio/BGM/Taller de dibujo.
#===============================================================================
module OstTaller
  DIR   = "Graphics/Titles/Taller/"
  BGM   = "Taller de dibujo"
  LW    = 264                       # el lienzo, en pixeles de pintura
  LH    = 176
  ZOOM  = 3
  LX    = 960 - LW * ZOOM / 2       # el lienzo en pantalla
  LY    = 96
  # el atril: el blanco de su lienzo esta en (222,200) y mide 586 de ancho
  ATRIL_K = LW * ZOOM / 586.0
  # la paleta (a 1024) y sus 13 colores: x, y y el color
  PALETA_K = 0.42
  PALETA_XY = [10, 300]
  COLORES = [[295, 285, 255, 255, 255], [453, 255, 54, 52, 53], [612, 265, 146, 135, 135],
             [763, 325, 151, 89, 52], [305, 460, 220, 61, 57], [460, 462, 245, 136, 46],
             [623, 465, 249, 222, 56], [835, 475, 160, 199, 80], [460, 628, 36, 131, 70],
             [623, 626, 92, 180, 228], [783, 640, 84, 162, 71], [450, 790, 56, 88, 167],
             [615, 786, 127, 68, 160]]
  RADIO = 58
  HERRAMIENTAS = [:lapiz, :pincel, :cubo, :goma, :papelera]
  HERR_K = 0.42
  HERR_X = 1785
  HERR_Y0 = 150
  HERR_PASO = 158
  GROSORES = [1, 3, 6]               # radio en pixeles de pintura
  BLANCO = [252, 250, 246]
  # el raton de este mkxp va en 640x480 aunque la pantalla este a 1920x1080
  RATON_BASE = [640, 480]

  def self.carpeta
    base = "."
    begin
      base = System.data_directory
    rescue
    end
    d = File.join(base, "Taller")
    Dir.mkdir(d) rescue nil
    return d
  end
  def self.ruta(i); return File.join(carpeta, "lienzo#{i + 1}.png"); end

  def self.raton
    begin
      x = Input.mouse_x; y = Input.mouse_y
      return [x * 1920 / RATON_BASE[0], y * 1080 / RATON_BASE[1]] if x && y
    rescue
    end
    return nil
  end
  def self.clic?; begin; return Input.trigger?(Input::MOUSELEFT); rescue; return false; end; end
  def self.pulsado?; begin; return Input.press?(Input::MOUSELEFT); rescue; return false; end; end

  #--- lo que dice la pintora --------------------------------------------------
  def self.hablar
    OstinatoVecinos.hablar("TalTxt", 0, 1)
    abrir
    OstinatoVecinos.hablar("TalTxt", 2, 2)
  end

  def self.abrir
    begin; Graphics.show_cursor = false; rescue; end
    OstMini.pantalla(BGM) do |vp, telon|
      @vp = vp
      OstMini.fundir(telon, 0, 12)
      menu
      OstMini.fundir(telon, 255, 12)
    end
  ensure
    begin; Graphics.show_cursor = true; rescue; end
  end

  #-----------------------------------------------------------------------------
  # Piezas comunes
  #-----------------------------------------------------------------------------
  def self.sprite(bm, x = 0, y = 0, z = 10)
    s = Sprite.new(@vp); s.bitmap = bm; s.x = x; s.y = y; s.z = z
    return s
  end

  def self.texto(s, txt, tam = 36, color = Color.new(255, 248, 230))
    b = s.bitmap
    b.clear
    b.font.size = tam
    b.font.bold = true
    sombra = Color.new(30, 20, 10, 220)
    b.font.color = sombra
    b.draw_text(3, 3, b.width, b.height, txt, 1)
    b.font.color = color
    b.draw_text(0, 0, b.width, b.height, txt, 1)
  end

  def self.puntero
    if !@puntero || @puntero.disposed?
      @puntero = sprite(Bitmap.new(1, 1), 0, 0, 900)
    end
    return @puntero
  end

  # mkxp guarda en cache los Bitmap.new(ruta): lo pintado en esta partida se
  # recuerda en memoria para no leer la version vieja del disco
  def self.cargar(i)
    @memoria ||= {}
    return @memoria[i].clone if @memoria[i] && !@memoria[i].disposed?
    bm = Bitmap.new(LW, LH)
    bm.fill_rect(0, 0, LW, LH, Color.new(*BLANCO))
    if FileTest.exist?(ruta(i))
      begin
        g = Bitmap.new(ruta(i))
        bm.blt(0, 0, g, Rect.new(0, 0, LW, LH))
        g.dispose
      rescue
      end
    end
    return bm
  end

  #-----------------------------------------------------------------------------
  # El menu de los 8 lienzos: el pueblo a acuarela de fondo, la cinta con el
  # titulo y 8 marcos colgados de su lazo. El elegido crece y se balancea.
  #-----------------------------------------------------------------------------
  MARCO_K   = 0.34
  MARCO_IN  = [180, 269, 662, 449]         # el hueco del marco (a 1024), ya vacio
  MARCO_LAZO = [512, 165]                   # el lazo: de ahi cuelga y gira
  MARCO_ETIQ = [510, 772]                   # la etiqueta de papel de abajo

  def self.menu
    fondo = sprite(OstMini.bmp(DIR + "fondo_menu.png"), 0, 0, 0)
    velo = sprite(Bitmap.new(1920, 1080), 0, 0, 1)
    velo.bitmap.fill_rect(0, 0, 1920, 1080, Color.new(255, 246, 228, 70))
    cinta = sprite(OstMini.bmp(DIR + "cinta.png"), 960, 100, 20)
    cinta.ox = cinta.bitmap.width / 2; cinta.oy = cinta.bitmap.height / 2
    cinta.zoom_x = cinta.zoom_y = 0.62
    titulo = sprite(Bitmap.new(1920, 90), 0, 57, 21)
    texto(titulo, "Mis cuadros", 54, Color.new(255, 252, 244))
    ayuda = sprite(Bitmap.new(1920, 50), 0, 1015, 20)
    texto(ayuda, "Enter o clic: pintar      Esc: salir", 30, Color.new(90, 50, 25))
    marco = OstMini.bmp(DIR + "ranura.png")
    mw = (1024 * MARCO_K).round
    huecos = []
    8.times do |i|
      col = i % 4; fila = i / 4
      cx = 960 + (col - 1.5) * (mw + 40)
      ly = 205 + fila * (mw + 30) + (MARCO_LAZO[1] * MARCO_K).round   # donde esta el lazo
      # la miniatura va debajo del marco y se asoma por el hueco
      mini = cargar(i)
      iw = MARCO_IN[2] * MARCO_K; ih = MARCO_IN[3] * MARCO_K
      k = [iw / LW, ih / LH].max
      t = sprite(mini, 0, 0, 10); t.zoom_x = t.zoom_y = k
      t.ox = LW / 2; t.oy = LH / 2
      m = sprite(marco, cx, ly, 11); m.ox = MARCO_LAZO[0]; m.oy = MARCO_LAZO[1]
      m.zoom_x = m.zoom_y = MARCO_K
      n = sprite(Bitmap.new(80, 40), 0, 0, 12); n.ox = 40; n.oy = 20
      texto(n, "#{i + 1}", 26, Color.new(110, 70, 30))
      huecos.push({ :m => m, :t => t, :n => n, :x => cx, :y => ly, :k => k, :z => 1.0, :a => 0.0 })
    end
    sel = 0
    ultimo_raton = nil
    tocado = lambda do |r|
      huecos.index do |h|
        w2 = mw / 2; arriba = h[:y]; abajo = h[:y] + (1024 * MARCO_K * 0.72)
        r[0] >= h[:x] - w2 && r[0] < h[:x] + w2 && r[1] >= arriba && r[1] < abajo
      end
    end
    loop do
      OstMini.tick
      r = raton
      if r && r != ultimo_raton
        ultimo_raton = r
        j = tocado.call(r)
        sel = j if j
      end
      viejo = sel
      sel = (sel + 1) % 8 if Input.trigger?(Input::RIGHT)
      sel = (sel + 7) % 8 if Input.trigger?(Input::LEFT)
      sel = (sel + 4) % 8 if Input.trigger?(Input::DOWN) || Input.trigger?(Input::UP)
      pbSEPlay("GUI sel cursor") rescue nil if sel != viejo
      reloj = System.uptime
      huecos.each_with_index do |h, i|
        el = i == sel
        h[:z] += ((el ? 1.12 : 1.0) - h[:z]) * 0.2
        ang = el ? 3.0 * Math.sin(reloj * 2.6) : 0.6 * Math.sin(reloj * 1.3 + i)
        h[:a] += (ang - h[:a]) * 0.25
        z = MARCO_K * h[:z]; rad = h[:a] * Math::PI / 180
        m = h[:m]; m.zoom_x = m.zoom_y = z; m.angle = h[:a]; m.z = el ? 31 : 11
        m.tone.set(el ? 20 : -10, el ? 16 : -10, el ? 0 : -10, 0)
        # lo que cuelga del lazo gira con el: hueco y etiqueta
        [[h[:t], (MARCO_IN[0] + MARCO_IN[2] / 2.0), (MARCO_IN[1] + MARCO_IN[3] / 2.0)],
         [h[:n], MARCO_ETIQ[0], MARCO_ETIQ[1]]].each do |s, px, py|
          dx = (px - MARCO_LAZO[0]) * z; dy = (py - MARCO_LAZO[1]) * z
          s.x = h[:x] + dx * Math.cos(rad) + dy * Math.sin(rad)
          s.y = h[:y] - dx * Math.sin(rad) + dy * Math.cos(rad)
          s.angle = h[:a]
        end
        h[:t].zoom_x = h[:t].zoom_y = h[:k] * h[:z]; h[:t].z = el ? 30 : 10
        h[:n].zoom_x = h[:n].zoom_y = h[:z]; h[:n].z = el ? 32 : 12
      end
      if r
        p = puntero
        p.bitmap = OstMini.bmp(DIR + "h_pincel.png") if p.bitmap.width < 2
        p.zoom_x = p.zoom_y = 0.22; p.ox = 60; p.oy = 280; p.x = r[0]; p.y = r[1]
      end
      if Input.trigger?(Input::BACK)
        pbSEPlay("GUI menu close") rescue nil
        break
      end
      encima = r && tocado.call(r)
      if Input.trigger?(Input::USE) || (clic? && encima)
        pbSEPlay("GUI sel decision") rescue nil
        todo = [fondo, velo, cinta, titulo, ayuda] + huecos.map { |h| [h[:m], h[:t], h[:n]] }.flatten
        todo.each { |s| s.visible = false }
        pintar(sel)
        nueva = cargar(sel)
        huecos[sel][:t].bitmap.dispose rescue nil
        huecos[sel][:t].bitmap = nueva
        todo.each { |s| s.visible = true }
        12.times { Input.update; OstMini.tick }
      end
    end
  ensure
    (huecos || []).each { |h| OstMini.soltar(h[:t]); OstMini.soltar(h[:n]); begin; h[:m].dispose; rescue; end }
    [fondo, velo, cinta, titulo, ayuda].each { |s| OstMini.soltar(s) if s }
    marco.dispose if marco && !marco.disposed?
    OstMini.soltar(@puntero) if @puntero
    @puntero = nil
  end


  #-----------------------------------------------------------------------------
  # La vista del atril
  #-----------------------------------------------------------------------------
  def self.pintar(i)
    sp = []
    fondo = sprite(OstMini.bmp(DIR + "fondo.png"), 0, 0, 0); sp << fondo
    fondo.tone.set(-25, -25, -20, 40)
    atril = sprite(OstMini.bmp(DIR + "atril.png"), 0, 0, 5); sp << atril
    atril.zoom_x = atril.zoom_y = ATRIL_K
    atril.x = (LX - 222 * ATRIL_K).round; atril.y = (LY - 200 * ATRIL_K).round
    @lienzo = cargar(i)
    lz = sprite(@lienzo, LX, LY, 6); sp << lz
    lz.zoom_x = lz.zoom_y = ZOOM
    paleta = sprite(OstMini.bmp(DIR + "paleta.png"), PALETA_XY[0], PALETA_XY[1], 10); sp << paleta
    paleta.zoom_x = paleta.zoom_y = PALETA_K
    # el color elegido: un aro alrededor de su mancha
    aro = Bitmap.new(80, 80)
    80.times { |x| 80.times { |y| d = Math.sqrt((x - 39.5) ** 2 + (y - 39.5) ** 2); aro.set_pixel(x, y, Color.new(255, 236, 120)) if d > 31 && d < 38 } }
    s_aro = sprite(aro, 0, 0, 11); s_aro.ox = 40; s_aro.oy = 40; sp << s_aro
    # los grosores, debajo de la paleta
    gros = []
    GROSORES.each_with_index do |g, k|
      b = Bitmap.new(70, 70)
      rr = 8 + g * 3
      70.times { |x| 70.times { |y| d = Math.sqrt((x - 34.5) ** 2 + (y - 34.5) ** 2); b.set_pixel(x, y, d < rr ? Color.new(60, 45, 35) : (d < 31 ? Color.new(250, 242, 222) : (d < 34 ? Color.new(40, 28, 18) : Color.new(0, 0, 0, 0)))) } }
      s = sprite(b, 70 + k * 100, PALETA_XY[1] + 440, 10); sp << s
      gros << s
    end
    herr = HERRAMIENTAS.each_with_index.map do |h, k|
      s = sprite(OstMini.bmp(DIR + "h_#{h}.png"), HERR_X, HERR_Y0 + k * HERR_PASO, 10); sp << s
      s.ox = 170; s.oy = 170; s.zoom_x = s.zoom_y = HERR_K
      s
    end
    ayuda = sprite(Bitmap.new(1920, 50), 0, 1020, 20); sp << ayuda
    texto(ayuda, "Esc: guardar y volver", 30, Color.new(255, 248, 230))
    @color = 1; @herr = :pincel; @gros = 1
    cursor = [LX + LW * ZOOM / 2, LY + LH * ZOOM / 2]
    ultimo = nil; antes = nil
    p = puntero
    loop do
      OstMini.tick
      r = raton
      if r && r != @raton_antes
        cursor = r
      end
      @raton_antes = r
      # teclado: las flechas mueven el puntero
      paso = Input.press?(Input::ACTION) ? 14 : 6
      cursor[0] -= paso if Input.press?(Input::LEFT)
      cursor[0] += paso if Input.press?(Input::RIGHT)
      cursor[1] -= paso if Input.press?(Input::UP)
      cursor[1] += paso if Input.press?(Input::DOWN)
      cursor[0] = [[cursor[0], 0].max, 1919].min; cursor[1] = [[cursor[1], 0].max, 1079].min
      break if Input.trigger?(Input::BACK)
      boton = clic? || Input.trigger?(Input::USE)
      apretado = pulsado? || Input.press?(Input::USE)
      cx, cy = cursor
      dentro = cx >= LX && cx < LX + LW * ZOOM && cy >= LY && cy < LY + LH * ZOOM
      px = ((cx - LX) / ZOOM).floor; py = ((cy - LY) / ZOOM).floor
      if boton && !dentro
        # paleta
        COLORES.each_with_index do |c, k|
          sx = PALETA_XY[0] + c[0] * PALETA_K; sy = PALETA_XY[1] + c[1] * PALETA_K
          if (cx - sx) ** 2 + (cy - sy) ** 2 <= (RADIO * PALETA_K + 6) ** 2
            @color = k; pbSEPlay("GUI sel cursor") rescue nil
            @herr = :pincel if @herr == :goma || @herr == :papelera
          end
        end
        gros.each_with_index { |s, k| if cx >= s.x && cx < s.x + 70 && cy >= s.y && cy < s.y + 70; @gros = k; pbSEPlay("GUI sel cursor") rescue nil; end }
        herr.each_with_index do |s, k|
          next if (cx - s.x) ** 2 + (cy - s.y) ** 2 > (170 * HERR_K) ** 2
          if HERRAMIENTAS[k] == :papelera
            @lienzo.fill_rect(0, 0, LW, LH, Color.new(*BLANCO))
            pbSEPlay("GUI party switch") rescue nil
            s.zoom_x = s.zoom_y = HERR_K * 1.3
          else
            @herr = HERRAMIENTAS[k]; pbSEPlay("GUI sel decision") rescue nil
          end
        end
      end
      if dentro
        c = COLORES[@color]
        col = @herr == :goma ? Color.new(*BLANCO) : Color.new(c[2], c[3], c[4])
        if @herr == :cubo
          rellenar(px, py, col) if boton
        elsif apretado
          rad = @herr == :lapiz ? 0 : (@herr == :goma ? GROSORES[@gros] + 2 : GROSORES[@gros])
          if antes
            linea(antes[0], antes[1], px, py, rad, col)
          else
            punto(px, py, rad, col)
          end
          antes = [px, py]
        else
          antes = nil
        end
      else
        antes = nil
      end
      # lo que se ve elegido
      c = COLORES[@color]
      s_aro.x = PALETA_XY[0] + c[0] * PALETA_K; s_aro.y = PALETA_XY[1] + c[1] * PALETA_K
      s_aro.zoom_x = s_aro.zoom_y = 1.0 + 0.06 * Math.sin(Graphics.frame_count / 7.0)
      gros.each_with_index { |s, k| s.tone.set(k == @gros ? 0 : -60, k == @gros ? 0 : -60, k == @gros ? 0 : -60, 0); s.opacity = k == @gros ? 255 : 170 }
      herr.each_with_index do |s, k|
        el = HERRAMIENTAS[k] == @herr
        objetivo = HERR_K * (el ? 1.18 : 1.0)
        s.zoom_x += (objetivo - s.zoom_x) * 0.3; s.zoom_y = s.zoom_x
        s.tone.set(el ? 30 : -30, el ? 30 : -30, el ? 0 : -30, 0)
      end
      # el puntero: la herramienta, con la punta en el sitio
      bm = OstMini.bmp(DIR + "h_#{dentro ? @herr : :pincel}.png")
      if p.bitmap != bm
        p.bitmap = bm
      end
      p.zoom_x = p.zoom_y = 0.26
      p.ox = 70; p.oy = 270
      p.x = cx; p.y = cy
    end
    @lienzo.to_file(ruta(i)) rescue nil
    @memoria ||= {}
    @memoria[i].dispose if @memoria[i] && !@memoria[i].disposed?
    @memoria[i] = @lienzo.clone
    pbSEPlay("GUI save choice") rescue nil
  ensure
    sp.each { |s| OstMini.soltar(s) }
    @lienzo = nil
  end

  #--- pintar ------------------------------------------------------------------
  def self.punto(x, y, r, col)
    if r <= 0
      @lienzo.set_pixel(x, y, col) if x >= 0 && y >= 0 && x < LW && y < LH
      return
    end
    (-r..r).each do |dy|
      w = Math.sqrt(r * r - dy * dy).floor
      @lienzo.fill_rect(x - w, y + dy, w * 2 + 1, 1, col)
    end
  end

  def self.linea(x0, y0, x1, y1, r, col)
    n = [(x1 - x0).abs, (y1 - y0).abs, 1].max
    (0..n).each { |k| punto((x0 + (x1 - x0) * k / n.to_f).round, (y0 + (y1 - y0) * k / n.to_f).round, r, col) }
  end

  # relleno por lineas desde (x, y): todo lo del mismo color que toque
  def self.rellenar(x, y, col)
    return if x < 0 || y < 0 || x >= LW || y >= LH
    viejo = @lienzo.get_pixel(x, y)
    v = [viejo.red, viejo.green, viejo.blue]
    return if v == [col.red, col.green, col.blue]
    igual = lambda { |px, py| c = @lienzo.get_pixel(px, py); c.red == v[0] && c.green == v[1] && c.blue == v[2] }
    pila = [[x, y]]
    while (p = pila.pop)
      px, py = p
      next if !igual.call(px, py)
      x0 = px; x0 -= 1 while x0 > 0 && igual.call(x0 - 1, py)
      x1 = px; x1 += 1 while x1 < LW - 1 && igual.call(x1 + 1, py)
      @lienzo.fill_rect(x0, py, x1 - x0 + 1, 1, col)
      [py - 1, py + 1].each do |ny|
        next if ny < 0 || ny >= LH
        dentro = false
        (x0..x1).each do |nx|
          if igual.call(nx, ny)
            pila.push([nx, ny]) if !dentro
            dentro = true
          else
            dentro = false
          end
        end
      end
    end
    pbSEPlay("Water berry plant", 60) rescue nil
  end
end
