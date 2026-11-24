#===============================================================================
# Pokemon Ostinato - Info del combate (la Y)
#
#   Con la Y (tecla Y o D, o pinchando la barra "Y Info") en el menu de
#   comandos se abre por la derecha el modal del diseno de David
#   (ostinato_combate_sin_interfaz_texto.kra, capa "info") con cuatro vistas,
#   igual que en la maqueta de Claude Design (InfoCombate):
#     1. La grafica: las estadisticas del Pokemon que elige, su objeto y su
#        habilidad con su explicacion.
#     2. La ruta: nombre, descripcion, una curiosidad y los Pokemon que salen
#        en ella (los vistos, con su dibujo; los demas, con "?").
#     3. Cambios: lo que se ha subido cada Pokemon del combate con sus ataques
#        (una flechita por cada +1, hasta +6; puntitos si no ha subido).
#     4. Info: tu Pokemon (de frente), sus tipos, su categoria, su entrada de
#        la Pokedex como curiosidad y sus debilidades.
#   Izquierda/derecha (o las flechas y los iconos de arriba) cambian de vista;
#   la Y o atras lo cierran.
#
#   Las piezas fijas (fondos de cada vista con sus barras en la diagonal del
#   dibujo, iconos, flechitas...) estan en Graphics/UI/Ostinato/Combate/info/.
#   Las medidas, en la pantalla de 1920x1080; dentro del panel, x - 1144.
#===============================================================================
module OstInfo
  DIR = "Graphics/UI/Ostinato/Combate/info/"
  X = 1144                      # borde izquierdo del panel
  ANCHO = 776
  F500 = "OstMedia"             # Barlow Semi Condensed Medium
  F600 = "OstEtiqueta"          # Barlow Semi Condensed SemiBold
  F700 = "OstTitulo"            # Barlow Semi Condensed Bold
  C2D = Color.new(45, 45, 45)
  C23 = Color.new(35, 35, 35)
  C3A = Color.new(58, 58, 58)
  BLANCO = Color.new(255, 255, 255)
  DESLIZ = 0.26                 # segundos que tarda en entrar/salir
  # pestanas de la barra de arriba: x, y, ancho, alto (en el panel)
  PESTANAS = [[122, 34, 77, 77], [257, 37, 69, 72], [373, 45, 70, 59], [498, 40, 43, 66]]
  FLECHAS = [[44, 40, 40, 66], [584, 40, 40, 66]]
  # colores de los tipos (el circulo grande de la tabla del .kra)
  TIPOS = [:NORMAL, :FIGHTING, :FLYING, :POISON, :GROUND, :ROCK, :BUG, :GHOST, :STEEL,
           :FIRE, :WATER, :GRASS, :ELECTRIC, :PSYCHIC, :ICE, :DRAGON, :DARK, :FAIRY]
  COLOR_TIPO = {
    :NORMAL => [130, 130, 130], :FIGHTING => [219, 149, 62], :FLYING => [125, 171, 207],
    :POISON => [137, 103, 202], :GROUND => [160, 117, 69], :ROCK => [169, 163, 133],
    :BUG => [162, 156, 55], :GHOST => [106, 77, 113], :STEEL => [120, 172, 200],
    :FIRE => [217, 110, 76], :WATER => [72, 156, 223], :GRASS => [92, 145, 59],
    :ELECTRIC => [221, 186, 62], :PSYCHIC => [220, 124, 148], :ICE => [107, 196, 199],
    :DRAGON => [88, 118, 187], :DARK => [78, 73, 70], :FAIRY => [215, 156, 226]
  }
  # mapa => [nombre, descripcion, curiosidad]
  RUTAS = {
    9 => ["Ruta 1",
          "Camino de hierba alta entre Villa Bambalina y la ciudad. Por aqu\303\255 pasan los carros del teatro cuando salen de gira.",
          "Dicen que los Pok\303\251mon de esta ruta se acercan al camino cuando oyen m\303\272sica desde el teatro."]
  }
  ESTADISTICAS = [[:ATTACK, "Ataque"], [:DEFENSE, "Defensa"], [:SPECIAL_ATTACK, "At. Esp."],
                  [:SPECIAL_DEFENSE, "Def. Esp."], [:SPEED, "Velocidad"],
                  [:ACCURACY, "Precisi\303\263n"], [:EVASION, "Evasi\303\263n"]]
  POKEMON = "Pok\303\251mon"
  ELIPSIS = "\342\200\246"
  POR4 = "\303\2274"

  def self.bmp(nombre)
    @cache ||= {}
    b = @cache[nombre]
    return b if b && !b.disposed?
    begin
      b = Bitmap.new(DIR + nombre)
    rescue
      b = Bitmap.new(4, 4)
    end
    @cache[nombre] = b
    return b
  end

  def self.soltar_cache
    (@cache || {}).each_value { |b| b.dispose if b && !b.disposed? }
    @cache = {}
  end

  # letra por su tamano CSS (Barlow: mayusculas = 0,7 del tamano)
  def self.letra(b, fuente, css)
    OstCombate.letra(b, fuente, css * 0.7)
  end

  # texto con la linea base en "base"
  def self.texto(b, x, base, txt, alin = 0, ancho = 700, color = C2D)
    OstCombate.escribe(b, x.round, base.round, txt, alin, ancho, color)
  end

  # centrado en (cx, cy) como el translate(-50%, -50%) con line-height 1
  def self.centrado(b, cx, cy, txt, css, color = C2D)
    texto(b, cx - 300, cy + 0.4 * css, txt, 1, 600, color)
  end

  # parte un texto en lineas de "ancho" px como mucho (la letra ya puesta)
  def self.lineas(b, txt, ancho, maximo = 99)
    ret = []
    linea = ""
    txt.to_s.split(/\s+/).each do |pal|
      prueba = linea.empty? ? pal : linea + " " + pal
      if b.text_size(prueba).width > ancho && !linea.empty?
        ret.push(linea)
        linea = pal
      else
        linea = prueba
      end
    end
    ret.push(linea) if !linea.empty?
    if ret.length > maximo
      ret = ret[0, maximo]
      ret[-1] = ret[-1].sub(/\s*\S*$/, "") + ELIPSIS
    end
    return ret
  end

  # parrafo: css, line-height 1,3; top del bloque
  def self.parrafo(b, x, top, txt, css, ancho, color, maximo = 99)
    lh = css * 1.3
    lineas(b, txt, ancho, maximo).each_with_index do |l, i|
      texto(b, x, top + (lh - css * 1.2) / 2.0 + css + i * lh, l, 0, ancho + 20, color)
    end
  end

  # pildora / circulo con suavizado (fila a fila)
  def self.pildora(b, x, y, w, h, color)
    r = h / 2.0
    h.times do |fy|
      dy = (fy + 0.5 - r).abs
      next if dy > r
      dx = Math.sqrt(r * r - dy * dy)
      x0 = r - dx
      b.fill_rect(x + x0.ceil, y + fy, (w - 2 * x0.ceil), 1, color)
      fr = x0.ceil - x0
      if fr > 0.05
        c = Color.new(color.red, color.green, color.blue, (color.alpha * fr).round)
        b.fill_rect(x + x0.floor, y + fy, 1, 1, c)
        b.fill_rect(x + w - x0.ceil, y + fy, 1, 1, c)
      end
    end
  end

  # rectangulo con las esquinas redondas (radio r), suavizado
  def self.redondo(b, x, y, w, h, r, color)
    b.fill_rect(x, y + r, w, h - 2 * r, color)
    r.times do |fy|
      dy = r - (fy + 0.5)
      dx = Math.sqrt([r * r - dy * dy, 0].max)
      x0 = r - dx
      [y + fy, y + h - 1 - fy].each do |yy|
        b.fill_rect(x + x0.ceil, yy, w - 2 * x0.ceil, 1, color)
        fr = x0.ceil - x0
        next if fr <= 0.05
        c = Color.new(color.red, color.green, color.blue, (color.alpha * fr).round)
        b.fill_rect(x + x0.floor, yy, 1, 1, c)
        b.fill_rect(x + w - x0.ceil, yy, 1, 1, c)
      end
    end
  end

  # poligono relleno (suavizado: 4 subfilas y bordes parciales) y su contorno
  def self.poligono(b, pts, relleno, alfa, trazo, grosor)
    w = b.width
    n = pts.length
    b.height.times do |y|
      cov = nil
      xmin = w
      xmax = -1
      4.times do |s|
        ys = y + (s + 0.5) / 4.0
        xs = []
        n.times do |k|
          a = pts[k]
          c = pts[(k + 1) % n]
          next if !((a[1] <= ys && c[1] > ys) || (c[1] <= ys && a[1] > ys))
          xs.push(a[0] + (ys - a[1]) * (c[0] - a[0]) / (c[1] - a[1]))
        end
        next if xs.length < 2
        xs.sort!
        cov ||= Array.new(w, 0.0)
        (xs.length / 2).times do |p|
          x0 = [xs[2 * p], 0.0].max
          x1 = [xs[2 * p + 1], w - 0.001].min
          next if x1 <= x0
          i0 = x0.floor
          i1 = x1.floor
          xmin = i0 if i0 < xmin
          xmax = i1 if i1 > xmax
          if i0 == i1
            cov[i0] += (x1 - x0) * 0.25
          else
            cov[i0] += (i0 + 1 - x0) * 0.25
            ((i0 + 1)...i1).each { |i| cov[i] += 0.25 }
            cov[i1] += (x1 - i1) * 0.25
          end
        end
      end
      next if !cov
      i = xmin
      while i <= xmax
        if cov[i] >= 0.999
          j = i
          j += 1 while j + 1 <= xmax && cov[j + 1] >= 0.999
          b.fill_rect(i, y, j - i + 1, 1, Color.new(relleno.red, relleno.green, relleno.blue, alfa))
          i = j + 1
          next
        end
        if cov[i] > 0.004
          b.set_pixel(i, y, Color.new(relleno.red, relleno.green, relleno.blue, (alfa * [cov[i], 1].min).round))
        end
        i += 1
      end
    end
    return if !trazo || grosor <= 0
    # contorno: cobertura por distancia a cada lado, encima del relleno
    hw = grosor / 2.0
    cob = {}
    n.times do |k|
      a = pts[k]
      c = pts[(k + 1) % n]
      dx = c[0] - a[0]
      dy = c[1] - a[1]
      l2 = dx * dx + dy * dy
      x0 = ([a[0], c[0]].min - hw - 1).floor
      x1 = ([a[0], c[0]].max + hw + 1).ceil
      y0 = ([a[1], c[1]].min - hw - 1).floor
      y1 = ([a[1], c[1]].max + hw + 1).ceil
      (y0..y1).each do |py|
        next if py < 0 || py >= b.height
        (x0..x1).each do |px|
          next if px < 0 || px >= w
          qx = px + 0.5 - a[0]
          qy = py + 0.5 - a[1]
          t = (l2 > 0) ? ((qx * dx + qy * dy) / l2) : 0
          t = 0.0 if t < 0
          t = 1.0 if t > 1
          ex = qx - t * dx
          ey = qy - t * dy
          d = Math.sqrt(ex * ex + ey * ey)
          v = hw + 0.5 - d
          next if v <= 0
          v = 1.0 if v > 1
          clave = py * w + px
          cob[clave] = v if !cob[clave] || cob[clave] < v
        end
      end
    end
    cob.each do |clave, sa|
      px = clave % w
      py = clave / w
      e = b.get_pixel(px, py)
      ea = e.alpha / 255.0
      oa = sa + ea * (1 - sa)
      next if oa <= 0
      r = (trazo.red * sa + e.red * ea * (1 - sa)) / oa
      g = (trazo.green * sa + e.green * ea * (1 - sa)) / oa
      bl = (trazo.blue * sa + e.blue * ea * (1 - sa)) / oa
      b.set_pixel(px, py, Color.new(r.round, g.round, bl.round, (oa * 255).round))
    end
  end

  # La tira de frente de una especie (animada si la hay) y la caja de su dibujo
  # (la de todos los cuadros juntos): [bitmap, cuadros, ancho, alto, [x, y, w, h], retraso]
  def self.dibujo(species, form = 0, gender = 0, shiny = false, pkmn = nil)
    archivo = nil
    if pkmn
      archivo = OstAnimados.archivo(pkmn, false) rescue nil
    else
      archivo = GameData::Species.check_graphic_file(OstAnimados::DIR, species, form, gender, shiny, false, "Front") rescue nil
      archivo = nil if archivo && File.basename(archivo).start_with?("000")
    end
    bm = nil
    total = 1
    if archivo
      begin
        bm = Bitmap.new(archivo)
        lado = bm.height
        total = (bm.width > lado && bm.width % lado == 0) ? bm.width / lado : 1
        fw = (total > 1) ? lado : bm.width
        fh = lado
      rescue
        bm = nil
      end
    end
    retraso = 0.06
    if bm
      v = (pkmn ? OstAnimados.velocidad(pkmn, false) : 2) rescue 2
      retraso = v / 2.0 * OstAnimados::RETRASO
    else
      ab = pkmn ? GameData::Species.sprite_bitmap_from_pokemon(pkmn, false) :
                  GameData::Species.sprite_bitmap(species, form, gender, shiny, false, false)
      return nil if !ab
      bm = ab.bitmap.clone
      ab.dispose
      total = 1
      fw = bm.width
      fh = bm.height
    end
    # caja: la union de unos cuantos cuadros
    tmp = Bitmap.new(fw, fh)
    paso = [total / 7, 1].max
    caja = nil
    (0...total).step(paso).first(8).each do |i|
      tmp.clear
      tmp.blt(0, 0, bm, Rect.new(i * fw, 0, fw, fh))
      c = OstCombate.caja(tmp)
      caja = caja ? [[caja[0], c[0]].min, [caja[1], c[1]].min, [caja[2], c[2]].max, [caja[3], c[3]].max] : c
    end
    tmp.dispose
    x0 = [caja[0] - 1, 0].max
    y0 = [caja[1] - 1, 0].max
    x1 = [caja[2] + 2, fw - 1].min
    y1 = [caja[3] + 2, fh - 1].min
    return [bm, total, fw, fh, [x0, y0, x1 - x0 + 1, y1 - y0 + 1], retraso]
  end

  # "ruta1" -> "Ruta 1"
  def self.bonito(nombre)
    s = nombre.to_s.strip
    s = s.sub(/^([[:alpha:]]+)\s*(\d+)$/) { "#{$1} #{$2}" }
    return s[0, 1].upcase + s[1..-1].to_s
  end

  def self.efecto_base
    return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER.to_f if defined?(Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER)
    return Effectiveness::NORMAL_EFFECTIVE.to_f if defined?(Effectiveness::NORMAL_EFFECTIVE)
    return 1.0
  end

  # [[tipo, x4?], ...] de los tipos que le hacen mas de lo normal
  def self.debilidades(tipos)
    base = efecto_base
    ret = []
    TIPOS.each do |t|
      next if !GameData::Type.exists?(t)
      ef = Effectiveness.calculate(t, *tipos).to_f rescue base
      r = ef / base
      ret.push([t, r >= 3.9]) if r > 1.01
    end
    return ret
  end
