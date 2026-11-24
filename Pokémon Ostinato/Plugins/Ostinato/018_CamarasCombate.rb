#===============================================================================
# Pokemon Ostinato - Camaras de combate (al estilo de Pokemon X/Y)
#
#   El combate ya no es un plano fijo:
#     - el rival saca su Pokemon y la camara se acerca a el;
#     - si pasan 15 s sin elegir ataque ni nada, la camara se mece despacio
#       entre los dos (como en X/Y); cualquier tecla la devuelve al general;
#     - el golpe sacude la camara y la empuja hacia el que lo recibe;
#     - el que se debilita, de cerca.
#   Antes de cada animacion de ataque vuelve al plano general (las
#   animaciones se colocan contando con el).
#   Kaia y tu Pokemon nunca suben de su sitio: sus pies (el corte de abajo
#   de sus sprites de espaldas) siguen siempre pegados al borde de abajo de
#   la pantalla; la camara solo los acerca (crecen hacia arriba) o los mueve
#   de lado.
#
#   Como va: la camara solo mueve los sprites del escenario (fondo, Pokemon,
#   sombras y entrenadores) mientras se dibuja cada fotograma, y despues los
#   deja como estaban. El juego sigue viendo sus posiciones de siempre. La
#   interfaz (fichas, botones, mensajes) no se mueve.
#
#   Solo en el combate a 1920 (016_CombateHD).
#===============================================================================
module OstCamara
  CENTRO = [960, 540]
  VISIBLE_Y = 540             # el centro de lo que se ve (sin barra abajo: la pantalla entera)
  ESPERA = 15                 # segundos sin elegir hasta que la camara se mueve sola
  RIVAL_EN = [1000, 300]      # donde queda el rival en sus primeros planos
  SUELO = OstCombate::ALTO    # el borde de abajo de la pantalla (ahi va el corte de tus Pokemon)
  MUNDO = /\A(battle_bg2?|pokemon_\d+|shadow_\d+|player_\d+|trainer_\d+)\z/

  # metodos de Sprite sin pasar por los de 016 (los Pokemon fingen zoom 1)
  SX  = ::Sprite.instance_method(:x)
  SY  = ::Sprite.instance_method(:y)
  SZX = ::Sprite.instance_method(:zoom_x)
  SZY = ::Sprite.instance_method(:zoom_y)
  SXS  = ::Sprite.instance_method(:x=)
  SYS  = ::Sprite.instance_method(:y=)
  SZXS = ::Sprite.instance_method(:zoom_x=)
  SZYS = ::Sprite.instance_method(:zoom_y=)

  @escena = nil
  @cam = [960.0, 540.0, 1.0]      # punto del mundo en el centro, zoom
  @meta = [960.0, 540.0, 1.0]
  @vel = 0.12
  @temblor = 0.0
  @mecer = false
  @bloqueo = 0

  class << self
    attr_accessor :escena
    attr_accessor :extras

    def activa?
      return @escena && OstCombate.activo? && !@escena.instance_variable_get(:@disposed)
    end

    def sprites
      return (@escena) ? @escena.instance_variable_get(:@sprites) : nil
    end

    def general(vel = 0.12)
      @mecer = false
      apuntar(CENTRO[0], CENTRO[1], 1.0, vel)
    end

    # zoom sobre un punto del mundo, dejandolo a la altura de lo visible
    def apuntar(x, y, z, vel = 0.12)
      @meta = [x.to_f, y.to_f + (CENTRO[1] - VISIBLE_Y) / z, z.to_f]
      @vel = vel
    end

    # el centro del dibujo de un Pokemon (en el mundo)
    def punto(idx)
      s = sprites && sprites["pokemon_#{idx}"]
      return (idx.even? ? OstCombate::PROPIO : OstCombate::RIVAL) if !s || s.disposed?
      c = getSpriteCenter(s) rescue [SX.bind(s).call, SY.bind(s).call]
      return c
    end

    # el rival, arriba en el centro (lejos de las dos fichas); el propio, a
    # la altura de lo visible
    def a_pokemon(idx, z, vel = 0.12)
      @mecer = false
      p = punto(idx)
      if idx.odd?
        @meta = [p[0] - (RIVAL_EN[0] - CENTRO[0]) / z.to_f, p[1] - (RIVAL_EN[1] - CENTRO[1]) / z.to_f, z.to_f]
        @vel = vel
      else
        apuntar(p[0], p[1], z, vel)
      end
    end

    # lo dibujado de verdad de un Pokemon (sin el margen transparente de su
    # cuadro), en el mundo: [izquierda, derecha, arriba, abajo]
    def caja(idx)
      s = sprites && sprites["pokemon_#{idx}"]
      return nil if !s || s.disposed? || !s.bitmap || s.bitmap.disposed?
      b = s.bitmap; r = s.src_rect
      @cajas ||= {}
      clave = [b.object_id, r.x, r.y, r.width, r.height]
      c = @cajas[clave]
      if !c
        x0 = r.width; x1 = -1; y0 = r.height; y1 = -1
        (0...r.height).step(2) do |y|
          (0...r.width).step(2) do |x|
            next if b.get_pixel(r.x + x, r.y + y).alpha < 40
            x0 = x if x < x0; x1 = x if x > x1; y0 = y if y < y0; y1 = y if y > y1
          end
        end
        c = (x1 < 0) ? [0, r.width, 0, r.height] : [x0, x1 + 2, y0, y1 + 2]
        @cajas.clear if @cajas.length > 64
        @cajas[clave] = c
      end
      zx = SZX.bind(s).call; zy = SZY.bind(s).call
      bx = SX.bind(s).call - s.ox * zx
      by = SY.bind(s).call - s.oy * zy
      bx, c0, c1 = s.mirror ? [bx, r.width - c[1], r.width - c[0]] : [bx, c[0], c[1]]
      return [bx + c0 * zx, bx + c1 * zx, by + c[2] * zy, by + c[3] * zy]
    end

    # varios Pokemon a la vez (los dos de un doble): centrados en la pantalla y
    # con el mismo margen a cada lado (por los bordes de sus dibujos, no por sus
    # centros), con el zoom justo para que quepan (como mucho z, el de uno solo)
    MARGEN = 520                # las fichas de vida llegan a x 470: asi no se pegan a ellas
    def a_pokemon_varios(idxs, z, vel = 0.12)
      return a_pokemon(idxs[0], z, vel) if idxs.length < 2
      @mecer = false
      l = nil; r = nil; ys = []
      idxs.each do |i|
        k = caja(i)
        if !k
          c = punto(i)
          k = [c[0] - 120, c[0] + 120, c[1] - 120, c[1] + 120]
        end
        l = [l || k[0], k[0]].min
        r = [r || k[1], k[1]].max
        ys.push((k[2] + k[3]) / 2.0)
      end
      z = [z.to_f, (1920.0 - 2 * MARGEN) / (r - l)].min
      z = [z, 1.0].max
      mx = (l + r) / 2.0
      my = ys.sum / ys.length.to_f
      if idxs[0].odd?
        @meta = [mx, my - (RIVAL_EN[1] - CENTRO[1]) / z, z]
        @vel = vel
      else
        apuntar(mx, my, z, vel)
      end
    end

    # mientras eliges: si pasan ESPERA segundos sin hacer nada, se mece
    # despacio entre los dos lados; cualquier tecla la devuelve al general
    def mecer(idx)
      @mecer = false
      @espera = [idx, System.uptime]
    end

    def sin_espera
      @espera = nil
      general(0.08)
    end

    def esperando
      return if !@espera
      if Input.dir4 != 0 || Input.press?(Input::USE) || Input.press?(Input::BACK)
        @espera[1] = System.uptime
        general(0.1) if @mecer
        return
      end
      return if @mecer || System.uptime - @espera[1] < ESPERA
      @mecer = @espera[0]
      @vel = 0.02
    end

    def sacudir(fuerza = 14)
      @temblor = fuerza.to_f
    end

    # vuelve al plano general y espera a estar en el (para las animaciones)
    def a_general_ya
      return if !activa?
      general(0.25)
      12.times do
        break if neutra?
        @escena.pbUpdate
      end
      @cam = [CENTRO[0].to_f, CENTRO[1].to_f, 1.0]
      @temblor = 0
    end

    def neutra?
      return (@cam[2] - 1.0).abs < 0.004 && (@cam[0] - CENTRO[0]).abs < 2 &&
             (@cam[1] - CENTRO[1]).abs < 2 && @temblor < 0.5
    end

    def bloquear
      @bloqueo += 1
      yield
    ensure
      @bloqueo -= 1
    end

    def reiniciar
      @cam = [CENTRO[0].to_f, CENTRO[1].to_f, 1.0]
      @meta = @cam.clone
      @temblor = 0
      @mecer = false
      @bloqueo = 0
    end

    # un paso de la camara (cada fotograma)
    def avanzar
      esperando
      if @mecer
        p0 = punto(@mecer)
        p1 = punto(@mecer ^ 1)
        t = (Math.sin(System.uptime * 0.5) + 1) / 2          # ~12 s ida y vuelta
        x = p0[0] + (p1[0] - p0[0]) * (0.25 + 0.35 * t)
        y = p0[1] + (p1[1] - p0[1]) * (0.25 + 0.35 * t)
        z = 1.10 + 0.04 * Math.sin(System.uptime * 0.37)
        @meta = [x, y + (CENTRO[1] - VISIBLE_Y) / z, z]
      end
      3.times { |i| @cam[i] += (@meta[i] - @cam[i]) * @vel }
      @temblor *= 0.86
      @temblor = 0 if @temblor < 0.3
    end

    # El borde de abajo del dibujo de un sprite, en la pantalla (sin camara)
    def fondo(s)
      return SY.bind(s).call + (s.src_rect.height - s.oy) * SZY.bind(s).call
    end

    # El borde de abajo (el corte) mas alto de los sprites del lado propio
    # -sus Pokemon y Kaia-, en reposo
    def corte_propio(claves = nil)
      ys = []
      sprites.each do |k, s|
        next if !k.is_a?(String) || !s
        next if claves ? !claves.include?(k) : k !~ /\A(pokemon_\d*[02468]|player_\d+)\z/
        next if s.disposed? || !s.bitmap || s.bitmap.disposed?
        next if !claves && !s.visible
        b = s.instance_variable_get(:@ost_reposo_fondo)
        ys.push(b || fondo(s))
      end
      return ys.min || OstCombate::PROPIO[1]
    end

    # que el fondo siga tapando la pantalla con el zoom
    def limitar(fx, fy, z)
      bg = sprites["battle_bg"]
      return [fx, fy] if !bg || bg.disposed? || !bg.bitmap
      x0 = SX.bind(bg).call
      y0 = SY.bind(bg).call
      x1 = x0 + bg.bitmap.width * SZX.bind(bg).call
      y1 = y0 + bg.bitmap.height * SZY.bind(bg).call
      mx = CENTRO[0] / z
      my = CENTRO[1] / z
      fx = [[fx, x0 + mx].max, x1 - mx].min if x1 - x0 >= 2 * mx
      fy = [[fy, y0 + my].max, y1 - my].min if y1 - y0 >= 2 * my
      # lo ultimo y por encima de todo: los pies del lado propio (Kaia y su
      # Pokemon) nunca suben de su sitio; siguen pegados al borde de abajo.
      # Con zoom crecen hacia arriba desde ellos, y como mucho bajan.
      c = corte_propio
      fy = [fy, c - (c - CENTRO[1]) / z].min
      return [fx, fy]
    end

    # Dibuja el fotograma con la camara puesta y devuelve todo a su sitio
    #   Ademas, siempre (tambien durante los ataques): el Pokemon propio nunca
    #   se dibuja mas arriba de su sitio. Su sprite de espaldas acaba cortado
    #   y ese corte va pegado al borde de abajo; si una animacion lo subia, se
    #   veia partido por la mitad.
    def dibujar
      return yield if !activa?
      camara = false
      if @bloqueo == 0
        begin
          avanzar
          camara = !neutra?
        rescue StandardError
          reiniciar
        end
      end
      guardados = []
      begin
        if camara
          z = @cam[2]
          fx, fy = limitar(@cam[0], @cam[1], z)
          dx = (@temblor > 0) ? (rand * 2 - 1) * @temblor : 0
          dy = (@temblor > 0) ? rand * @temblor * 0.6 : 0   # solo hacia abajo: nada sube
        end
        sprites.each do |k, s|
          next if !s || !k.is_a?(String) || k !~ MUNDO
          next if s.disposed?
          x = SX.bind(s).call; y = SY.bind(s).call
          ny = y
          # comparando su borde de abajo (las animaciones le cambian el origen)
          if k =~ /\Apokemon_\d*[02468]\z/ &&(reposo = s.instance_variable_get(:@ost_reposo_fondo))
            sube = reposo - fondo(s)
            ny = y + sube if sube > 0
          end
          next if !camara && ny == y
          zx = SZX.bind(s).call; zy = SZY.bind(s).call
          guardados.push([s, x, y, zx, zy])
          if camara
            SXS.bind(s).call(((x - fx) * z + CENTRO[0] + dx).round)
            SYS.bind(s).call(((ny - fy) * z + CENTRO[1] + dy).round)
            SZXS.bind(s).call(zx * z)
            SZYS.bind(s).call(zy * z)
          else
            SYS.bind(s).call(ny)
          end
        end
        # piezas que no estan en la escena pero viven en el mundo (la megaevolucion)
        if camara && @extras
          @extras.each do |s|
            next if !s || s.disposed?
            x = SX.bind(s).call; y = SY.bind(s).call
            zx = SZX.bind(s).call; zy = SZY.bind(s).call
            guardados.push([s, x, y, zx, zy])
            SXS.bind(s).call(((x - fx) * z + CENTRO[0] + dx).round)
            SYS.bind(s).call(((y - fy) * z + CENTRO[1] + dy).round)
            SZXS.bind(s).call(zx * z)
            SZYS.bind(s).call(zy * z)
          end
        end
      rescue StandardError
        # una camara que falla no rompe el dibujo: todo a su sitio y plano general
        guardados.each do |s, x, y, zx, zy|
          next if s.disposed?
          SXS.bind(s).call(x); SYS.bind(s).call(y)
          SZXS.bind(s).call(zx); SZYS.bind(s).call(zy)
        end
        guardados = []
        reiniciar
      end
      begin
        return yield
      ensure
        guardados.each do |s, x, y, zx, zy|
          next if s.disposed?
          SXS.bind(s).call(x); SYS.bind(s).call(y)
          SZXS.bind(s).call(zx); SZYS.bind(s).call(zy)
        end
      end
    end
  end
