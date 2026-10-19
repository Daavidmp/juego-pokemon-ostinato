#===============================================================================
# Pokemon Ostinato - Debilitarse un Pokemon salvaje: cae y se apaga
#
#   Los de entrenador vuelven a su ball (019). Los salvajes no tienen ball:
#     - suena su grito grave y da una sacudida corta hacia atras;
#     - se le doblan las patas y cae con peso: se aplasta contra el suelo, da
#       un rebote pequeno y la sombra se ensancha al tocar el suelo (los que
#       vuelan, en vez de doblar las patas, aletean un poco y caen dando tumbos);
#     - se queda gris y se deshace de abajo arriba en motas de polvo que suben
#       y se apagan (del color de su dibujo, en cuadritos como los pixeles);
#     - solo queda la sombra, que se encoge y desaparece.
#   Solo en el combate a 1920 (016_CombateHD).
#===============================================================================
class OstDebilitarSalvaje
  FIN    = 150
  CAIDA  = 46              # fotograma en que toca el suelo
  GRIS   = 64              # empieza a ponerse gris
  CORTE  = [76, 128]       # se deshace entre estos dos fotogramas
  MOTAS  = 90              # motas como mucho a la vez
  VIDA   = [34, 56]        # fotogramas que dura cada mota

  SX  = ::Sprite.instance_method(:x)
  SY  = ::Sprite.instance_method(:y)
  SZX = ::Sprite.instance_method(:zoom_x)
  SZY = ::Sprite.instance_method(:zoom_y)
  SZXS = ::Sprite.instance_method(:zoom_x=)
  SZYS = ::Sprite.instance_method(:zoom_y=)

  def initialize(sprites, viewport, battler)
    @vp = viewport
    @poke = sprites["pokemon_#{battler.index}"]
    @sombra = sprites["shadow_#{battler.index}"]
    @pkmn = (@poke.respond_to?(:pkmn) && @poke.pkmn) || battler.pokemon
    @vuela = vuela?
    @f = 0
    # como esta ahora (en crudo, sin el zoom fingido de 016)
    @x0 = SX.bind(@poke).call
    @y0 = SY.bind(@poke).call
    @zx0 = SZX.bind(@poke).call
    @zy0 = SZY.bind(@poke).call
    if @sombra && !@sombra.disposed?
      @szx0 = SZX.bind(@sombra).call
      @szy0 = SZY.bind(@sombra).call
      @sop0 = @sombra.opacity
    end
    @copia = nil
    @motas = []
    @mota_bm = {}
  end

  def done?; return @f > FIN; end

  def dispose
    @motas.each { |m| m[0].dispose if !m[0].disposed? }
    @mota_bm.each_value { |b| b.dispose if !b.disposed? }
    if @copia
      @copia.bitmap.dispose if @copia.bitmap && !@copia.bitmap.disposed?
      @copia.dispose if !@copia.disposed?
    end
    if @poke && !@poke.disposed?
      @poke.visible = false
      @poke.x = @x0; @poke.y = @y0
      SZXS.bind(@poke).call(@zx0); SZYS.bind(@poke).call(@zy0)
      @poke.angle = 0
      @poke.opacity = 255
      @poke.tone = Tone.new(0, 0, 0, 0)
      @poke.color = Color.new(0, 0, 0, 0)
    end
    if @sombra && !@sombra.disposed?
      @sombra.visible = false
      SZXS.bind(@sombra).call(@szx0) if @szx0
      SZYS.bind(@sombra).call(@szy0) if @szy0
      @sombra.opacity = @sop0 if @sop0
    end
  end

  #-----------------------------------------------------------------------------
  def vuela?
    return false if !@pkmn
    # en los metrics de Ostinato no hay altitudes: se mira el tipo y Levitacion
    return @pkmn.hasType?(:FLYING) || @pkmn.hasAbility?(:LEVITATE)
  rescue
    return false
  end

  def suave(t); t = [[t, 0.0].max, 1.0].min; return 1 - (1 - t) ** 3; end
  def tramo(a, b); return [[(@f - a) / (b - a).to_f, 0.0].max, 1.0].min; end
  def se(n, v = 100, p = 100); pbSEPlay(n, v, p) rescue nil; end

  # el Pokemon, desplazado y deformado respecto a como estaba (anclado por los pies)
  def poner(dx, dy, ex, ey, angulo = 0)
    @poke.x = (@x0 + dx).round        # los de BattlerSprite: update los vuelve a poner
    @poke.y = (@y0 + dy).round
    SZXS.bind(@poke).call(@zx0 * ex)
    SZYS.bind(@poke).call(@zy0 * ey)
    @poke.angle = angulo
  end

  def sombra(ancho, opacidad)
    return if !@sombra || @sombra.disposed? || !@szx0
    SZXS.bind(@sombra).call(@szx0 * ancho)
    SZYS.bind(@sombra).call(@szy0 * [ancho, 1.0].min)
    @sombra.opacity = @sop0 * opacidad
  end

  def update
    return if done?
    f = @f
    if f == 0
      begin
        GameData::Species.play_cry_from_pokemon(@pkmn, 90, 75)
      rescue
      end
    end
    # 1) la sacudida del golpe: hacia atras (lejos de tu Pokemon) y vuelta
    if f < 14
      t = tramo(0, 14)
      atras = Math.sin(t * Math::PI) * 26
      poner(atras, -atras * 0.35, 1, 1)
      @poke.color = Color.new(255, 255, 255, 120 * (1 - t))
    # 2) se le doblan las patas (o aletea por ultima vez) y cae
    elsif f < CAIDA
      if @vuela
        t = tramo(14, CAIDA)
        sube = (t < 0.35) ? -40 * suave(t / 0.35) : -40 * (1 - ((t - 0.35) / 0.65) ** 2)
        poner(Math.sin(f * 0.5) * 6 * (1 - t), sube, 1, 1, 22 * t * Math.sin(f * 0.35))
      else
        t = tramo(14, 30)
        cae = tramo(30, CAIDA)
        poner(0, 0, 1 + 0.05 * suave(t), 1 - 0.14 * suave(t) - 0.02 * cae, 0)
      end
      sombra(1 + 0.1 * tramo(30, CAIDA), 1)
    # 3) toca el suelo: se aplasta, rebota un poco y se asienta
    elsif f < GRIS
      if f == CAIDA
        se("Pkmn faint", 80, 90)
        se("Battle damage weak", 55, 70)
        OstCamara.sacudir(6) rescue nil
      end
      t = tramo(CAIDA, GRIS)
      rebote = Math.sin(t * Math::PI) * 14 * (1 - t)
      aplasta = Math.exp(-t * 4) * Math.cos(t * Math::PI * 2.2)
      poner(0, -rebote, 1.06 + 0.16 * aplasta, 0.84 - 0.24 * aplasta, 0)
      sombra(1.1 + 0.3 * Math.exp(-t * 5), 1)
    # 4) se queda gris y se deshace en polvo de abajo arriba
    else
      poner(0, 0, 1.06, 0.84, 0) if f == GRIS
      g = tramo(GRIS, CORTE[0])
      gris = Tone.new(-50 * g, -50 * g, -40 * g, 255 * g)
      @poke.tone = gris
      @copia.tone = gris if @copia
      deshacer if f >= CORTE[0]
      sombra(1.1 * (1 - suave(tramo(CORTE[1] - 20, FIN - 6))), 1 - tramo(CORTE[1] - 10, FIN - 6))
    end
    mover_motas
    @f += 1
  end

  #-----------------------------------------------------------------------------
  # Una copia quieta del dibujo (el de 016 cambia de cuadro y de rectangulo al
  # actualizarse), recortada desde abajo; de la linea del corte salen las motas.
  def deshacer
    if !@copia
      bm = @poke.bitmap
      return if !bm || bm.disposed?
      @copia = Sprite.new(@vp)
      @copia.bitmap = bm.clone
      @copia.ox = @poke.ox; @copia.oy = @poke.oy
      @copia.x = SX.bind(@poke).call; @copia.y = SY.bind(@poke).call
      @copia.zoom_x = SZX.bind(@poke).call; @copia.zoom_y = SZY.bind(@poke).call
      @copia.z = @poke.z
      @copia.tone = @poke.tone
      @caja = OstCombate.caja(@copia.bitmap)
      @src = @poke.src_rect.clone
      @copia.src_rect = @src.clone
      @poke.visible = false
    end
    t = tramo(*CORTE)
    x0, y0, x1, y1 = @caja
    linea = (y1 + 1 - (y1 + 1 - y0) * (t ** 0.85)).round
    r = @copia.src_rect
    r.set(@src.x, @src.y, @src.width, [linea - @src.y, 0].max)
    @copia.src_rect = r
    @copia.visible = linea > y0
    return if linea <= y0 || linea > y1 + 1
    # motas de la fila que se acaba de ir
    26.times do
      break if @motas.length >= MOTAS
      bx = x0 + rand(x1 - x0 + 1)
      by = [linea + rand(4), y1].min
      c = @copia.bitmap.get_pixel(bx, by)
      next if c.alpha < 60
      sx = @copia.x + (bx - @src.x - @copia.ox) * @copia.zoom_x
      sy = @copia.y + (by - @src.y - @copia.oy) * @copia.zoom_y
      nueva_mota(sx, sy, c)
    end
  end

  # cuadradito de color (apagado, como el gris del cuerpo)
  def mota_bitmap(c)
    k = ((c.red * 0.3 + c.green * 0.59 + c.blue * 0.11) * 0.55 + 40).round.clamp(0, 255)
    r = ((c.red * 0.35 + k * 0.65) / 16).round * 16
    g = ((c.green * 0.35 + k * 0.65) / 16).round * 16
    b = ((c.blue * 0.35 + k * 0.65 + 6) / 16).round * 16
    clave = [r, g, b]
    return @mota_bm[clave] if @mota_bm[clave]
    bm = Bitmap.new(2, 2)
    bm.fill_rect(0, 0, 2, 2, Color.new(r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255)))
    @mota_bm[clave] = bm
    return bm
  end

  def nueva_mota(x, y, c)
    s = Sprite.new(@vp)
    s.bitmap = mota_bitmap(c)
    s.ox = s.oy = 1
    tam = [@copia.zoom_x, 1].max * (rand(3) == 0 ? 1.0 : 0.67)
    s.zoom_x = s.zoom_y = tam
    s.x = x; s.y = y
    s.z = @copia.z + 1
    vida = VIDA[0] + rand(VIDA[1] - VIDA[0])
    # [sprite, x, y, vx, vy, edad, vida, fase]
    @motas.push([s, x.to_f, y.to_f, rand * 1.2 - 0.6, -(0.6 + rand * 1.6), 0, vida, rand * 6.28])
  end

  def mover_motas
    @motas.reject! do |m|
      s = m[0]
      m[5] += 1
      m[1] += m[3] + Math.sin(m[7] + m[5] * 0.12) * 0.5
      m[2] += m[4]
      m[4] *= 0.985                       # frenan al subir, como polvo
      s.x = m[1].round; s.y = m[2].round
      t = m[5] / m[6].to_f
      s.opacity = 255 * (t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85))
      if m[5] >= m[6]
        s.dispose
        next true
      end
      next false
    end
  end
