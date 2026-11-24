#===============================================================================
# Pokemon Ostinato - Las luces de la discoteca (interior del gimnasio 1, mapa 20).
#
# Mismo modelo que las farolas (007_Farolas.rb) y que la maqueta
# recursos/gimnasio_discoteca/luces.py: la sala se oscurece con un velo morado
# y encima se dibuja lo que brilla solo (neones, pantallas de las lamparas,
# pista que late) y se suma luz de color (focos que barren, bola de espejos con
# sus puntos de luz, lamparas calidas).
# Las imagenes estan en Graphics/Pictures/Discoteca (las hace
# Downloads/taller/gimnasio_interior/luces.py). Todo en pixeles del mapa.
#===============================================================================
module OstDiscoteca
  MAPA = 20
  DIR  = "Graphics/Pictures/Discoteca/"

  # Los 6 focos de la tarima: pie (abajo en el centro) y lente, relativa al pie.
  FOCOS = [
    [307.0, 280.0, -7.5, -15.2], [378.0, 280.0, -7.5, -15.2], [427.0, 280.0, -7.0, -15.2],
    [566.5, 280.0, -7.3, -15.2], [616.5, 280.0, -7.3, -13.3], [687.0, 280.0, -7.5, -15.2]
  ]
  # Baldosas de la pista (4x3): esquina y fase de su latido.
  BALDOSAS = [
    [349, 404, 0.0], [424, 404, 3.665], [499, 404, 1.047], [574, 404, 4.712],
    [349, 468, 0.524], [424, 468, 4.189], [499, 468, 1.571], [574, 468, 5.236],
    [349, 532, 1.047], [424, 532, 4.712], [499, 532, 2.094], [574, 532, 5.76]
  ]
  # Lamparas de los reservados: centro y radio de su luz.
  LAMPARAS = [
    [871.3, 225.1, 72.3], [870.5, 408.2, 72.3], [871.3, 591.4, 72.3],
    [947.4, 139.6, 53.7], [948.2, 321.2, 53.7], [948.6, 505.2, 53.7]
  ]
  COLORES = [[255, 64, 115], [77, 140, 255], [255, 217, 64], [90, 255, 140], [217, 77, 255], [64, 242, 255]]
  CALIDA  = [255, 184, 107]
  BOLA_X, BOLA_Y = 498.0, 417.0   # centro de la bola
  BOLA_ESQ = [448, 352]           # esquina de sus 3x3 casillas
  ANCHO, ALTO = 992.0, 736.0
  N_PUNTOS = 90

  def self.segundos
    begin
      return System.uptime
    rescue StandardError
      return Graphics.frame_count / 40.0
    end
  end
end



