#===============================================================================
# Pokemon Ostinato - El tunel de la ruta 4 (mapas 15 a 18), vivo
#
#   Encima del mapa, en el mismo viewport (como las farolas de 007):
#   - el agua se mueve (ondula) y le corren reflejos de luz por encima;
#   - todo esta a oscuras salvo donde hay lamparas (cada una late y alguna
#     parpadea) y la luz de la calle en la entrada, con sus rayos;
#   - Kaia lleva un poco de luz alrededor;
#   - caen gotas del techo en los charcos y en el agua: la gota, la onda que
#     se abre y su "plic" con eco, mas fuerte cuanto mas cerca;
#   - motas de polvo flotando en la luz y una niebla muy suave;
#   - sonido de fondo del tunel (BGS "Tunel ambiente").
#   Arte en Graphics/Pictures/Tunel/ (agua_N, brillo_N y oscuro_N de cada
#   mapa, sacados de la imagen del mapa; luz, onda, gota, mota, niebla, rayos).
#===============================================================================
module OstTunel
  DIR = "Graphics/Pictures/Tunel/"
  BGS = "Tunel ambiente"
  BGS_VOLUMEN = 40     # por debajo de la musica (BGM "Tunel ruta 4", en los mapas)
  # el circulo de luz alrededor de Kaia, como en las cuevas de Pokemon:
  # dentro no hay oscuridad; el borde es escalonado (PASO) y se oscurece en BORDE
  RADIO = 80
  BORDE = 16
  PASO  = 4

  # Todo en pixeles del mapa (32 por casilla).
  #   :agua      donde va la imagen agua_N (x, y)
  #   :lamparas  [x, y, :calida / :fria / :parpadea]
  #   :charcos   donde caen gotas ademas de en el agua
  #   :entrada   luz de la calle que entra (x del centro, y del borde), o nil
  MAPAS = {
    15 => {
      :agua     => [64, 551],
      :lamparas => [[175, 368, :calida], [528, 368, :calida], [623, 368, :parpadea], [528, 718, :calida],
                    [623, 718, :calida], [207, 943, :calida], [559, 943, :calida]],
      :charcos  => [[290, 436], [226, 478], [611, 626], [547, 1088], [305, 1005], [510, 1010]],
      :entrada  => [384, 1376]
    },
    16 => {
      :agua     => [64, 551],
      :lamparas => [[400, 81, :calida], [177, 369, :calida], [560, 1075, :parpadea], [545, 705, :fria]],
      :charcos  => [[288, 431], [223, 471], [440, 300], [700, 800]],
      :entrada  => nil
    },
    # parte 3: el arroyo, y la luz del dia que entra por un agujero del techo
    # sobre la hierba (va como :entrada: sus rayos y sus motas)
    17 => {
      :agua     => [676, 230],
      :lamparas => [[110, 110, :calida], [335, 110, :calida], [592, 110, :parpadea], [72, 430, :calida],
                    [880, 82, :calida], [1073, 82, :calida], [1265, 82, :calida], [912, 432, :calida],
                    [1232, 432, :fria]],
      :charcos  => [[128, 378], [585, 210], [545, 575]],
      :entrada  => [480, 330]
    },
    # parte 4, la ultima: la estacion, la sala del techo hundido y la escalera
    # de salida, por donde entra la luz de la calle (va como :entrada)
    18 => {
      :agua     => [802, 646],
      :lamparas => [[145, 48, :calida], [752, 48, :parpadea], [80, 370, :calida], [400, 368, :calida],
                    [558, 302, :calida], [815, 240, :calida], [1103, 145, :calida], [880, 592, :fria]],
      :charcos  => [[240, 655], [1232, 640], [1195, 340], [1255, 300]],
      :entrada  => [1215, 230]
    }
  }

  def self.bmp(nombre)
    return Bitmap.new(DIR + nombre) rescue nil
  end

  # el sonido de fondo: suena en el tunel y se apaga al salir
  def self.sonido(dentro)
    actual = ($game_system.playing_bgs.name rescue "")
    if dentro
      pbBGSPlay(BGS, BGS_VOLUMEN) if actual != BGS
    elsif actual == BGS
      pbBGSFade(1.0)
    end
  rescue
  end
end

