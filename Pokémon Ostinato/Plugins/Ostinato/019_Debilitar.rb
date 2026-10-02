#===============================================================================
# Pokemon Ostinato - Debilitarse: vuelta a la Poke Ball
#
#   Cuando se debilita un Pokemon de entrenador (el tuyo o el del rival), en
#   vez de hundirse:
#     - suena su grito grave y su Poke Ball cae girando hasta quedar encima;
#     - la ball se abre con un destello;
#     - el Pokemon se vuelve blanco, se desvanece y queda una bola de luz;
#     - la bola vuela a la ball dejando estrellas;
#     - al entrar, un destello "tronador": relampagos en zigzag, rayos, un
#       aro de luz y un fogonazo;
#     - la ball se cierra, se tambalea y se va hacia su entrenador.
#   Los salvajes se debilitan como siempre.
#
#   Piezas: las de la v21 (Graphics/Battle animations/ball_*, ballBurst_*),
#   ampliadas como los Pokemon. Los relampagos se dibujan aqui.
#   Solo en el combate a 1920 (016_CombateHD).
#===============================================================================
class OstDebilitar
  DIR = "Graphics/Battle animations/"
  K   = OstCombate::ESCALA
  FIN = 140

  def initialize(sprites, viewport, battler)
    @sprites = sprites
    @vp = viewport
    @idx = battler.index
    @propio = !battler.opposes?
    @poke = sprites["pokemon_#{@idx}"]
    @sombra = sprites["shadow_#{@idx}"]
    @pkmn = (@poke.respond_to?(:pkmn) && @poke.pkmn) || battler.pokemon
    @f = 0
    @todo = []
    @z = @poke.z + 5
    # donde esta el Pokemon y donde flota la ball (encima de su cabeza)
    @centro = getSpriteCenter(@poke)
    @cima = cima_del_dibujo
    @bx = @centro[0]
    @by = [[@cima - 70, 110].max, OstCombate::BARRA2_Y - 230].min
    crear_sprites
  end

  def done?; return @f > FIN; end

  def dispose
    @todo.each do |s|
      next if !s || s.disposed?
      b = s.is_a?(Sprite) ? s.bitmap : nil
      s.dispose
      b.dispose if b && !b.disposed?
    end
    @rayo_bm.dispose if @rayo_bm && !@rayo_bm.disposed?
    if @poke && !@poke.disposed?
      @poke.visible = false
      @poke.opacity = 255
      @poke.color = Color.new(0, 0, 0, 0)
    end
    @sombra.visible = false if @sombra && !@sombra.disposed?
  end

  #-----------------------------------------------------------------------------
  def cima_del_dibujo
    return @centro[1] - 120 if !@poke.bitmap || @poke.bitmap.disposed?
    caja = OstCombate.caja(@poke.bitmap)
    y = OstCamara::SY.bind(@poke).call
    zy = OstCamara::SZY.bind(@poke).call
    return y - (@poke.oy - caja[1]) * zy
  end

  def bm(nombre)
    return Bitmap.new(DIR + nombre)
  rescue
    return Bitmap.new(DIR + "ballBurst_particle")
  end

  def nuevo(bitmap, z, ox = nil, oy = nil)
    s = Sprite.new(@vp)
    s.bitmap = bitmap
    s.ox = ox || bitmap.width / 2
    s.oy = oy || bitmap.height / 2
    s.z = z
    s.opacity = 0
    @todo.push(s)
    return s
  end

  def crear_sprites
    ball = @pkmn ? @pkmn.poke_ball : :POKEBALL
    ball = :POKEBALL if !pbResolveBitmap(DIR + "ball_#{ball}")
    @ball_bm = bm("ball_#{ball}")
    @abierta_bm = pbResolveBitmap(DIR + "ball_#{ball}_open") ? bm("ball_#{ball}_open") : bm("ball_POKEBALL_open")
    @ball = nuevo(@ball_bm, @z + 6, 16, 32)
    @ball.src_rect = Rect.new(0, 0, 32, 64)
    @ball.zoom_x = @ball.zoom_y = K
    @todo.push(@ball_bm, @abierta_bm)
    # el resplandor detras del Pokemon y la bola de luz (halo rojo, centro blanco)
    @halo = nuevo(bm("ballBurst_particle"), @poke.z - 1)   # detras del Pokemon
    @halo.tone = Tone.new(0, -70, -70)
    @orbe_halo = nuevo(bm("ballBurst_particle"), @z + 4)
    @orbe_halo.tone = Tone.new(0, -120, -120)
    @orbe = nuevo(bm("ballBurst_particle"), @z + 5)
    # el destello al entrar
    @estallido = nuevo(bm("ballBurst_dazzle"), @z + 8)
    @estallido.tone = Tone.new(0, 0, -110)
    @aro = nuevo(bm("ballBurst_ring1"), @z + 7)
    @aro.tone = Tone.new(0, -40, -150)
    @abre = nuevo(bm("ballBurst_dazzle"), @z + 7)
    rb = bm("ballBurst_ray")
    @rayos = Array.new(10) do |i|
      s = nuevo(rb, @z + 7, rb.width / 2, rb.height)
      s.angle = i * 36 + 10
      s.tone = Tone.new(0, 0, -90)
      s
    end
    @rayo_bm = relampago_bitmap
    @relampagos = Array.new(6) do |i|
      s = nuevo(@rayo_bm, @z + 9, @rayo_bm.width / 2, @rayo_bm.height)
      s.angle = i * 60 + rand(30)
      s.mirror = i.odd?
      s
    end
    st = bm("ballBurst_star")
    @estrellas = Array.new(10) do |i|
      a = (i * 36 + rand(20)) * Math::PI / 180
      [nuevo(st, @z + 8), Math.cos(a), Math.sin(a), 6 + rand * 5]
    end
    @rastro = Array.new(12) { nuevo(st, @z + 3) }
    @rastro_i = 0
    @fogonazo = nuevo(Bitmap.new(16, 16), 99000)
    @fogonazo.bitmap.fill_rect(0, 0, 16, 16, Color.new(255, 255, 235))
    @fogonazo.ox = @fogonazo.oy = 0
    @fogonazo.zoom_x = Graphics.width / 16.0
    @fogonazo.zoom_y = Graphics.height / 16.0
  end

  # un relampago en zigzag que sale del centro hacia arriba: nucleo blanco y
  # brillo amarillo alrededor
  def relampago_bitmap
    w = 90
    h = 300
    b = Bitmap.new(w, h)
    pts = [[w / 2, h - 1]]
    y = h - 1
    x = w / 2
    while y > 10
      y -= 22 + rand(18)
      x = [[x + rand(-26..26), 12].max, w - 12].min
      pts.push([x, [y, 4].max])
    end
    [[9, Color.new(255, 230, 90, 90)], [5, Color.new(255, 245, 160, 200)], [2, Color.new(255, 255, 255)]].each do |r, c|
      pts.each_cons(2) do |(x0, y0), (x1, y1)|
        n = [(x1 - x0).abs, (y1 - y0).abs].max
        (0..n).each do |t|
          px = x0 + (x1 - x0) * t / n.to_f
          py = y0 + (y1 - y0) * t / n.to_f
          b.fill_rect(px.round - r, py.round - r / 2, 2 * r, [r, 1].max, c)
        end
      end
    end
    return b
  end

  #-----------------------------------------------------------------------------
  def suave(t); t = [[t, 0.0].max, 1.0].min; return 1 - (1 - t) ** 3; end
  def tramo(a, b); return [[(@f - a) / (b - a).to_f, 0.0].max, 1.0].min; end
  def se(n, v = 100, p = 100); pbSEPlay(n, v, p) rescue nil; end

  def update
    return if done?
    f = @f
    # el grito, grave como en la v21
    if f == 0
      begin
        GameData::Species.play_cry_from_pokemon(@pkmn, 90, 75)
      rescue
      end
    end
    # 1) la ball cae girando y se queda flotando encima
    if f >= 10 && f < 92
      t = suave(tramo(10, 30))
      @ball.opacity = 255 * tramo(10, 14)
      @ball.x = @bx
      @ball.y = (@by - 260 + 260 * t + Math.sin(f * 0.15) * 4 * t).round
      if f < 30
        @ball.src_rect.x = ((f / 2) % 8) * 32
      elsif f == 30
        se("Battle recall")
        @ball.bitmap = @abierta_bm
        @ball.src_rect = Rect.new(0, 0, 32, 64)
      end
    end
    # destellito al abrirse
    if f >= 30 && f < 42
      t = tramo(30, 42)
      @abre.x = @bx; @abre.y = @by
      @abre.zoom_x = @abre.zoom_y = 0.4 + 1.2 * t
      @abre.opacity = 255 * (1 - t)
    end
    # 2) el Pokemon se vuelve blanco, con un resplandor rojo detras
    if f >= 32 && f <= 70
      @poke.color = Color.new(255, 255, 255, 255 * tramo(32, 50))
      @halo.x, @halo.y = @centro
      @halo.zoom_x = @halo.zoom_y = 3 + 2 * tramo(32, 60)
      @halo.opacity = 130 * tramo(32, 50) * (1 - tramo(58, 70))
    end
    # 3) se desvanece y queda la bola de luz
    if f >= 50 && f <= 70
      @poke.opacity = 255 * (1 - tramo(50, 66))
      @sombra.opacity = 255 * (1 - tramo(50, 60)) if @sombra && !@sombra.disposed?
      t = suave(tramo(50, 68))
      [[@orbe_halo, 2.6], [@orbe, 1.3]].each do |s, z|
        s.x, s.y = @centro
        s.zoom_x = s.zoom_y = z * t
        s.opacity = 255 * t
      end
    end
    # 4) vuela a la ball dejando estrellas
    if f > 70 && f <= 90
      se("Battle jump to ball") if f == 71
      t = tramo(70, 90)
      t = t * t
      x = @centro[0] + (@bx - @centro[0]) * t
      y = @centro[1] + (@by - @centro[1]) * t - Math.sin(t * Math::PI) * 60
      [[@orbe_halo, 2.6], [@orbe, 1.3]].each do |s, z|
        s.x = x.round; s.y = y.round
        s.zoom_x = s.zoom_y = z * (1 - 0.7 * t)
      end
      if f.even?
        e = @rastro[@rastro_i % @rastro.length]
        @rastro_i += 1
        e.x = x.round + rand(-20..20); e.y = y.round + rand(-20..20)
        e.opacity = 230
        e.zoom_x = e.zoom_y = 0.6 + rand * 0.5
        e.angle = rand(72)
      end
    end
    @rastro.each { |e| e.opacity -= 20 if e.opacity > 0 }
    # 5) entra: se cierra la ball y el destello tronador
    if f == 90
      se("Anim/PRSFX- Spark1")
      se("Battle ball shake", 80)
      @orbe.opacity = 0
      @orbe_halo.opacity = 0
      @ball.bitmap = @ball_bm
      @ball.src_rect = Rect.new(0, 0, 32, 64)
    end
    if f >= 90 && f < 116
      t = tramo(90, 116)
      @estallido.x = @bx; @estallido.y = @by
      @estallido.zoom_x = @estallido.zoom_y = 0.6 + 3.2 * suave(tramo(90, 100))
      @estallido.angle = f * 3
      @estallido.opacity = 255 * (1 - tramo(96, 108))
      @aro.x = @bx; @aro.y = @by
      @aro.zoom_x = @aro.zoom_y = 0.4 + 3.6 * suave(t)
      @aro.opacity = 255 * (1 - t)
      @rayos.each do |s|
        s.x = @bx; s.y = @by
        s.zoom_x = 1.2
        s.zoom_y = 0.4 + 2.4 * suave(tramo(90, 102))
        s.opacity = 255 * (1 - tramo(98, 112))
      end
      # los relampagos parpadean
      @relampagos.each_with_index do |s, i|
        s.x = @bx; s.y = @by
        s.zoom_x = s.zoom_y = 0.9 + 0.3 * tramo(90, 104)
        s.opacity = (f < 106 && (f + i) % 3 != 0) ? 255 : 0
      end
      @estrellas.each do |s, cx, cy, v|
        d = v * (f - 90)
        s.x = (@bx + cx * d).round
        s.y = (@by + cy * d + 0.25 * (f - 90) ** 2).round
        s.angle = f * 8
        s.zoom_x = s.zoom_y = 1.2 - 0.6 * t
        s.opacity = 255 * (1 - tramo(104, 116))
      end
      @fogonazo.opacity = (f < 96) ? 150 * (1 - tramo(90, 96)) : 0
    end
    # 6) se tambalea y se va hacia su entrenador
    if f >= 92 && f < 112
      @ball.x = @bx
      @ball.y = @by
      @ball.angle = 18 * Math.sin((f - 92) * 0.6) * (1 - tramo(92, 112))
    end
    if f >= 112
      t = tramo(112, FIN)
      t2 = t * t
      dx = @propio ? -520 : 520
      dy = @propio ? 320 : -420
      @ball.x = (@bx + dx * t2).round
      @ball.y = (@by + dy * t2 - Math.sin(t * Math::PI) * 50).round
      @ball.angle = (@propio ? 1 : -1) * 540 * t2
      @ball.src_rect.x = ((f / 2) % 8) * 32
      @ball.opacity = 255 * (1 - tramo(128, FIN))
    end
    @f += 1
  end
end

class Battle::Scene
  alias ostdeb_pbFaintBattler pbFaintBattler
  def pbFaintBattler(battler)
    return ostdeb_pbFaintBattler(battler) if !OstCombate.activo?
    return ostdeb_pbFaintBattler(battler) if @battle.wildBattle? && battler.opposes?
    return ostdeb_pbFaintBattler(battler) if !@sprites["pokemon_#{battler.index}"]
    @briefMessage = false
    OstCamara.a_general_ya if defined?(OstCamara)
    anim = nil
    caja = nil
    begin
      anim = OstDebilitar.new(@sprites, @viewport, battler)
      caja = Animation::DataBoxDisappear.new(@sprites, @viewport, battler.index)
      loop do
        anim.update
        caja.update
        pbUpdate
        break if anim.done? && caja.animDone?
      end
    rescue StandardError => e
      # una animacion que falla no puede cortar el combate
      echoln("OstDebilitar: #{e.class}: #{e.message}")
      s = @sprites["pokemon_#{battler.index}"]
      s.visible = false if s && !s.disposed?
      @sprites["dataBox_#{battler.index}"].visible = false rescue nil
    ensure
      anim.dispose if anim
      caja.dispose if caja
    end
  end
end