class OstDiscotecaLuces
  def initialize(viewport, map)
    @map = map
    @vp = viewport
    @bitmaps = {}
    @sprites = []
    @t0 = OstDiscoteca.segundos
    @sub_x = Game_Map::X_SUBPIXELS
    @sub_y = Game_Map::Y_SUBPIXELS
    @disposed = false
    # velo oscuro (encima de todo el mapa y de los personajes)
    @oscuro = nuevo("oscuridad", 3000)
    # lo que brilla solo
    @brillan = nuevo("brillan", 3010)
    @halo_neon = nuevo("brillan_halo", 3020, 1)
    # la pista: cada baldosa se apaga y se enciende con una sombra justo encima del suelo
    # (z 1: por debajo de los personajes, que la pisan sin quedar tapados)
    @sombra = Bitmap.new(75, 64)
    @sombra.fill_rect(0, 0, 75, 64, Color.new(10, 0, 25))
    @baldosas = OstDiscoteca::BALDOSAS.map { |b|
      s = Sprite.new(@vp)
      s.bitmap = @sombra
      s.z = 1
      @sprites.push(s)
      [s, b]
    }
    # bola: 24 fotogramas
    @bola_frames = (0...24).map { |i| cargar("bola%02d" % i) }
    @bola = Sprite.new(@vp)
    @bola.z = 3030
    @sprites.push(@bola)
    # lamparas calidas
    @lamparas = OstDiscoteca::LAMPARAS.map { |l|
      s = nuevo("halo", 3040, 1)
      s.ox = 64; s.oy = 64
      s.zoom_x = s.zoom_y = l[2] / 29.0
      s.color = Color.new(*OstDiscoteca::CALIDA, 255)
      [s, l]
    }
    # focos: aparato (debajo del velo, ordenado como un personaje), haz, charco y lente
    @focos = OstDiscoteca::FOCOS.each_with_index.map { |f, i|
      cuerpo = nuevo("foco#{i}", 0)
      cuerpo.ox = cuerpo.bitmap.width / 2
      cuerpo.oy = cuerpo.bitmap.height
      haz = nuevo("haz", 3050, 1)
      haz.ox = 48; haz.oy = 0
      charco = nuevo("halo", 3040, 1)
      charco.ox = 64; charco.oy = 64
      charco.zoom_x = 1.7; charco.zoom_y = 1.34
      lente = nuevo("halo", 3060, 1)
      lente.ox = 64; lente.oy = 64
      lente.zoom_x = lente.zoom_y = 0.28
      [cuerpo, haz, charco, lente, f]
    }
    # puntos de luz de la bola
    srand(7)
    @puntos = (0...OstDiscoteca::N_PUNTOS).map {
      s = nuevo("punto", 3060, 1)
      s.ox = 6; s.oy = 6
      tam = 2.2 + rand * 1.8
      s.zoom_x = s.zoom_y = tam / 3.3 * 0.83
      s.color = (rand < 0.75) ? Color.new(255, 255, 255, 255) :
                Color.new(128 + rand(128), 128 + rand(128), 128 + rand(128), 255)
      [s, rand * Math::PI * 2, Math.sqrt(0.04 + rand * 0.96)]
    }
    srand
    update
  end

  def cargar(nombre)
    @bitmaps[nombre] ||= (Bitmap.new(OstDiscoteca::DIR + nombre) rescue Bitmap.new(1, 1))
  end

  def nuevo(nombre, z, mezcla = 0)
    s = Sprite.new(@vp)
    s.bitmap = cargar(nombre)
    s.z = z
    s.blend_type = mezcla
    @sprites.push(s)
    return s
  end

  def disposed?
    return @disposed
  end

  def dispose
    return if @disposed
    @sprites.each { |s| s.dispose if s && !s.disposed? }
    @bitmaps.each_value { |b| b.dispose if b && !b.disposed? }
    @sombra.dispose if @sombra && !@sombra.disposed?
    @bola_frames = []
    @sprites = []
    @bitmaps = {}
    @map = nil
    @disposed = true
  end

  # de pixeles del mapa a pixeles de la pantalla
  def sx(x); return x - @map.display_x / @sub_x; end
  def sy(y); return y - @map.display_y / @sub_y; end

  def poner(s, x, y)
    s.x = sx(x).round
    s.y = sy(y).round
  end

  def update
    return if @disposed || !@map
    t = OstDiscoteca.segundos - @t0
    poner(@oscuro, 0, 0)
    poner(@brillan, 0, 0)
    poner(@halo_neon, 0, 0)
    @halo_neon.opacity = (150 + 40 * Math.sin(t * 3.1)).round
    # la pista late a 2 golpes por segundo, cada baldosa a su paso
    @baldosas.each { |s, b|
      poner(s, b[0], b[1])
      pulso = 0.55 + 0.45 * (0.5 + 0.5 * Math.sin(2 * Math::PI * 2 * t + b[2]))
      s.opacity = (175 * (1 - pulso)).round
    }
    # bola: una vuelta de brillo cada 2,5 s
    @bola.bitmap = @bola_frames[((t / 2.5) % 1.0 * 24).floor % 24]
    poner(@bola, OstDiscoteca::BOLA_ESQ[0], OstDiscoteca::BOLA_ESQ[1])
    # lamparas, con un parpadeo muy leve
    @lamparas.each { |s, l|
      poner(s, l[0], l[1])
      s.opacity = (125 * (0.96 + 0.04 * Math.sin(t * 13.0))).round
    }
    # focos: giran un poco hacia su charco, que barre la sala; el color salta cada 2 s
    w, h = OstDiscoteca::ANCHO, OstDiscoteca::ALTO
    @focos.each_with_index { |(cuerpo, haz, charco, lente, f), i|
      px, py, lx, ly = f
      tx = w * 0.5 + w * 0.32 * Math.sin(0.55 * t + i * 1.1) * (i.odd? ? 1 : -1)
      ty = h * 0.62 + h * 0.2 * Math.sin(0.8 * t + i * 0.7)
      base = Math.atan2(ly, lx)
      ang = Math.atan2(ty - py, tx - px) - base
      ang = (ang + Math::PI) % (2 * Math::PI) - Math::PI
      ang = [[ang * 0.6, -0.45].max, 0.45].min
      c = Math.cos(ang); sn = Math.sin(ang)
      ox = px + lx * c - ly * sn
      oy = py + lx * sn + ly * c
      col = OstDiscoteca::COLORES[(i + (t / 2).floor) % OstDiscoteca::COLORES.size]
      color = Color.new(col[0], col[1], col[2], 255)
      poner(cuerpo, px, py)
      cuerpo.angle = -ang * 180 / Math::PI
      cuerpo.z = cuerpo.y + 32
      vx = tx - ox; vy = ty - oy
      poner(haz, ox, oy)
      haz.angle = 90 - Math.atan2(vy, vx) * 180 / Math::PI
      haz.zoom_y = Math.sqrt(vx * vx + vy * vy) / 256.0
      haz.color = color
      haz.opacity = 120
      poner(charco, tx, ty)
      charco.color = color
      charco.opacity = 105
      poner(lente, ox, oy)
      lente.color = color
      lente.opacity = 200
    }
    # puntos de la bola girando por la sala
    giro = 0.35 * t
    @puntos.each { |s, a0, r|
      a = a0 + giro
      poner(s, OstDiscoteca::BOLA_X + Math.cos(a) * r * w * 0.55, OstDiscoteca::BOLA_Y + Math.sin(a) * r * h * 0.48)
      s.opacity = 150
    }
  end
end



EventHandlers.add(:on_new_spriteset_map, :ostinato_discoteca,
  proc { |spriteset, viewport|
    mapa = spriteset.map
    next if !mapa || mapa.map_id != OstDiscoteca::MAPA
    spriteset.addUserSprite(OstDiscotecaLuces.new(viewport, mapa))
  }
)
