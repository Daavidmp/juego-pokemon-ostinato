#===============================================================================
# Pokemon Ostinato - Camaras de combate (al estilo de Pokemon X/Y)
#
#   El combate ya no es un plano fijo:
#     - el rival saca su Pokemon y la camara se acerca a el;
#     - al empezar, la pantalla se parte en dos vistas (tu Pokemon y el suyo,
#       de cerca, con un "VS" en medio);
#     - si pasan 15 s sin elegir ataque ni nada, la camara se mece despacio
#       entre los dos (como en X/Y); cualquier tecla la devuelve al general;
#     - el golpe sacude la camara y la empuja hacia el que lo recibe;
#     - el que se debilita, de cerca.
#   Antes de cada animacion de ataque vuelve al plano general (las
#   animaciones se colocan contando con el).
#
#   Como va: la camara solo mueve los sprites del escenario (fondo, Pokemon,
#   sombras y entrenadores) mientras se dibuja cada fotograma, y despues los
#   deja como estaban. El juego sigue viendo sus posiciones de siempre. La
#   interfaz (fichas, barra, mensajes) no se mueve.
#
#   Solo en el combate a 1920 (016_CombateHD).
#===============================================================================
module OstCamara
  CENTRO = [960, 540]
  VISIBLE_Y = 380             # el centro de lo que se ve por encima de la barra
  ESPERA = 15                 # segundos sin elegir hasta que la camara se mueve sola
  RIVAL_EN = [1000, 300]      # donde queda el rival en sus primeros planos
  PIES_Y = 770                # el borde de abajo del lado propio, nunca por encima
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
      # los pies del lado propio (el corte de abajo de su sprite de espaldas)
      # siguen escondidos tras la barra
      fy = [fy, OstCombate::PROPIO[1] - (PIES_Y - CENTRO[1]) / z].min if z > 1.0
      fx = [[fx, x0 + mx].max, x1 - mx].min if x1 - x0 >= 2 * mx
      fy = [[fy, y0 + my].max, y1 - my].min if y1 - y0 >= 2 * my
      return [fx, fy]
    end

    # Dibuja el fotograma con la camara puesta y devuelve todo a su sitio
    def dibujar
      return yield if !activa? || @bloqueo > 0
      begin
        avanzar
      rescue StandardError
        reiniciar
        return yield
      end
      return yield if neutra?
      z = @cam[2]
      fx, fy = limitar(@cam[0], @cam[1], z)
      dx = (@temblor > 0) ? (rand * 2 - 1) * @temblor : 0
      dy = (@temblor > 0) ? (rand * 2 - 1) * @temblor * 0.6 : 0
      guardados = []
      sprites.each do |k, s|
        next if !s || !k.is_a?(String) || k !~ MUNDO
        next if s.disposed?
        x = SX.bind(s).call; y = SY.bind(s).call
        zx = SZX.bind(s).call; zy = SZY.bind(s).call
        guardados.push([s, x, y, zx, zy])
        SXS.bind(s).call(((x - fx) * z + CENTRO[0] + dx).round)
        SYS.bind(s).call(((y - fy) * z + CENTRO[1] + dy).round)
        SZXS.bind(s).call(zx * z)
        SZYS.bind(s).call(zy * z)
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

    #---------------------------------------------------------------------------
    # La pantalla partida en dos: tu Pokemon a la izquierda, el suyo a la
    # derecha, de cerca, con una raya negra en diagonal y un VS en medio.
    #---------------------------------------------------------------------------
    def dividida(idx_propio, idx_rival)
      return if !activa?
      sp = sprites
      return if !sp["pokemon_#{idx_propio}"] || !sp["pokemon_#{idx_rival}"]
      z = 1.7
      vistas = []
      [[idx_propio, 0], [idx_rival, 960]].each do |idx, x0|
        vp = Viewport.new(x0 + (x0 == 0 ? -960 : 960), 0, 960, 1080)
        vp.z = 100500
        copias = []
        ["battle_bg", "shadow_#{idx}", "pokemon_#{idx}"].each do |k|
          o = sp[k]
          next if !o || o.disposed?
          copias.push([o, Sprite.new(vp)])
        end
        p = punto(idx)
        vistas.push([vp, copias, p, x0])
      end
      raya = Sprite.new
      raya.bitmap = raya_bitmap
      raya.z = 100510
      raya.ox = raya.bitmap.width / 2
      raya.x = 960
      raya.opacity = 0
      vs = Sprite.new
      vs.bitmap = Bitmap.new(200, 124)   # la letra no pasa de 96: se dibuja a 96 y se amplia
      OstCombate.fuente(vs.bitmap, 96)
      OstCombate.texto(vs.bitmap, 0, 0, 200, 124, "VS", 1, Color.new(255, 255, 255),
                       Color.new(10, 10, 10), 4)
      vs.ox = 100
      vs.oy = 62
      vs.x = 960
      vs.y = 470
      vs.angle = 8
      vs.z = 100520
      vs.opacity = 0
      destello = Sprite.new
      destello.bitmap = Bitmap.new(16, 16)
      destello.bitmap.fill_rect(0, 0, 16, 16, Color.new(255, 255, 255))
      destello.zoom_x = 120
      destello.zoom_y = 68
      destello.z = 100530
      destello.opacity = 0
      total = 104
      begin
        bloquear do
          total.times do |f|
            # entrar (0-10), quieto, salir (92-104)
            e = (f < 10) ? f / 10.0 : (f >= 92) ? 1 - (f - 92) / 12.0 : 1.0
            e = 1 - (1 - e) ** 3
            vistas.each do |vp, copias, p, x0|
              fuera = (x0 == 0) ? -960 : 960
              vp.rect.x = (x0 + fuera * (1 - e)).round
              # un empujon lento hacia dentro mientras esta quieto
              zz = z * (1 + 0.06 * [f - 10, 0].max / 82.0)
              cx, cy = p
              cy -= 60
              bg = sp["battle_bg"]
              if bg && !bg.disposed? && bg.bitmap
                bx0 = SX.bind(bg).call; by0 = SY.bind(bg).call
                bx1 = bx0 + bg.bitmap.width * SZX.bind(bg).call
                by1 = by0 + bg.bitmap.height * SZY.bind(bg).call
                cx = [[cx, bx0 + 480 / zz].max, bx1 - 480 / zz].min
                cy = [[cy, by0 + 540 / zz].max, by1 - 540 / zz].min
              end
              copias.each do |o, c|
                next if o.disposed?
                c.bitmap = o.bitmap
                c.src_rect = o.src_rect
                c.ox = o.ox
                c.oy = o.oy
                c.mirror = o.mirror
                c.opacity = o.opacity
                c.tone = o.tone
                c.color = o.color
                c.visible = o.visible
                c.x = ((SX.bind(o).call - cx) * zz + 480).round
                c.y = ((SY.bind(o).call - cy) * zz + 540).round
                c.zoom_x = SZX.bind(o).call * zz
                c.zoom_y = SZY.bind(o).call * zz
              end
            end
            raya.opacity = (f < 8) ? 0 : (f >= 92) ? 255 * (1 - (f - 92) / 12.0) : 255
            if f >= 10 && f < 92
              q = [(f - 10) / 6.0, 1.0].min
              vs.opacity = 255 * q
              s = 1.8 - 0.8 * (1 - (1 - q) ** 3)
              vs.zoom_x = vs.zoom_y = s * 2.2
            elsif f >= 92
              vs.opacity = 255 * (1 - (f - 92) / 8.0)
            end
            destello.opacity = (f >= 10 && f < 18) ? 200 * (1 - (f - 10) / 8.0) : 0
            @escena.pbUpdate
          end
        end
      ensure
        vistas.each do |vp, copias, _p, _x|
          copias.each { |_o, c| c.dispose }
          vp.dispose
        end
        [raya, vs, destello].each do |s|
          s.bitmap.dispose if s.bitmap && s != raya
          s.dispose
        end
      end
    end

    # la raya negra con filo blanco, en diagonal, tapando la junta del centro
    def raya_bitmap
      return @raya if @raya && !@raya.disposed?
      @raya = Bitmap.new(140, 1080)
      blanco = Color.new(255, 255, 255)
      negro = Color.new(10, 10, 10)
      1080.times do |y|
        xc = 70 + 24 - 48 * y / 1080.0
        @raya.fill_rect((xc - 44).round, y, 88, 1, blanco)
        @raya.fill_rect((xc - 36).round, y, 72, 1, negro)
      end
      return @raya
    end
  end
