#===============================================================================
# Pokemon Ostinato - "X TE DESAFIA": la entrada a los combates importantes
#
#   1. La pantalla del mapa se raja poco a poco (unos 2 s): una grieta en un
#      sitio, otra en otro, la pantalla entera... y estalla en cristales que
#      caen.
#   2. Negro. De golpe, el personaje (a la izquierda, senalando).
#   3. A la derecha cae el "bollo" (una mancha aplastada, como pisada por una
#      apisonadora) con "LIRA TE DESAFIA" encima.
#   4. Mientras, la pantalla negra se rompe un poquito: se le sueltan unas
#      piececitas que caen y por los huecos asoma el fondo.
#   Va a 1920x1080 (OstinatoHD) y acaba en negro, que es como tiene que acabar
#   una animacion de entrada a combate. Usa OstMini (curvas y temblor).
#
#   Arte en Graphics/Titles/Desafio/ (de Firefly; prompts en
#   recursos/prompts_desafio.txt): grietas_a/b/c, fondo, bollo, el personaje
#   (lira.png) y el letrero de cada rival, texto_TIPO.png (texto_LIRA.png).
#   Para otro rival basta con su dibujo y su letrero, y anadir su tipo a RIVALES.
#===============================================================================
module OstDesafio
  DIR = "Graphics/Titles/Desafio/"
  W = 1920
  H = 1080
  # tipo de entrenador => dibujo del personaje
  RIVALES = { :LIRA => "lira" }

  # las grietas: [imagen, donde cae el golpe en pantalla, donde esta el golpe
  # dentro de la imagen (a 1920x1080), zoom]
  GRIETA_A = ["grietas_a", [1430, 310], [955, 530], 0.70]
  GRIETA_B = ["grietas_b", [560, 720], [656, 530], 0.80]
  GOLPE_C  = [1172, 515]          # el golpe principal de grietas_c: de ahi salen los cristales

  PERSONAJE_X = 620                # el personaje, a la izquierda (centro de sus pies)
  BOLLO_X = 1385                   # el letrero, a la derecha
  BOLLO_Y = 520
  BOLLO_Z = 0.80
  TEXTO_Z = 0.95

  # la lamina negra se rompe solo por aqui: [centro, radio, en que fotograma empieza]
  ROTURAS = [[[250, 160], 190, 10], [[1760, 950], 200, 40], [[1050, 70], 150, 75],
             [[1840, 120], 130, 105]]
  CELDA = [96, 90]                 # tamano de las piececitas (rejilla de triangulos)

  def self.se(nombre, volumen = 90, tono = 100)
    begin
      pbSEPlay(nombre, volumen, tono)
    rescue
    end
  end

  def self.bmp(nombre)
    return OstMini.bmp(DIR + nombre + ".png")
  end

  # Filas de un poligono convexo: [[y, x0, x1], ...] recortadas a w x h
  def self.filas(pts, w, h)
    ys = pts.map { |p| p[1] }
    y0 = [ys.min.floor, 0].max
    y1 = [ys.max.ceil, h - 1].min
    ret = []
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
      xb = [xs.max.round, w].min
      ret.push([y, xa, xb]) if xb > xa
    end
    return ret
  end

  # Los cristales: la foto (a la resolucion del mapa) partida en trozos que
  # salen del golpe (cx, cy): radios a angulos irregulares y anillos. Cada
  # trozo es su bitmap con la forma del poligono, copiado fila a fila.
  def self.cristales(foto, cx, cy)
    fw = foto.width
    fh = foto.height
    azar = Random.new(7)
    n = 12
    angulos = (0...n).map { |i| (i + 0.15 + azar.rand * 0.7) * 2 * Math::PI / n }
    radios = [0, fh * 0.14, fh * 0.34, fh * 0.62, fw * 1.3]
    trozos = []
    (radios.length - 1).times do |j|
      n.times do |k|
        a0 = angulos[k]
        a1 = angulos[(k + 1) % n] + (k == n - 1 ? 2 * Math::PI : 0)
        r0 = radios[j]
        r1 = radios[j + 1]
        pts = [[cx + Math.cos(a0) * r0, cy + Math.sin(a0) * r0],
               [cx + Math.cos(a0) * r1, cy + Math.sin(a0) * r1],
               [cx + Math.cos(a1) * r1, cy + Math.sin(a1) * r1]]
        pts.push([cx + Math.cos(a1) * r0, cy + Math.sin(a1) * r0]) if r0 > 0
        fs = filas(pts, fw, fh)
        next if fs.empty?
        bx0 = fs.map { |f| f[1] }.min
        bx1 = fs.map { |f| f[2] }.max
        by0 = fs.first[0]
        b = Bitmap.new(bx1 - bx0, fs.last[0] - by0 + 1)
        fs.each { |y, xa, xb| b.blt(xa - bx0, y - by0, foto, Rect.new(xa, y, xb - xa, 1)) }
        mx = pts.map { |p| p[0] }.sum / pts.length
        my = pts.map { |p| p[1] }.sum / pts.length
        trozos.push([b, bx0, by0, mx, my])
      end
    end
    return trozos
  end

  # Las piececitas de la lamina negra que se van a soltar: triangulos de una
  # rejilla movida al azar, solo cerca de los sitios de ROTURAS.
  def self.piececitas
    azar = Random.new(23)
    cw, ch = CELDA
    cols = W / cw + 1
    rows = H / ch + 1
    pt = []
    (rows + 1).times do |j|
      (cols + 1).times do |i|
        jx = (i == 0 || i == cols) ? 0 : (azar.rand - 0.5) * cw * 0.6
        jy = (j == 0 || j == rows) ? 0 : (azar.rand - 0.5) * ch * 0.6
        pt[j * (cols + 1) + i] = [i * cw + jx, j * ch + jy]
      end
    end
    lista = []
    rows.times do |j|
      cols.times do |i|
        a = pt[j * (cols + 1) + i]
        b = pt[j * (cols + 1) + i + 1]
        c = pt[(j + 1) * (cols + 1) + i]
        d = pt[(j + 1) * (cols + 1) + i + 1]
        [[a, b, d], [a, d, c]].each do |tri|
          mx = tri.map { |p| p[0] }.sum / 3
          my = tri.map { |p| p[1] }.sum / 3
          ROTURAS.each do |centro, radio, empieza|
            dd = Math.sqrt((mx - centro[0])**2 + (my - centro[1])**2) / radio
            next if dd > 1 || azar.rand > 0.85 * (1 - dd * 0.6)
            lista.push([tri, mx, my, empieza + (dd * 40 + azar.rand * 12).round])
            break
          end
        end
      end
    end
    return lista
  end

  #-----------------------------------------------------------------------------
  def self.animar(viewport, tipo = :LIRA)
    foto = nil
    begin
      foto = Graphics.snap_to_bitmap
    rescue
    end
    escala_foto = foto ? W.to_f / foto.width : 1.0
    piezas = foto ? cristales(foto, GOLPE_C[0] / escala_foto, GOLPE_C[1] / escala_foto) : []
    sueltas = piececitas
    antes = OstinatoHD.subir
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 999_999
    sprites = []
    nuevo = proc do |bitmap, z|
      s = Sprite.new(vp)
      s.bitmap = bitmap
      s.z = z
      sprites.push(s)
      s
    end
    centrado = proc do |nombre, z|
      s = nuevo.call(bmp(nombre), z)
      s.ox = s.bitmap.width / 2
      s.oy = s.bitmap.height / 2
      s
    end
    begin
      OstMini.temblar(0)
      # el fondo y, encima, la lamina negra (un bitmap al que se le hacen huecos)
      fondo = centrado.call("fondo", 1)
      fondo.x = W / 2
      fondo.y = H / 2
      lamina_b = Bitmap.new(W, H)
      lamina_b.fill_rect(0, 0, W, H, Color.new(0, 0, 0))
      lamina = nuevo.call(lamina_b, 2)

      # el personaje y el letrero, escondidos
      pj = nuevo.call(bmp(RIVALES[tipo] || "lira"), 6)
      pj.ox = pj.bitmap.width / 2
      pj.oy = pj.bitmap.height
      pj.x = PERSONAJE_X
      pj.y = H + 20
      pj.mirror = true                  # que senale hacia su letrero
      pj.visible = false
      bollo = centrado.call("bollo", 7)
      bollo.x = BOLLO_X
      bollo.y = BOLLO_Y
      bollo.visible = false
      texto = centrado.call("texto_#{tipo}", 8)
      texto.x = BOLLO_X
      texto.y = BOLLO_Y
      texto.visible = false

      # la foto del mapa, ya en cristales (pegados: todavia no se nota)
      cristal = piezas.map do |b, bx, by, cx, cy|
        s = nuevo.call(b, 10)
        s.ox = (cx - bx).round
        s.oy = (cy - by).round
        s.zoom_x = s.zoom_y = escala_foto
        s.x = (cx * escala_foto).round
        s.y = (cy * escala_foto).round
        dx = s.x - GOLPE_C[0]
        dy = s.y - GOLPE_C[1]
        d = Math.sqrt(dx * dx + dy * dy) + 1
        v = 5 + d / 70.0 + rand * 5
        [s, s.x.to_f, s.y.to_f, dx / d * v, dy / d * v - 3, (rand - 0.5) * 10]
      end
      grieta = proc do |datos|
        g = nuevo.call(bmp(datos[0]), 11)
        g.blend_type = 1                 # lo negro no se ve: solo las lineas
        g.ox = datos[2][0]
        g.oy = datos[2][1]
        g.x = datos[1][0]
        g.y = datos[1][1]
        g.opacity = 0
        g
      end
      grieta_a = grieta.call(GRIETA_A)
      grieta_b = grieta.call(GRIETA_B)
      grieta_c = grieta.call(["grietas_c", GOLPE_C, GOLPE_C, 1.0])
      blanco_b = Bitmap.new(W, H)
      blanco_b.fill_rect(0, 0, W, H, Color.new(255, 255, 255))
      blanco = nuevo.call(blanco_b, 12)
      blanco.opacity = 0

      cayendo = []            # piececitas sueltas: [sprite, vy, giro]
      t = 0
      t_pj = nil              # cuando aparece el personaje
      paso = proc do
        t += 1
        # la lamina negra se rompe un poquito: cada piececita a su hora
        if t_pj
          f = t - t_pj
          sueltas.each do |q|
            next if !q || q[3] != f
            tri = q[0]
            fs = filas(tri, W, H)
            next if fs.empty?
            bx0 = fs.map { |r| r[1] }.min
            bx1 = fs.map { |r| r[2] }.max
            by0 = fs.first[0]
            pb = Bitmap.new([bx1 - bx0, 1].max, fs.last[0] - by0 + 1)
            fs.each do |y, xa, xb|
              lamina_b.fill_rect(xa, y, xb - xa, 1, Color.new(0, 0, 0, 0))
              pb.fill_rect(xa - bx0, y - by0, xb - xa, 1, Color.new(0, 0, 0))
            end
            s = nuevo.call(pb, 3)
            s.ox = (q[1] - bx0).round
            s.oy = (q[2] - by0).round
            s.x = q[1].round
            s.y = q[2].round
            cayendo.push([s, -1.5 - rand * 2, (rand - 0.5) * 8, (rand - 0.5) * 2])
          end
        end
        cayendo.each do |c|
          s = c[0]
          next if !s.visible
          c[1] += 0.55
          s.y += c[1].round
          s.x += c[3].round
          s.angle += c[2]
          s.zoom_x = s.zoom_y = [s.zoom_x - 0.008, 0.5].max
          s.visible = false if s.y > H + 120
        end
        fondo.zoom_x = fondo.zoom_y = 1.0 + 0.0004 * (t_pj ? t - t_pj : 0)
        OstMini.temblor(vp)
        Graphics.update
        Input.update
      end

      # --- 1. se raja poco a poco ----------------------------------------------
      golpe = proc do |g, zoom, sonido, fuerza|
        se(sonido, 100, 100)
        OstMini.temblar(fuerza)
        blanco.opacity = 90
        6.times do |f|
          u = OstMini.sale((f + 1) / 6.0)
          g.opacity = (255 * u).to_i
          g.zoom_x = g.zoom_y = zoom * (0.55 + 0.45 * u)
          blanco.opacity = [blanco.opacity - 16, 0].max
          paso.call
        end
      end
      golpe.call(grieta_a, GRIETA_A[3], "Anim/Ice2", 8)
      30.times { paso.call }
      golpe.call(grieta_b, GRIETA_B[3], "Anim/Ice5", 11)
      26.times { paso.call }
      golpe.call(grieta_c, 1.0, "Anim/Ice8", 16)
      16.times { paso.call }

      # --- y estalla -------------------------------------------------------------
      se("Rock Smash", 90, 90)
      se("Anim/Explosion2", 55, 120)
      OstMini.temblar(18)
      blanco.opacity = 150
      30.times do |f|
        u = (f + 1) / 30.0
        [grieta_a, grieta_b, grieta_c].each { |g| g.opacity = [g.opacity - 40, 0].max }
        blanco.opacity = [blanco.opacity - 25, 0].max
        cristal.each do |q|
          s = q[0]
          q[1] += q[3]
          q[2] += q[4]
          q[4] += 1.2
          s.x = q[1].round
          s.y = q[2].round
          s.angle += q[5]
          s.zoom_x = s.zoom_y = escala_foto * (1.0 + 0.7 * OstMini.entra(u))
          s.opacity = (255 * (1 - OstMini.entra(u))).to_i
        end
        paso.call
      end
      cristal.each { |q| q[0].visible = false }
      8.times { paso.call }            # un instante de negro

      # --- 2. de golpe, el personaje -----------------------------------------------
      se("Vs flash", 100, 100)
      t_pj = t
      pj.visible = true
      blanco.opacity = 255
      OstMini.temblar(6)
      6.times do |f|
        u = OstMini.sale((f + 1) / 6.0)
        pj.zoom_x = pj.zoom_y = 1.10 - 0.10 * u
        blanco.opacity = [blanco.opacity - 45, 0].max
        paso.call
      end
      pj.zoom_x = pj.zoom_y = 1.0

      # --- 3. el bollo, aplastado ---------------------------------------------------
      se("Vs sword", 100, 100)
      se("Anim/PRSFX- Brick Break1", 80, 90)
      bollo.visible = texto.visible = true
      # cae alto y estrecho...
      5.times do |f|
        u = OstMini.entra((f + 1) / 5.0)
        bollo.zoom_x = BOLLO_Z * (0.35 + 0.80 * u)
        bollo.zoom_y = BOLLO_Z * (1.9 - 1.2 * u)
        bollo.y = (BOLLO_Y - 320 * (1 - u)).round
        texto.zoom_x = bollo.zoom_x / BOLLO_Z * TEXTO_Z
        texto.zoom_y = bollo.zoom_y / BOLLO_Z * TEXTO_Z
        texto.y = bollo.y
        paso.call
      end
      # ...y la apisonadora lo deja plano, con un golpe
      OstMini.temblar(20)
      blanco.opacity = 110
      12.times do |f|
        u = OstMini.rebote((f + 1) / 12.0)
        sx = 1.15 - 0.15 * u
        sy = 0.70 + 0.30 * u
        bollo.zoom_x = BOLLO_Z * sx
        bollo.zoom_y = BOLLO_Z * sy
        texto.zoom_x = TEXTO_Z * sx
        texto.zoom_y = TEXTO_Z * sy
        blanco.opacity = [blanco.opacity - 14, 0].max
        paso.call
      end

      # --- 4. se queda, y el negro se va desconchando ---------------------------------
      150.times do |f|
        texto.tone = ((f / 10) % 2 == 1 && f > 30) ? Tone.new(40, 20, 30) : Tone.new(0, 0, 0)
        pj.zoom_x = pj.zoom_y = 1.0 + 0.008 * Math.sin(f * 0.1)
        paso.call
      end

      # y todo a negro
      negro_b = Bitmap.new(W, H)
      negro_b.fill_rect(0, 0, W, H, Color.new(0, 0, 0))
      negro = nuevo.call(negro_b, 20)
      negro.opacity = 0
      16.times { |f| negro.opacity = [(f + 1) * 16, 255].min; paso.call }
      viewport.color = Color.new(0, 0, 0, 255) if viewport
    ensure
      vp.ox = 0
      vp.oy = 0
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

SpecialBattleIntroAnimations.register("ostinato_desafio", 100,
  proc { |battle_type, foe, location|
    next false if battle_type.even? || !foe || foe.length != 1
    next OstDesafio::RIVALES.key?(foe[0].trainer_type)
  },
  proc { |viewport, battle_type, foe, location|
    OstDesafio.animar(viewport, foe[0].trainer_type)
  }
)