end

class Battle::Scene
  alias ostdebsal_pbFaintBattler pbFaintBattler
  def pbFaintBattler(battler)
    return ostdebsal_pbFaintBattler(battler) if !OstCombate.activo?
    return ostdebsal_pbFaintBattler(battler) if !@battle.wildBattle? || !battler.opposes?
    return ostdebsal_pbFaintBattler(battler) if defined?(OstJefe) && OstJefe.activo?
    return ostdebsal_pbFaintBattler(battler) if !@sprites["pokemon_#{battler.index}"]
    @briefMessage = false
    OstCamara.a_general_ya if defined?(OstCamara)
    anim = nil
    caja = nil
    begin
      anim = OstDebilitarSalvaje.new(@sprites, @viewport, battler)
      caja = Animation::DataBoxDisappear.new(@sprites, @viewport, battler.index)
      loop do
        anim.update
        caja.update
        pbUpdate
        break if anim.done? && caja.animDone?
      end
    rescue StandardError => e
      # una animacion que falla no puede cortar el combate
      echoln("OstDebilitarSalvaje: #{e.class}: #{e.message}")
      s = @sprites["pokemon_#{battler.index}"]
      s.visible = false if s && !s.disposed?
      @sprites["dataBox_#{battler.index}"].visible = false rescue nil
    ensure
      anim.dispose if anim
      caja.dispose if caja
    end
  end
end
