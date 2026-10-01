#===============================================================================
# Pokemon Ostinato - "LIRA TE DESAFIA": la entrada al primer combate contra Lira
#
#   1. La pantalla se raja: sobre la foto del mapa salen las grietas, con un
#      fogonazo y un temblor.
#   2. Estalla en cristales: la foto se parte en trozos que siguen las grietas
#      (radios desde el centro y anillos) y saltan hacia la camara girando.
#   3. Detras hay una lamina negra sobre el fondo rojo, que se deshace en
#      particulas que caen: lo destapa de dentro afuera, sin destaparlo entero.
#   4. Lira entra deprisa por la derecha sobre la explosion de tinta.
#   5. Cae el letrero "LIRA TE DESAFIA" a la derecha, con un golpe.
#   Va a 1920x1080 (OstinatoHD) y acaba en negro, que es como tiene que acabar
#   una animacion de entrada a combate. Usa OstMini (curvas y temblor).
#
#   Arte en Graphics/Titles/Desafio/ (fondo, grietas, tinta, lira, lineas) y
#   Graphics/Titles/DesafioTexto.png.
#===============================================================================
module OstDesafio
  DIR = "Graphics/Titles/Desafio/"
  W = 1920
  H = 1080
  TESELA  = 40            # lado de cada trozo de la lamina negra
  CENTRO  = [820, 500]    # de donde empieza a deshacerse
  LIMITE  = 0.80          # hasta donde se deshace (1 = casi entera)
  CAIDA   = 48            # fotogramas en los que van soltandose
  LIRA_X  = 1450          # Lira, a la derecha (centro de sus pies)
  TEXTO_X = 1270          # el letrero, abajo a la derecha
  TEXTO_Y = 955
  TEXTO_Z = 0.72

  def self.se(nombre, volumen = 90, tono = 100)
    begin
      pbSEPlay(nombre, volumen, tono)
    rescue
    end
  end

  #-----------------------------------------------------------------------------
  # Los cristales. La foto (a la resolucion del mapa) se parte en trozos que
  # salen del punto del golpe: radios a angulos irregulares y anillos. Cada
  # trozo es su propio bitmap con la forma del poligono, copiado fila a fila
  # (un blt por fila y trozo: unos pocos miles en total, es instantaneo).
  #-----------------------------------------------------------------------------
  def self.cristales(foto)
    fw = foto.width
    fh = foto.height
    cx = fw / 2.0
    cy = fh / 2.0
    azar = Random.new(7)
    angulos = []
    n = 11
    n.times { |i| angulos.push((i + 0.15 + azar.rand * 0.7) * 2 * Math::PI / n) }
    radios = [0, fh * 0.16, fh * 0.38, fh * 0.70, fw * 1.2]
    trozos = []
    (radios.length - 1).times do |j|
      n.times do |k|
        a0 = angulos[k]
        a1 = angulos[(k + 1) % n] + (k == n - 1 ? 2 * Math::PI : 0)
        r0 = radios[j]
        r1 = radios[j + 1]
        pts = []
        pts.push([cx + Math.cos(a0) * r0, cy + Math.sin(a0) * r0])
        pts.push([cx + Math.cos(a0) * r1, cy + Math.sin(a0) * r1])
        pts.push([cx + Math.cos(a1) * r1, cy + Math.sin(a1) * r1])
        pts.push([cx + Math.cos(a1) * r0, cy + Math.sin(a1) * r0]) if r0 > 0
        ys = pts.map { |p| p[1] }
        y0 = [ys.min.floor, 0].max
        y1 = [ys.max.ceil, fh - 1].min
        next if y1 < y0
        filas = []
        (y0..y1).each do |y|
          yy = y + 0.5
          xs = []
          pts.each_index do |m|
            p = pts[m]
            q = pts[(m + 1) % pts.length]
            next if p[1] == q[1]
            lo, hi = [p[1], q[1]].minmax
            next if yy < lo || yy >= hi
            xs.push(p[0] + (yy - p[1]) * (q[0] - p[0]) / (q[1] - p[1]))
          end
          next if xs.length < 2
          xa = [xs.min.round, 0].max
          xb = [xs.max.round, fw].min
          filas.push([y, xa, xb]) if xb > xa
        end
        next if filas.empty?
        bx0 = filas.map { |f| f[1] }.min
        bx1 = filas.map { |f| f[2] }.max
        b = Bitmap.new(bx1 - bx0, y1 - y0 + 1)
        filas.each { |y, xa, xb| b.blt(xa - bx0, y - y0, foto, Rect.new(xa, y, xb - xa, 1)) }
        mx = pts.map { |p| p[0] }.sum / pts.length
        my = pts.map { |p| p[1] }.sum / pts.length
        trozos.push([b, bx0, y0, mx, my])
      end
    end
    return trozos
  end

  #-----------------------------------------------------------------------------
  # La lamina negra: una rejilla de teselas. A cada una se le da el momento en
  # que se suelta segun lo lejos que esta de CENTRO (con algo de ruido, para que
  # el contorno sea irregular); las que pasan de LIMITE no caen nunca.
  #-----------------------------------------------------------------------------
  def self.lamina(vp, bitmap)
    azar = Random.new(11)
    lista = []
    (H / TESELA).times do |j|
      (W / TESELA).times do |i|
        cx = i * TESELA + TESELA / 2
        cy = j * TESELA + TESELA / 2
        s = Sprite.new(vp)
        s.bitmap = bitmap
        s.z = 2
        s.ox = s.oy = TESELA / 2
        s.x = cx
        s.y = cy
        dx = (cx - CENTRO[0]) / 1150.0
        dy = (cy - CENTRO[1]) / 640.0
        v = Math.sqrt(dx * dx + dy * dy) + azar.rand * 0.22 + 0.06 * Math.sin(cx * 0.013 + cy * 0.021)
        cae = (v < LIMITE) ? (v / LIMITE * CAIDA).round + azar.rand(4) : nil
        lista.push([s, cx.to_f, cy.to_f, (azar.rand - 0.5) * 3, -azar.rand * 3, (azar.rand - 0.5) * 16, cae])
      end
    end
    return lista
  end

  # f: fotogramas desde que empezo a deshacerse
  def self.desmoronar(teselas, f)
    teselas.each do |q|
      s, x, y, vx, vy, giro, cae = q
      next if !cae || f < cae || !s.visible
      g = f - cae
      q[4] = vy + 0.9                     # cae
      q[1] = x + vx
      q[2] = y + q[4]
      s.x = q[1].round
      s.y = q[2].round
      s.angle += giro
      z = [1.0 - g * 0.025, 0.3].max      # y se hace pequena, como polvo
      s.zoom_x = s.zoom_y = z
      s.opacity = (g > 14) ? [255 - (g - 14) * 18, 0].max : 255
      s.visible = false if s.opacity <= 0 || s.y > H + 60
    end
  end

  #-----------------------------------------------------------------------------
  def self.animar(viewport)
    foto = nil
    begin
      foto = Graphics.snap_to_bitmap
    rescue
    end
    piezas = foto ? cristales(foto) : []
    antes = OstinatoHD.subir
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 999_999
    sprites = []
    compartidos = []          # bitmaps que usan varios sprites: se sueltan aparte
    nuevo = proc do |bitmap, z|
      s = Sprite.new(vp)
      s.bitmap = bitmap
      s.z = z
      sprites.push(s)
      s
    end
    lleno = proc do |color, z|
      b = Bitmap.new(W, H)
      b.fill_rect(0, 0, W, H, color)
      nuevo.call(b, z)
    end
    begin
      OstMini.temblar(0)
      negro = lleno.call(Color.new(0, 0, 0), 0)

      # el fondo rojo, tapado por una lamina negra hecha de teselas que luego
      # se desprenden y caen como particulas
      fondo = nuevo.call(OstMini.bmp(DIR + "fondo.png"), 1)
      fondo.ox = fondo.bitmap.width / 2
      fondo.oy = fondo.bitmap.height / 2
      fondo.x = W / 2
      fondo.y = H / 2
      tesela_b = Bitmap.new(TESELA, TESELA)
      tesela_b.fill_rect(0, 0, TESELA, TESELA, Color.new(0, 0, 0))
      compartidos.push(tesela_b)
      teselas = lamina(vp, tesela_b)

      lineas = nuevo.call(OstMini.bmp(DIR + "lineas.png"), 4)
      lineas.opacity = 0
      tinta = nuevo.call(OstMini.bmp(DIR + "tinta.png"), 5)
      tinta.ox = tinta.bitmap.width / 2
      tinta.oy = tinta.bitmap.height / 2
      tinta.x = LIRA_X
      tinta.y = 520
      tinta.opacity = 0
      lira = nuevo.call(OstMini.bmp(DIR + "lira.png"), 6)
      lira.ox = lira.bitmap.width / 2
      lira.oy = lira.bitmap.height
      lira.y = H + 10
      lira.x = W + lira.bitmap.width
      lira.opacity = 0
      letrero = nuevo.call(OstMini.bmp("Graphics/Titles/DesafioTexto.png"), 7)
      letrero.ox = letrero.bitmap.width / 2
      letrero.oy = letrero.bitmap.height / 2
      letrero.x = TEXTO_X
      letrero.y = TEXTO_Y
      letrero.opacity = 0

      # la foto del mapa, ya en cristales (pegados, todavia no se ve el corte)
      e = foto ? W.to_f / foto.width : 1.0
      cristal = piezas.map do |b, bx, by, cx, cy|
        s = nuevo.call(b, 10)
        s.ox = (cx - bx).round
        s.oy = (cy - by).round
        s.zoom_x = s.zoom_y = e
        s.x = (cx * e).round
        s.y = (cy * e).round
        dx = cx * e - W / 2
        dy = cy * e - H / 2
        d = Math.sqrt(dx * dx + dy * dy) + 1
        v = 6 + d / 55.0 + rand * 6
        [s, s.x.to_f, s.y.to_f, dx / d * v, dy / d * v - 4, (rand - 0.5) * 9]
      end
      grietas = nuevo.call(OstMini.bmp(DIR + "grietas.png"), 11)
      grietas.blend_type = 1
      grietas.ox = W / 2
      grietas.oy = H / 2
      grietas.x = W / 2
      grietas.y = H / 2
      grietas.opacity = 0
      blanco = lleno.call(Color.new(255, 255, 255), 12)
      blanco.opacity = 0

      t = 0
      desde = nil             # cuando empieza a deshacerse la lamina
      paso = proc do
        t += 1
        desmoronar(teselas, t - desde) if desde
        OstMini.temblor(vp)
        Graphics.update
        Input.update
      end

      # --- 1. el golpe: se raja ----------------------------------------------
      se("Anim/Ice2", 100, 90)
      blanco.opacity = 170
      grietas.zoom_x = grietas.zoom_y = 0.6
      OstMini.temblar(12)
      8.times do |f|
        u = OstMini.sale((f + 1) / 8.0)
        grietas.opacity = (255 * u).to_i
        grietas.zoom_x = grietas.zoom_y = 0.6 + 0.4 * u
        blanco.opacity = [blanco.opacity - 25, 0].max
        paso.call
      end
      # un segundo crujido, y la foto se hunde un pelo hacia dentro
      18.times do |f|
        se("Anim/Ice5", 80, 110) if f == 8
        OstMini.temblar(6) if f == 8
        z = 1.0 - 0.015 * OstMini.sale((f + 1) / 18.0)
        cristal.each do |q|
          q[0].zoom_x = q[0].zoom_y = e * z
          q[0].x = (W / 2 + (q[1] - W / 2) * z).round
          q[0].y = (H / 2 + (q[2] - H / 2) * z).round
        end
        paso.call
      end

      # --- 2. estalla ---------------------------------------------------------
      se("Anim/Ice8", 100, 100)
      se("Rock Smash", 80, 80)
      blanco.opacity = 200
      OstMini.temblar(20)
      34.times do |f|
        u = (f + 1) / 34.0
        grietas.opacity = [(255 * (1 - u * 3)).to_i, 0].max
        blanco.opacity = [blanco.opacity - 30, 0].max
        cristal.each do |q|
          s, x, y, vx, vy, giro = q
          q[1] = x + vx
          q[2] = y + vy
          q[3] = vx * 1.04
          q[4] = vy * 1.04 + 1.1            # salen hacia fuera y caen
          s.x = q[1].round
          s.y = q[2].round
          s.angle += giro
          s.zoom_x = s.zoom_y = e * (1.0 + 0.9 * OstMini.entra(u))
          s.opacity = (255 * (1 - OstMini.entra(u))).to_i
        end
        # a la vez empieza a revelarse el fondo, de izquierda a derecha
        paso.call
        break if f == 12
      end
      # --- 3. la lamina negra se deshace en particulas -------------------------
      # Caen las teselas de dentro hacia fuera, con un contorno irregular; las
      # de los bordes se quedan: el fondo rojo no se destapa entero.
      se("Anim/PRSFX- Air Slash1", 80, 100)
      desde = t
      (CAIDA + 12).times do
        # los cristales que quedan siguen cayendo
        cristal.each do |q|
          s = q[0]
          next if !s.visible
          q[1] += q[3]
          q[2] += q[4]
          q[4] += 1.1
          s.x = q[1].round
          s.y = q[2].round
          s.angle += q[5]
          s.opacity = [s.opacity - 22, 0].max
          s.visible = false if s.opacity <= 0
        end
        paso.call
      end
      cristal.each { |q| q[0].visible = false }
      grietas.visible = false

      # --- 4. Lira entra por la derecha sobre la tinta ---------------------------
      se("Vs flash", 90, 100)
      lineas.opacity = 170
      20.times do |f|
        u = (f + 1).to_f
        tz = 0.15 + 0.9 * OstMini.rebote([u / 14.0, 1.0].min)
        tinta.zoom_x = tinta.zoom_y = tz
        tinta.opacity = 255
        tinta.angle = -8 + 8 * [u / 20.0, 1.0].min
        k = OstMini.sale([u / 14.0, 1.0].min)
        lira.opacity = 255
        lira.x = (W + 400 - (W + 400 - LIRA_X) * k).round
        lira.zoom_x = 1.0 + 0.15 * (1 - k)          # estirada por la velocidad
        lira.zoom_y = 1.0 - 0.04 * (1 - k)
        lineas.x = -((t * 80) % W)
        fondo.zoom_x = fondo.zoom_y = 1.0 + 0.002 * f
        paso.call
      end
      blanco.opacity = 120
      OstMini.temblar(8)

      # --- 5. el letrero, de golpe ----------------------------------------------
      90.times do |f|
        if f < 7
          u = OstMini.entra((f + 1) / 7.0)
          letrero.opacity = (255 * u).to_i
          letrero.zoom_x = letrero.zoom_y = TEXTO_Z * (2.4 - 1.4 * u)
        elsif f == 7
          se("Vs sword", 100, 100)
          se("Anim/Explosion2", 60, 120)
          OstMini.temblar(18)
          blanco.opacity = 140
          letrero.zoom_x = letrero.zoom_y = TEXTO_Z
        end
        blanco.opacity = [blanco.opacity - 18, 0].max
        letrero.tone = (f > 20 && (f / 8) % 2 == 1) ? Tone.new(60, 40, 40) : Tone.new(0, 0, 0)
        lira.zoom_x = lira.zoom_y = 1.0 + 0.012 * Math.sin(f * 0.12)
        lineas.x = -((t * 40) % W)
        lineas.opacity = [lineas.opacity - 2, 60].max
        fondo.zoom_x = fondo.zoom_y = 1.04 + 0.0006 * f
        paso.call
      end

      # y todo a negro
      negro.z = 20
      negro.opacity = 0
      16.times { |f| negro.opacity = [(f + 1) * 16, 255].min; paso.call }
      viewport.color = Color.new(0, 0, 0, 255) if viewport
    ensure
      vp.ox = 0
      vp.oy = 0
      (teselas || []).each { |q| q[0].dispose if !q[0].disposed? }
      compartidos.each { |b| b.dispose if b && !b.disposed? }
      sprites.each do |s|
        next if s.disposed?
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
        s.dispose
      end
      foto.dispose if foto && !foto.disposed?
      begin; vp.dispose; rescue; end
      OstinatoHD.bajar(antes) if antes
      viewport.color = Color.new(0, 0, 0, 255) if viewport
    end
  end
end

SpecialBattleIntroAnimations.register("ostinato_lira_desafia", 100,
  proc { |battle_type, foe, location|
    next false if battle_type.even? || !foe || foe.length != 1
    next foe[0].trainer_type == :LIRA
  },
  proc { |viewport, battle_type, foe, location|
    OstDesafio.animar(viewport)
  }
)