end

#-------------------------------------------------------------------------------
# El modal
#-------------------------------------------------------------------------------
class OstInfoModal
  def initialize(scene, battle, idx)
    @scene = scene
    @battle = battle
    @idx = idx
    @battler = battle.battlers[idx]
    @vista = 0
    @viewport = Viewport.new(0, 0, OstCombate::ANCHO, OstCombate::ALTO)
    @viewport.z = 100500
    @viewport.ox = -800
    @zonas_vp = Viewport.new(0, 0, OstCombate::ANCHO, OstCombate::ALTO)
    @zonas_vp.z = 100499
    @sprites = {}
    @sprites["sombra"] = Sprite.new(@viewport)
    @sprites["sombra"].bitmap = OstInfo.bmp("sombra_modal.png")
    @sprites["sombra"].x = OstInfo::X - 60
    @sprites["fondo"] = Sprite.new(@viewport)
    @sprites["fondo"].x = OstInfo::X
    @sprites["radar"] = Sprite.new(@viewport)
    @sprites["radar"].x = OstInfo::X + 196
    @sprites["radar"].y = 223
    @sprites["capa"] = Sprite.new(@viewport)
    @sprites["capa"].bitmap = Bitmap.new(OstInfo::ANCHO, OstCombate::ALTO)
    @sprites["capa"].x = OstInfo::X
    @sprites["capa"].z = 3
    @iconos = []
    @zoom_icono = [1.0, 1.0, 1.0, 1.0]
    OstInfo::PESTANAS.each_with_index do |(x, y, w, h), i|
      s = Sprite.new(@viewport)
      s.ox = w / 2.0
      s.oy = h / 2.0
      s.x = OstInfo::X + x + w / 2.0
      s.y = y + h / 2.0
      s.z = 4
      @iconos.push(s)
    end
    # zonas para el raton (fuera del viewport que se desliza)
    @zonas = (OstInfo::PESTANAS + OstInfo::FLECHAS).map do |x, y, w, h|
      z = Sprite.new(@zonas_vp)
      z.bitmap = Bitmap.new(w, h)
      z.x = OstInfo::X + x
      z.y = y
      z.opacity = 0
      z
    end
    @animados = []     # [sprite, dibujo, escala] que se mueven
    @extra = []        # sprites de la vista actual
    @dibujos = {}
    poner_vista(0)
  end

  def dispose
    @extra.each { |s| s.dispose if !s.disposed? }
    @sprites.each_value do |s|
      next if s.disposed?
      s.bitmap.dispose if s.bitmap && (s == @sprites["capa"] || s == @sprites["radar"]) && !s.bitmap.disposed?
      s.dispose
    end
    @iconos.each { |s| s.dispose if !s.disposed? }
    @zonas.each { |z| z.bitmap.dispose; z.dispose }
    @dibujos.each_value { |d| d[0].dispose if d && d[0] && !d[0].disposed? }
    @viewport.dispose
    @zonas_vp.dispose
    OstInfo.soltar_cache
  end

  # CSS "ease": cubic-bezier(.25, .1, .25, 1)
  def ease(t)
    return 0.0 if t <= 0
    return 1.0 if t >= 1
    u = t
    6.times do
      x = 3 * 0.25 * u * (1 - u)**2 + 3 * 0.25 * u**2 * (1 - u) + u**3
      dx = 3 * 0.25 * (1 - u)**2 + 6 * (0.25 - 0.25) * u * (1 - u) + 3 * (1 - 0.25) * u**2
      break if dx.abs < 1e-6
      u -= (x - t) / dx
      u = [[u, 0.0].max, 1.0].min
    end
    return 3 * 0.1 * u * (1 - u)**2 + 3 * 1.0 * u**2 * (1 - u) + u**3
  end

  def deslizar(entrar)
    inicio = System.uptime
    loop do
      t = (System.uptime - inicio) / OstInfo::DESLIZ
      e = ease(t)
      @viewport.ox = entrar ? (-800 * (1 - e)).round : (-800 * e).round
      actualizar
      @scene.pbUpdate
      break if t >= 1
    end
  end

  def run
    deslizar(true)
    estado = @scene.pbInitializeMouseState
    loop do
      actualizar
      @scene.pbUpdate
      nueva = nil
      if Input.trigger?(Input::LEFT)
        nueva = (@vista + 3) % 4
      elsif Input.trigger?(Input::RIGHT)
        nueva = (@vista + 1) % 4
      elsif Input.trigger?(Input::BACK) || Input.trigger?(Input::SPECIAL) || OstInfoModal.tecla_y?
        pbPlayCancelSE
        break
      end
      if !nueva
        pulsado = @scene.pbCheckMouseButtons(@zonas, estado) rescue nil
        if pulsado
          if pulsado < 4
            nueva = pulsado
          elsif pulsado == 4
            nueva = (@vista + 3) % 4
          else
            nueva = (@vista + 1) % 4
          end
        end
      end
      if nueva && nueva != @vista
        pbPlayCursorSE
        poner_vista(nueva)
      end
    end
    deslizar(false)
  ensure
    dispose
  end

  def self.tecla_y?
    return Input.triggerex?(:Y) rescue false
  end

  # los iconos crecen y los dibujos se mueven
  def actualizar
    ahora = System.uptime
    @iconos.each_with_index do |s, i|
      meta = (i == @vista) ? 1.15 : 1.0
      @zoom_icono[i] += (meta - @zoom_icono[i]) * 0.3
      s.zoom_x = s.zoom_y = @zoom_icono[i]
    end
    @animados.each do |s, d, k|
      next if s.disposed? || d[1] <= 1
      i = ((ahora / d[5]).floor) % d[1]
      c = d[4]
      s.src_rect.set(i * d[2] + c[0], c[1], c[2], c[3])
    end
  end

  def dibujo_de(clave)
    return @dibujos[clave] if @dibujos.key?(clave)
    @dibujos[clave] = yield rescue nil
    return @dibujos[clave]
  end

  # un dibujo encajado (centrado) en un hueco de "lado" px como mucho
  def poner_dibujo(d, cx, cy, maximo, z = 5)
    return if !d
    c = d[4]
    k = [maximo.to_f / c[2], maximo.to_f / c[3]].min
    s = Sprite.new(@viewport)
    s.bitmap = d[0]
    s.src_rect.set(c[0], c[1], c[2], c[3])
    s.zoom_x = s.zoom_y = k
    s.x = (cx - c[2] * k / 2.0).round
    s.y = (cy - c[3] * k / 2.0).round
    s.z = z
    @extra.push(s)
    @animados.push([s, d, k])
  end

  def poner_vista(v)
    @vista = v
    @extra.each { |s| s.dispose if !s.disposed? }
    @extra = []
    @animados = []
    @iconos.each_with_index do |s, i|
      s.bitmap = OstInfo.bmp("icono#{i + 1}#{(i == v) ? '_sel' : ''}.png")
    end
    b = @sprites["capa"].bitmap
    b.clear
    @sprites["radar"].visible = (v == 0)
    case v
    when 0 then vista_grafica(b)
    when 1 then vista_ruta(b)
    when 2 then vista_cambios(b)
    when 3 then vista_info(b)
    end
  end

  #--- 1. La grafica ------------------------------------------------------------
  def vista_grafica(b)
    @sprites["fondo"].bitmap = OstInfo.bmp("fondo_grafica.png")
    bt = @battler
    vals = [bt.totalhp, bt.attack, bt.defense, bt.speed, bt.spdef, bt.spatk]
    if !@radar_hecho
      @radar_hecho = true
      rb = Bitmap.new(330, 356)
      tope = [vals.max, 1].max / 0.8
      cx = 360
      cy = 400
      vert = [[360, 233], [514, 316], [514, 483], [360, 566], [206, 483], [206, 316]]
      pts = vert.each_with_index.map do |p, i|
        k = [vals[i] / tope, 1.0].min
        [cx + (p[0] - cx) * k - 196, cy + (p[1] - cy) * k - 223]
      end
      OstInfo.poligono(rb, pts, Color.new(158, 147, 232), 235, Color.new(134, 121, 222), 2)
      @sprites["radar"].bitmap = rb
    end
    OstInfo.letra(b, OstInfo::F500, 30)
    [["PS", 360, 165], ["Ataque", 582, 287], ["Defensa", 582, 512], ["Velocidad", 360, 634],
     ["Def. Esp.", 139, 512], ["At. Esp.", 139, 287]].each do |t, x, y|
      OstInfo.centrado(b, x, y, t, 30)
    end
    OstInfo.letra(b, OstInfo::F600, 32)
    OstInfo.centrado(b, 360, 209, "#{bt.hp} / #{bt.totalhp}", 32)
    [[bt.attack, 582, 331], [bt.defense, 582, 467], [bt.speed, 360, 589],
     [bt.spdef, 139, 467], [bt.spatk, 139, 331]].each do |n, x, y|
      OstInfo.centrado(b, x, y, n.to_s, 32)
    end
    OstInfo.letra(b, OstInfo::F600, 30)
    OstInfo.texto(b, 0, 729, "Objeto", 1, 288)
    OstInfo.texto(b, 0, 805, "Habilidad", 1, 288)
    objeto = (bt.item_id) ? (GameData::Item.get(bt.item_id).name rescue "Ninguno") : "Ninguno"
    habilidad = (bt.abilityName rescue "").to_s
    explica = (GameData::Ability.get(bt.ability_id).description rescue "").to_s
    OstInfo.letra(b, OstInfo::F600, 32)
    OstInfo.texto(b, 318, 729.8, objeto, 0, 440, OstInfo::C23)
    OstInfo.texto(b, 318, 805.8, habilidad, 0, 440, OstInfo::C23)
    OstInfo.letra(b, OstInfo::F500, 30)
    OstInfo.parrafo(b, 34, 846, explica, 30, 690, OstInfo::C3A, 3)
  end

  #--- 2. La ruta ---------------------------------------------------------------
  def vista_ruta(b)
    @sprites["fondo"].bitmap = OstInfo.bmp("fondo_ruta.png")
    id = ($game_map.map_id rescue 0)
    datos = OstInfo::RUTAS[id] || []
    nombre = datos[0] || OstInfo.bonito(($game_map.name rescue "") || "")
    OstInfo.letra(b, OstInfo::F700, 48)
    OstInfo.texto(b, 48, 171 + 0.9 * 48, nombre, 0, 700, OstInfo::C23)
    OstInfo.letra(b, OstInfo::F500, 28)
    OstInfo.parrafo(b, 48, 231, datos[1] || "", 28, 690, OstInfo::C3A, 3)
    OstInfo.parrafo(b, 48, 455, datos[2] || "", 28, 690, OstInfo::C3A, 3)
    OstInfo.letra(b, OstInfo::F600, 30)
    OstInfo.texto(b, 0, 420, "Curiosidad", 1, 288)
    OstInfo.texto(b, 0, 645, OstInfo::POKEMON + " de la ruta", 1, 288)
    # las especies: las del combate (si es salvaje) y las de los encuentros del mapa
    especies = []
    if @battle.wildBattle?
      @battle.battlers.each { |bt| especies.push(bt.species) if bt && bt.opposes? && !especies.include?(bt.species) }
    end
    begin
      enc = GameData::Encounter.get(id, $PokemonGlobal.encounterVersion)
      if enc
        enc.types.each_value do |lista|
          lista.each { |e| especies.push(e[1]) if !especies.include?(e[1]) }
        end
      end
    rescue
    end
    especies = especies[0, 8]
    huecos = [((especies.length + 3) / 4) * 4, 4].max
    huecos.times do |i|
      sp = especies[i]
      tx = 48 + (i % 4) * 172
      ty = 680 + (i / 4) * 165
      b.blt(tx, ty, OstInfo.bmp("casilla.png"), Rect.new(0, 0, 128, 150))
      visto = sp && ($player.seen?(sp) rescue true)
      OstInfo.letra(b, OstInfo::F600, 22)
      if visto
        d = dibujo_de([:sp, sp]) { OstInfo.dibujo(sp) }
        poner_dibujo(d, OstInfo::X + tx + 14 + 50, ty + 8 + 50, 100)
        nom = (GameData::Species.get(sp).name rescue sp.to_s)
        OstInfo.texto(b, tx, ty + 135.6, nom, 1, 128)
      else
        b.blt(tx + 24, ty + 14, OstInfo.bmp("interrogante.png"), Rect.new(0, 0, 80, 80))
        OstInfo.letra(b, OstInfo::F700, 52)
        OstInfo.texto(b, tx, ty + 74.8, "?", 1, 128, OstInfo::BLANCO)
        OstInfo.letra(b, OstInfo::F600, 22)
        OstInfo.texto(b, tx, ty + 135.6, "???", 1, 128)
      end
    end
  end

  #--- 3. Cambios de caracteristicas ---------------------------------------------
  def vista_cambios(b)
    doble = begin
      @battle.pbSideSize(0) > 1 || @battle.pbSideSize(1) > 1
    rescue
      false
    end
    @sprites["fondo"].bitmap = OstInfo.bmp(doble ? "fondo_cambios2.png" : "fondo_cambios1.png")
    sitios = doble ? [[0, 0, 147], [2, 388, 147], [1, 0, 589], [3, 388, 589]] : [[0, 0, 147], [1, 0, 589]]
    sitios.each do |i, x0, y0|
      bt = @battle.battlers[i]
      next if !bt || !bt.pokemon
      titulo = bt.opposes? ? (@battle.wildBattle? ? "#{bt.name} salvaje" : "#{bt.name} rival") : "Tu #{bt.name}"
      if doble
        OstInfo.letra(b, OstInfo::F600, 28)
        OstInfo.texto(b, x0, y0 + 42.2, titulo, 1, 288)
      else
        OstInfo.letra(b, OstInfo::F600, 30)
        OstInfo.texto(b, x0, y0 + 43, titulo, 1, 288)
      end
      OstInfo::ESTADISTICAS.each_with_index do |(st, nom), k|
        y = y0 + 70 + k * 48
        sube = (bt.stages[st] rescue 0).to_i
        sube = 0 if sube < 0
        sube = 6 if sube > 6
        if doble
          OstInfo.letra(b, OstInfo::F600, 24)
          OstInfo.texto(b, x0 + 18, y + 31.6, nom, 0, 130)
          sx = x0 + 140
          paso = 36
          fl = OstInfo.bmp("flecha_p.png")
        else
          OstInfo.letra(b, OstInfo::F600, 27)
          OstInfo.texto(b, 48, y + 32.8, nom, 0, 200)
          sx = 266
          paso = 72
          fl = OstInfo.bmp("flecha_g.png")
        end
        pt = OstInfo.bmp("punto.png")
        6.times do |j|
          cx = sx + paso / 2 + j * paso
          if j < sube
            b.blt(cx - fl.width / 2, y - 1, fl, fl.rect)
          else
            b.blt(cx - 7, y + 22 - 7, pt, pt.rect)
          end
        end
      end
    end
  end

  #--- 4. Info de tu Pokemon ------------------------------------------------------
  def vista_info(b)
    @sprites["fondo"].bitmap = OstInfo.bmp("fondo_info.png")
    bt = @battler
    pk = bt.displayPokemon rescue bt.pokemon
    datos = GameData::Species.get_species_form(pk.species, pk.form) rescue GameData::Species.get(pk.species)
    # titulo: nombre y nivel en la misma linea base
    base = 171 + 0.9 * 48
    OstInfo.letra(b, OstInfo::F700, 48)
    nombre = bt.name.to_s
    OstInfo.texto(b, 48, base, nombre, 0, 600, OstInfo::C23)
    x = 48 + b.text_size(nombre + " ").width + 10
    OstInfo.letra(b, OstInfo::F600, 30)
    OstInfo.texto(b, x, base, "Nv. #{bt.level}", 0, 300, OstInfo::C23)
    # el retrato, de frente, encajado en el circulo (260 como mucho)
    d = dibujo_de([:yo, pk.species, pk.form, pk.shiny?]) { OstInfo.dibujo(pk.species, pk.form, pk.gender, pk.shiny?, pk) }
    poner_dibujo(d, OstInfo::X + 388, 382, 260)
    # tipos y categoria
    tipos = (bt.pbTypes(true) rescue pk.types).uniq
    x = 48
    tipos.each do |t|
      OstInfo.letra(b, OstInfo::F700, 26)
      nom = GameData::Type.get(t).name rescue t.to_s
      w = b.text_size(nom).width + 44
      col = OstInfo::COLOR_TIPO[t] || [130, 130, 130]
      OstInfo.pildora(b, x, 547, w, 39, Color.new(col[0], col[1], col[2]))
      OstInfo.texto(b, x, 577, nom, 1, w, OstInfo::BLANCO)
      x += w + 12
    end
    if datos && datos.category && !datos.category.empty?
      OstInfo.letra(b, OstInfo::F600, 28)
      OstInfo.texto(b, x + 4, 577.8, OstInfo::POKEMON + " #{datos.category}", 0, 700, OstInfo::C3A)
    end
    # curiosidad: su entrada de la Pokedex
    OstInfo.letra(b, OstInfo::F600, 30)
    OstInfo.texto(b, 0, 670, "Curiosidad", 1, 288)
    OstInfo.texto(b, 0, 900, "Debilidades", 1, 288)
    OstInfo.letra(b, OstInfo::F500, 28)
    OstInfo.parrafo(b, 48, 707, (datos ? datos.pokedex_entry : ""), 28, 690, OstInfo::C3A, 3)
    # debilidades: circulo del color del tipo con su icono, el nombre y x4 si toca
    x = 48
    deb = OstInfo.debilidades(tipos)
    if deb.empty?
      OstInfo.letra(b, OstInfo::F600, 28)
      OstInfo.texto(b, x, 976.2, "Ninguna", 0, 600)
    end
    deb.each do |t, x4|
      sombra = OstInfo.bmp("sombra_tipo.png")
      b.blt(x - 8, 933 - 8, sombra, sombra.rect)
      col = OstInfo::COLOR_TIPO[t] || [130, 130, 130]
      OstInfo.pildora(b, x, 933, 64, 64, Color.new(col[0], col[1], col[2]))
      ic = OstInfo.bmp("tipos/#{t}.png")
      b.blt(x + 9, 933 + 9, ic, ic.rect)
      x += 64 + 12
      OstInfo.letra(b, OstInfo::F600, 28)
      nom = GameData::Type.get(t).name rescue t.to_s
      OstInfo.texto(b, x, 976.2, nom, 0, 300)
      x += b.text_size(nom).width
      if x4
        x += 12
        OstInfo.letra(b, OstInfo::F700, 22)
        w = b.text_size(OstInfo::POR4).width + 20
        OstInfo.redondo(b, x, 950, w, 30, 8, Color.new(35, 35, 35))
        OstInfo.texto(b, x, 973.8, OstInfo::POR4, 1, w, OstInfo::BLANCO)
        x += w
      end
      x += 30
    end
  end