end

class << Graphics
  alias_method :ostcam_update, :update
  def update
    OstCamara.dibujar { ostcam_update }
  end
end

# Donde descansa cada Pokemon (lo que la v21 llama y no guarda: @spriteY
# sigue a las animaciones)
class Battle::Scene::BattlerSprite
  alias ostcam_pbSetPosition pbSetPosition
  def pbSetPosition
    ostcam_pbSetPosition
    @ost_reposo_fondo = OstCamara.fondo(self) if OstCombate.activo? && @_iconBitmap
  end
end

class Battle::Scene
  alias ostcam_pbStartBattle pbStartBattle
  def pbStartBattle(battle)
    OstCamara.reiniciar
    OstCamara.escena = self
    ostcam_pbStartBattle(battle)
  end

  alias ostcam_pbEndBattle pbEndBattle
  def pbEndBattle(result)
    OstCamara.general(0.3)
    ret = ostcam_pbEndBattle(result)
    OstCamara.escena = nil
    OstCamara.reiniciar
    return ret
  end

  # Sacar Pokemon: el del rival, de cerca (en un doble, los dos)
  alias ostcam_pbSendOutBattlers pbSendOutBattlers
  def pbSendOutBattlers(sendOuts, startBattle = false)
    return ostcam_pbSendOutBattlers(sendOuts, startBattle) if !OstCamara.activa? || sendOuts.empty?
    OstCamara.a_general_ya
    ostcam_pbSendOutBattlers(sendOuts, startBattle)
    if @battle.opposes?(sendOuts[0][0])
      OstCamara.a_pokemon_varios(sendOuts.map { |s| s[0] }, 1.45, (sendOuts.length > 1) ? 0.18 : 0.1)
      45.times { pbUpdate }
      OstCamara.general(0.1)
    elsif startBattle
      # al empezar, ya en el plano general (sin pantalla partida ni VS)
      OstCamara.a_general_ya
    else
      OstCamara.a_pokemon_varios(sendOuts.map { |s| s[0] }, 1.3, 0.1)
      30.times { pbUpdate }
      OstCamara.general(0.1)
    end
  end

  alias ostcam_pbCommandMenu pbCommandMenu
  def pbCommandMenu(idxBattler, firstAction, &block)
    OstCamara.mecer(idxBattler) if OstCamara.activa?
    ret = ostcam_pbCommandMenu(idxBattler, firstAction, &block)
    OstCamara.sin_espera if OstCamara.activa?
    return ret
  end

  alias ostcam_pbFightMenu pbFightMenu
  def pbFightMenu(idxBattler, megaEvoPossible = false, &block)
    OstCamara.mecer(idxBattler) if OstCamara.activa?
    ret = ostcam_pbFightMenu(idxBattler, megaEvoPossible, &block)
    OstCamara.sin_espera if OstCamara.activa?
    return ret
  end

  # Las animaciones de ataque, siempre en plano general
  alias ostcam_pbAnimationCore pbAnimationCore
  def pbAnimationCore(animation, user, target, oppMove = false)
    return ostcam_pbAnimationCore(animation, user, target, oppMove) if !OstCamara.activa? || !animation
    OstCamara.a_general_ya
    OstCamara.bloquear { ostcam_pbAnimationCore(animation, user, target, oppMove) }
  end

  # El golpe: sacudida y empujon hacia el que lo recibe
  alias ostcam_pbHitAndHPLossAnimation pbHitAndHPLossAnimation
  def pbHitAndHPLossAnimation(targets)
    if OstCamara.activa? && targets && targets[0]
      OstCamara.a_pokemon(targets[0][0].index, 1.12, 0.2)
      OstCamara.sacudir(16)
    end
    ostcam_pbHitAndHPLossAnimation(targets)
    OstCamara.general(0.07) if OstCamara.activa?
  end

  alias ostcam_pbFaintBattler pbFaintBattler
  def pbFaintBattler(battler)
    OstCamara.a_pokemon(battler.index, 1.25, 0.1) if OstCamara.activa?
    ostcam_pbFaintBattler(battler)
    OstCamara.general(0.08) if OstCamara.activa?
  end
end