end

class << Graphics
  alias_method :ostcam_update, :update
  def update
    OstCamara.dibujar { ostcam_update }
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

  # Sacar Pokemon: el del rival, de cerca; al empezar, la pantalla partida
  alias ostcam_pbSendOutBattlers pbSendOutBattlers
  def pbSendOutBattlers(sendOuts, startBattle = false)
    return ostcam_pbSendOutBattlers(sendOuts, startBattle) if !OstCamara.activa? || sendOuts.empty?
    OstCamara.a_general_ya
    ostcam_pbSendOutBattlers(sendOuts, startBattle)
    if @battle.opposes?(sendOuts[0][0])
      OstCamara.a_pokemon(sendOuts[0][0], 1.45, 0.1)
      45.times { pbUpdate }
      OstCamara.general(0.1)
    elsif startBattle
      rival = @battle.battlers.find { |b| b && b.opposes?(sendOuts[0][0]) && !b.fainted? }
      OstCamara.a_general_ya
      begin
        OstCamara.dividida(sendOuts[0][0], rival.index) if rival
      rescue StandardError => e
        # una camara que falla no puede cortar el combate
        echoln("OstCamara: #{e.class}: #{e.message}")
      end
    else
      OstCamara.a_pokemon(sendOuts[0][0], 1.3, 0.1)
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