class OstTunelVivo
  def initialize(viewport, map, datos)
    @vp = viewport
    @map = map
    @d = datos
    @t = 0
    @disposed = false
    @sub = Game_Map::X_SUBPIXELS
    @suby = Game_Map::Y_SUBPIXELS
    @fijos = []      # [sprite, x del mapa, y del mapa]
    # el agua: la misma agua del mapa, ondulando
    @agua = sprite("agua_#{map.map_id}.png", 2)
    if @agua
      @agua.wave_amp = 2 rescue nil
      @agua.wave_length = 110 rescue nil
      @agua.wave_speed = 260 rescue nil
      @fijos.push([@agua, datos[:agua][0], datos[:agua][1]])
    end
    # los reflejos que le corren por encima
    @brillo = sprite("brillo_#{map.map_id}.png", 3)
    if @brillo
      @brillo.blend_type = 1
      @brillo_w = @brillo.bitmap.width / 12
      @brillo.src_rect = Rect.new(0, 0, @brillo_w, @brillo.bitmap.height)
      @fijos.push([@brillo, datos[:agua][0], datos[:agua][1]])
    end
    # niebla muy suave
    @niebla = Plane.new(@vp)
    @niebla.bitmap = OstTunel.bmp("niebla.png")
    @niebla.z = 1400
    @niebla.opacity = 60
    @niebla.blend_type = 1
    # la oscuridad, con sus huecos de luz
    @oscuro_src = OstTunel.bmp("oscuro_#{map.map_id}.png")
    if @oscuro_src
      @oscuro = Sprite.new(@vp)
      @oscuro.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      @oscuro.z = 1500
    end
    # las lamparas
    @lamparas = []
    datos[:lamparas].each do |x, y, tipo|
      s = sprite(tipo == :fria || tipo == :parpadea ? "luz_fria.png" : "luz.png", 1501)
      next if !s
      s.blend_type = 1
      s.ox = s.bitmap.width / 2
      s.oy = s.bitmap.height / 2
      s.zoom_x = s.zoom_y = (tipo == :fria ? 0.9 : 1.15)
      @lamparas.push([s, x, y, tipo, rand(628) / 100.0, 0])
    end
    # los rayos de la calle en la entrada
    if datos[:entrada]
      @rayos = sprite("rayos.png", 1502)
      if @rayos
        @rayos.blend_type = 1
        @rayos.ox = @rayos.bitmap.width / 2
        @rayos.oy = @rayos.bitmap.height
        @rayos.zoom_x = 1.25
        @rayos.zoom_y = 1.4
      end
    end
    # la luz que lleva Kaia
    @kaia = sprite("luz.png", 1501)
    if @kaia
      @kaia.blend_type = 1
      @kaia.ox = @kaia.bitmap.width / 2
      @kaia.oy = @kaia.bitmap.height / 2
      @kaia.zoom_x = @kaia.zoom_y = 0.75
      @kaia.opacity = 110
    end

    # bitmaps de los efectos pequenos (se comparten)
    @b_onda = OstTunel.bmp("onda.png")
    @b_gota = OstTunel.bmp("gota.png")
    @b_mota = OstTunel.bmp("mota.png")
    @gotas = []      # [sprite gota, x, y destino, y actual, velocidad]
    @ondas = []      # [sprite, cuadro, x, y]
    @motas = []      # [sprite, x, y, vx, vy, vida, edad]
    @destellos = []  # [sprite, x, y, edad]
    @proxima = 30
    update
  end

  def sprite(nombre, z)
    b = OstTunel.bmp(nombre)
    return nil if !b
    s = Sprite.new(@vp)
    s.bitmap = b
    s.z = z
    return s
  end

  def disposed?; return @disposed; end

  def dispose
    return if @disposed
    todos = [@agua, @brillo, @oscuro, @rayos, @kaia] + @lamparas.map { |l| l[0] }
    todos.compact.each do |s|
      next if s.disposed?
      s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
      s.dispose
    end
    (@gotas.map { |g| g[0] } + @ondas.map { |o| o[0] } + @motas.map { |m| m[0] } + @destellos.map { |d| d[0] }).each { |s| s.dispose if !s.disposed? }
    if @niebla && !@niebla.disposed?
      @niebla.bitmap.dispose if @niebla.bitmap
      @niebla.dispose
    end
    [@b_onda, @b_gota, @b_mota, @oscuro_src].each { |b| b.dispose if b && !b.disposed? }
    @disposed = true
  end

  # pixel del mapa -> pantalla
  def sx(x); return x - @map.display_x / @sub; end
  def sy(y); return y - @map.display_y / @suby; end

  def update
    return if @disposed
    @t += 1
    @fijos.each { |s, x, y| s.x = sx(x); s.y = sy(y) }
    oscuridad
    @agua.update if @agua
    if @agua
      # el agua respira: un poco mas clara y mas oscura
      v = (10 * Math.sin(@t / 50.0)).round
      @agua.tone.set(v, v + 4, v + 6, 0)
    end
    if @brillo
      cuadro = (@t / 7) % 12
      @brillo.src_rect.x = cuadro * @brillo_w
      @brillo.opacity = 150 + (40 * Math.sin(@t / 37.0)).round
    end
    if @niebla
      @niebla.ox = (@map.display_x / @sub) + (@t * 0.25).to_i
      @niebla.oy = (@map.display_y / @suby) + (@t * 0.1).to_i
    end
    lamparas
    if @rayos
      e = @d[:entrada]
      @rayos.x = sx(e[0])
      @rayos.y = sy(e[1])
      @rayos.opacity = 170 + (50 * Math.sin(@t / 45.0)).round
    end
    if @kaia && $game_player
      @kaia.x = $game_player.screen_x
      @kaia.y = $game_player.screen_y - 20
      @kaia.opacity = 62 + (6 * Math.sin(@t / 13.0)).round
    end
    gotas
    motas
    destellos
  end

  def lamparas
    @lamparas.each do |l|
      s, x, y, tipo, fase = l
      l[4] += 0.05
      op = 150 + (14 * Math.sin(l[4])) + (8 * Math.sin(l[4] * 2.9))
      if tipo == :parpadea
        # de vez en cuando falla: unos tirones y se apaga un momento
        l[5] = 40 + rand(200) if l[5] <= 0 && rand(240) == 0
        if l[5] > 0
          l[5] -= 1
          op = (l[5] % 7 < 3) ? 25 : op * 0.6 if l[5] < 30
        end
      elsif tipo == :fria
        op *= 0.75
      end
      s.opacity = op.round
      s.x = sx(x)
      s.y = sy(y)
    end
  end

  # gotas que caen del techo en un charco o en el agua
  def gotas
    @proxima -= 1
    if @proxima <= 0
      @proxima = 25 + rand(55)
      destino = nil
      if rand(100) < 45 || !@agua
        c = @d[:charcos].sample
        destino = [c[0] + rand(9) - 4, c[1] + rand(5) - 2] if c
      else
        destino = punto_de_agua
      end
      if destino && @b_gota
        s = Sprite.new(@vp)
        s.bitmap = @b_gota
        s.z = 1499
        s.ox = 1
        s.oy = 8
        @gotas.push([s, destino[0], destino[1], destino[1] - 70 - rand(40), 1.5])
      end
    end
    @gotas.delete_if do |g|
      s = g[0]
      g[4] += 0.55
      g[3] += g[4]
      s.x = sx(g[1])
      s.y = sy(g[3].round)
      if g[3] >= g[2]
        s.dispose
        onda(g[1], g[2])
        true
      else
        false
      end
    end
    @ondas.delete_if do |o|
      s = o[0]
      o[1] += 1
      cuadro = o[1] / 3
      if cuadro >= 10
        s.dispose
        true
      else
        s.src_rect = Rect.new(cuadro * 48, 0, 48, 24)
        s.x = sx(o[2])
        s.y = sy(o[3])
        false
      end
    end
  end

  def punto_de_agua
    return nil if !@agua
    b = @agua.bitmap
    12.times do
      x = rand(b.width)
      y = rand(b.height)
      next if b.get_pixel(x, y).alpha < 10
      return [x + @d[:agua][0], y + @d[:agua][1]]
    end
    return nil
  end

  def onda(x, y)
    if @b_onda
      s = Sprite.new(@vp)
      s.bitmap = @b_onda
      s.blend_type = 1
      s.z = 4
      s.ox = 24
      s.oy = 12
      s.src_rect = Rect.new(0, 0, 48, 24)
      @ondas.push([s, 0, x, y])
    end
    # salpicadura: dos o tres gotitas que saltan
    if @b_mota
      (2 + rand(2)).times do
        m = Sprite.new(@vp)
        m.bitmap = @b_mota
        m.blend_type = 1
        m.z = 5
        m.zoom_x = m.zoom_y = 0.5
        @motas.push([m, x.to_f, y.to_f - 2, (rand - 0.5) * 1.6, -1.2 - rand * 1.2, 16, 0, true])
      end
    end
    # el plic, mas fuerte cuanto mas cerca de Kaia
    if $game_player
      dx = sx(x) - $game_player.screen_x
      dy = sy(y) - $game_player.screen_y
      dist = Math.sqrt(dx * dx + dy * dy)
      vol = (85 - dist / 5).round
      pbSEPlay("Tunel gota #{1 + rand(3)}", vol, 85 + rand(30)) if vol > 8
    end
  rescue
  end

  # La oscuridad del trozo de mapa que se ve, con el circulo de luz de Kaia
  # recortado: dentro, nada; en el borde, escalones de PASO px que se van
  # oscureciendo hasta la oscuridad que hubiera alli (las lamparas la bajan).
  def oscuridad
    return if !@oscuro || !@oscuro_src
    b = @oscuro.bitmap
    b.clear
    mx = (@map.display_x / @sub).round; my = (@map.display_y / @suby).round
    b.blt(0, 0, @oscuro_src, Rect.new(mx, my, b.width, b.height))
    return if !$game_player
    cx = $game_player.screen_x
    cy = $game_player.screen_y - 16
    r = OstTunel::RADIO; bo = OstTunel::BORDE; pa = OstTunel::PASO
    ext = r + bo
    y = -ext
    while y < ext
      x = -ext
      while x < ext
        d = Math.sqrt((x + pa / 2.0) ** 2 + (y + pa / 2.0) ** 2)
        if d < r
          b.clear_rect(cx + x, cy + y, pa, pa)
        elsif d < ext
          # el mismo trozo de oscuridad, pero mas flojo cuanto mas cerca de Kaia
          b.clear_rect(cx + x, cy + y, pa, pa)
          b.blt(cx + x, cy + y, @oscuro_src, Rect.new(mx + cx + x, my + cy + y, pa, pa), (255 * (d - r) / bo).round)
        end
        x += pa
      end
      y += pa
    end
  end

  # motas de polvo flotando en la luz (y las gotitas de las salpicaduras)
  def motas
    if @b_mota && @motas.count { |m| !m[7] } < 28 && rand(6) == 0
      foco = (@lamparas.map { |l| [l[1], l[2] + 40] } + (@d[:entrada] ? [[@d[:entrada][0], @d[:entrada][1] - 120]] * 3 : [])).sample
      if foco
        m = Sprite.new(@vp)
        m.bitmap = @b_mota
        m.blend_type = 1
        m.z = 1503
        m.zoom_x = m.zoom_y = 0.5
        @motas.push([m, foco[0] + rand(140) - 70.0, foco[1] + rand(90) - 45.0, (rand - 0.5) * 0.25, -0.05 - rand * 0.15, 160 + rand(160), 0, false])
      end
    end
    @motas.delete_if do |m|
      s = m[0]
      m[6] += 1
      if m[7]          # gotita de salpicadura: cae
        m[4] += 0.18
      else
        m[3] += Math.sin((@t + m[5]) / 40.0) * 0.01
      end
      m[1] += m[3]
      m[2] += m[4]
      vida = m[6].to_f / m[5]
      s.opacity = (m[7] ? 220 * (1 - vida) : 160 * Math.sin(Math::PI * [vida, 1.0].min))
      s.x = sx(m[1].round)
      s.y = sy(m[2].round)
      if m[6] >= m[5]
        s.dispose
        true
      else
        false
      end
    end
  end

  # destellos de luz sobre el agua, como reflejos
  def destellos
    if @b_mota && @destellos.length < 6 && rand(9) == 0
      p = punto_de_agua
      if p
        s = Sprite.new(@vp)
        s.bitmap = @b_mota
        s.blend_type = 1
        s.z = 6
        @destellos.push([s, p[0], p[1], 0])
      end
    end
    @destellos.delete_if do |d|
      s = d[0]
      d[3] += 1
      s.opacity = 255 * Math.sin(Math::PI * d[3] / 24.0)
      s.zoom_x = s.zoom_y = 0.6 + 0.5 * Math.sin(Math::PI * d[3] / 24.0)
      s.x = sx(d[1])
      s.y = sy(d[2])
      if d[3] >= 24
        s.dispose
        true
      else
        false
      end
    end
  end
end

EventHandlers.add(:on_new_spriteset_map, :ostinato_tunel_vivo,
  proc { |spriteset, viewport|
    mapa = spriteset.map
    datos = OstTunel::MAPAS[mapa.map_id]
    if mapa == $game_map
      OstTunel.sonido(datos ? true : false)
    end
    next if !datos
    spriteset.addUserSprite(OstTunelVivo.new(viewport, mapa, datos))
  }
)