end

#-------------------------------------------------------------------------------
# La Y en el menu de comandos: una zona invisible encima de la barra "Y Info"
# para el raton, y abrir el modal desde el bucle del menu
#-------------------------------------------------------------------------------
class Battle::Scene::CommandMenu
  alias ostinfo_initialize initialize
  def initialize(viewport, z)
    ostinfo_initialize(viewport, z)
    return if !@ost
    @ostZonaY = Sprite.new(viewport)
    @ostZonaY.bitmap = Bitmap.new(244, 50)
    @ostZonaY.x = 1676
    @ostZonaY.y = 525
    @ostZonaY.opacity = 0
    addSprite("zonaY", @ostZonaY)
  end

  def ost_zona_y; return @ostZonaY; end

  alias ostinfo_dispose dispose
  def dispose
    @ostZonaY.bitmap.dispose if @ostZonaY && !@ostZonaY.disposed? && @ostZonaY.bitmap
    ostinfo_dispose
  end
end

class Battle::Scene
  def ost_abrir_info(idxBattler)
    pbPlayDecisionSE
    OstInfoModal.new(self, @battle, idxBattler).run
  rescue StandardError => e
    echoln("OstInfo: #{e.class}: #{e.message}\n#{(e.backtrace || [])[0, 6].join("\n")}")
  end

  # lo llama el bucle del menu de comandos (016) cada fotograma
  def ost_info_pedida?(cw, estado)
    return true if Input.trigger?(Input::SPECIAL) || OstInfoModal.tecla_y?
    return false if !cw.respond_to?(:ost_zona_y) || !cw.ost_zona_y
    return !!(pbCheckMouseButtons([cw.ost_zona_y], estado) rescue false)
  end
end
