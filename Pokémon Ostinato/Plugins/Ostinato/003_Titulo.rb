#===============================================================================
# Pokemon Ostinato - Pantalla de titulo
#
# Los botones son el dibujo a mano del propio menu.kra: seis placas de madera con
# cristales en los extremos, unidas por un hilo con esferitas. Cada pieza se
# recorto de la capa original y se reescalo a 1920x1080, asi que van colocadas
# exactamente donde estaban dibujadas sobre la escena.
#
# Sustituye a PokemonLoad_Scene (PokemonLoadScene en BES) manteniendo su contrato,
# asi que PokemonLoadScreen y los MenuHandlers de :load_screen siguen funcionando.
# (Migrado a La Base de Sky: ver Plugins/Ostinato/001_Compatibilidad.rb)
#
# Capas, de atras a delante:
#   0 fondo animado (400 fotogramas a 20 fps)
#   1 hilo, por tramos
#   2 esferitas parpadeando (luces de navidad), en aditivo
#   3 halo dorado de la placa elegida, en aditivo
#   4 placa apagada
#   5 placa encendida, que aparece por fundido al elegirla
#   6 titileo de los cristales y las letras, en aditivo
#===============================================================================
module OstinatoTitle
  FRAME_DIR   = "Graphics/Titles/OstinatoMenu/"
  FRAME_COUNT = 400
  FRAME_EXT   = ".jpg"
  FALLBACK    = "Graphics/Titles/OstinatoMenu_fallback"
  BTN_IMG     = "Graphics/Titles/OstBtn"
  THR_IMG     = "Graphics/Titles/OstThr"
  DOT_IMG     = "Graphics/Titles/OstDotGlow"

  HI_W = 1920
  HI_H = 1080

  BTN_W  = 568           # tamano del sprite de placa
  BTN_H  = 190
  BTN_CX = 693           # centro horizontal tal como esta dibujado
  BTN_OFF_X = -200       # desplazamiento de toda la pila hacia la izquierda
  BTN_GAP = 134          # separacion media entre placas
  # centro vertical de cada hueco, tal como estan dibujados
  BTN_CY = [206, 342, 474, 608, 743, 876]

  SEL_ZOOM = 1.035       # cuanto crece la elegida
  EASE     = 0.25

  BGM_NAME = "Nocturne of Lanterns"
  BGM_VOL  = 100

  # La cancion viene sonando desde el arranque (es el title_bgm del motor y a
  # Scene_Intro se le quito el corte), asi que aqui no se reinicia: solo se
  # arranca si otra pantalla, como los creditos, ha cambiado la musica.
  def self.bgm_playing?
    begin
      return false if !$game_system
      b = nil
      if $game_system.respond_to?("getPlayingBGM")
        b = $game_system.getPlayingBGM
      elsif $game_system.respond_to?("playing_bgm")
        b = $game_system.playing_bgm
      end
      return false if !b
      n = b.respond_to?("name") ? b.name : b.to_s
      return false if !n
      return n.include?(BGM_NAME)
    rescue
      return false
    end
  end

  def self.ensure_bgm
    return if bgm_playing?
    begin
      pbBGMPlay(BGM_NAME, BGM_VOL)
    rescue
    end
  end

  # Con menos de seis opciones la pila se acorta, asi que se baja media
  # separacion por cada hueco que falta y vuelve a quedar centrada en vertical.
  # El hilo y las esferitas se mueven lo mismo, para no descolocar el dibujo.
  def self.stack_dy(n)
    return 0.0 if n <= 0
    return (6 - n) * BTN_GAP * 0.5
  end

  # Tramos del hilo: [grupo, x, y]. El grupo g une el hueco g-1 con el g; el 0
  # es el remate de arriba y el 6 el de abajo.
  THREADS = [[0, 519,  96], [1, 396, 201], [2, 378, 318], [3, 449, 469],
             [4, 391, 603], [5, 396, 716], [6, 449, 870]]

  # Esferitas: [grupo, x, y] con el centro ya en coordenadas de pantalla.
  DOTS = [[0, 582, 107], [1, 986, 239], [1, 407, 314], [1, 957, 323],
          [2, 852, 405], [2, 389, 462], [3, 976, 528], [3, 1003, 558],
          [4, 976, 668], [4, 400, 712], [5, 448, 842], [6, 866, 947],
          [6, 747, 967]]

  # Con menos de seis opciones la pila se acorta por abajo, y con ella los
  # tramos de hilo que ya no unen dos placas.
  def self.group_visible?(g, n)
    return false if n <= 0        # sin placas no hay nada que unir
    return true if g == 0
    return n >= 6 if g == 6
    return g <= n - 1
  end

  # Cada boton se empareja con su placa por el nombre, asi aguanta cambios de
  # texto o de idioma sin tocar indices.
  def self.plaque_for(name)
    n = name.to_s.downcase
    return 0 if n.include?("nueva") || n.include?("partida")
    return 1 if n.include?("continu")
    return 2 if n.include?("logro")
    return 3 if n.include?("opci") || n.include?("configur")
    return 4 if n.include?("dito")
    return 5 if n.include?("salir")
    return -1
  end

  # Graphics.width puede ir un fotograma por detras tras un resize_screen, y
  # crear el viewport con el valor viejo recorta la escena a una esquina.
  def self.real_size
    w = Graphics.width
    h = Graphics.height
    begin
      b = Graphics.snap_to_bitmap
      if b
        w = b.width if b.width > 0
        h = b.height if b.height > 0
        b.dispose if !b.disposed?
      end
    rescue
    end
    return [w, h]
  end

  # Essentials multiplica zoom, x, y y el rect de los viewports por
  # $ResizeFactor (Sprite_Resizer). Aqui la resolucion se lleva a mano.
  def self.suspend_resizer
    begin
      $ostinato_rf  = $ResizeFactor
      $ostinato_rfm = $ResizeFactorMul
      $ostinato_rox = $ResizeOffsetX
      $ostinato_roy = $ResizeOffsetY
      $ResizeFactor = 1.0
      $ResizeFactorMul = 100
      $ResizeOffsetX = 0
      $ResizeOffsetY = 0
    rescue
    end
  end

  def self.resume_resizer
    begin
      $ResizeFactor    = $ostinato_rf  if $ostinato_rf
      $ResizeFactorMul = $ostinato_rfm if $ostinato_rfm
      $ResizeOffsetX   = $ostinato_rox if $ostinato_rox
      $ResizeOffsetY   = $ostinato_roy if $ostinato_roy
    rescue
    end
  end

  def self.raise_res
    begin
      $ostinato_prev = OstinatoHD.subir
    rescue
    end
  end

  def self.restore_res
    begin
      OstinatoHD.bajar($ostinato_prev)
      $ostinato_prev = nil
    rescue
    end
  end

  def self.at_low_res
    subida = !$ostinato_prev.nil?
    begin
      restore_res
      yield
    ensure
      raise_res if subida
    end
  end
end

#===============================================================================
class PokemonLoad_Scene
  def pbUpdate
    pbCheckResolution
    pbUpdateBackground
    @t = (@t || 0) + 1
    pbAnimateDots
    pbAnimatePlaques
    pbUpdateSpriteHash(@sprites) if @sprites
  end

  #-----------------------------------------------------------------------------
  # Fondo animado
  #-----------------------------------------------------------------------------
  def pbFramePath(i)
    return sprintf("%st%03d%s", OstinatoTitle::FRAME_DIR, i, OstinatoTitle::FRAME_EXT)
  end

  def pbLoadFrame(i)
    begin
      return Bitmap.new(pbFramePath(i))
    rescue
      return nil
    end
  end

  def pbSetupBackground
    @frame = 0
    @tick = 0
    @animated = false
    bmp = pbLoadFrame(0)
    if bmp
      @animated = true
    else
      name = (pbResolveBitmap(OstinatoTitle::FALLBACK) rescue nil)
      bmp = Bitmap.new(name) if name
    end
    @sprites["bg"] = Sprite.new(@viewport)
    @sprites["bg"].z = 0
    if bmp
      @sprites["bg"].bitmap = bmp
    else
      b = Bitmap.new(@gw, @gh)
      b.fill_rect(0, 0, @gw, @gh, Color.new(29, 34, 54))
      @sprites["bg"].bitmap = b
    end
    pbFitBackground
  end

  def pbFitBackground
    s = @sprites["bg"]
    return if !s || !s.bitmap || s.bitmap.disposed?
    return if s.bitmap.width <= 0 || s.bitmap.height <= 0
    s.zoom_x = @gw.to_f / s.bitmap.width
    s.zoom_y = @gh.to_f / s.bitmap.height
  end

  def pbUpdateBackground
    return if !@animated || !@sprites || !@sprites["bg"]
    step = (Graphics.frame_rate >= 60) ? 3 : 2
    @tick += 1
    return if @tick < step
    @tick = 0
    @frame = (@frame + 1) % OstinatoTitle::FRAME_COUNT
    nb = pbLoadFrame(@frame)
    return if !nb
    old = @sprites["bg"].bitmap
    @sprites["bg"].bitmap = nb
    old.dispose if old && !old.disposed?
    pbFitBackground
  end

  #-----------------------------------------------------------------------------
  # Hilo y esferitas
  #-----------------------------------------------------------------------------
  def pbSetupThread
    n = (@commands ? @commands.length : 6)
    sx = @gw.to_f / OstinatoTitle::HI_W
    sy = @gh.to_f / OstinatoTitle::HI_H
    dy = OstinatoTitle.stack_dy(n)
    ox = OstinatoTitle::BTN_OFF_X
    for i in 0...OstinatoTitle::THREADS.length
      d = OstinatoTitle::THREADS[i]
      next if !OstinatoTitle.group_visible?(d[0], n)
      nm = (pbResolveBitmap(OstinatoTitle::THR_IMG + d[0].to_s) rescue nil)
      next if !nm
      sp = Sprite.new(@viewport)
      begin
        sp.bitmap = Bitmap.new(nm)
        sp.x = ((d[1] + ox) * sx).round
        sp.y = ((d[2] + dy) * sy).round
        sp.zoom_x = sx
        sp.zoom_y = sy
        sp.z = 1
        @sprites["thr#{i}"] = sp
      rescue
        sp.dispose
      end
    end
    @dotPhase = []
    @dotRate = []
    dm = (pbResolveBitmap(OstinatoTitle::DOT_IMG) rescue nil)
    return if !dm
    begin
      @dotBmp = Bitmap.new(dm)
    rescue
      @dotBmp = nil
      return
    end
    k = 0
    for i in 0...OstinatoTitle::DOTS.length
      d = OstinatoTitle::DOTS[i]
      next if !OstinatoTitle.group_visible?(d[0], n)
      sp = Sprite.new(@viewport)
      sp.bitmap = @dotBmp
      sp.ox = @dotBmp.width / 2
      sp.oy = @dotBmp.height / 2
      sp.x = ((d[1] + ox) * sx).round
      sp.y = ((d[2] + dy) * sy).round
      sp.z = 2
      sp.blend_type = 1
      @sprites["dot#{k}"] = sp
      # cada luz con su fase y su ritmo, para que no parpadeen a la vez
      @dotPhase[k] = (i * 1.31) % 6.2831853
      @dotRate[k] = 0.048 + ((i * 7) % 11) * 0.0065
      k += 1
    end
    @dotBase = sy
  end

  def pbAnimateDots
    return if !@dotPhase || @dotPhase.length == 0
    for i in 0...@dotPhase.length
      sp = @sprites["dot#{i}"]
      next if !sp || sp.disposed?
      v = Math.sin(@t * @dotRate[i] + @dotPhase[i])
      # curva mordida: pasan mas tiempo encendidas que apagadas, y nunca a cero
      f = 0.5 + 0.5 * v
      f = f * f * (3.0 - 2.0 * f)
      sp.opacity = (76 + 179 * f).to_i
      z = (@dotBase || 1.0) * (0.80 + 0.34 * f)
      sp.zoom_x = z
      sp.zoom_y = z
    end
  end

  #-----------------------------------------------------------------------------
  # Placas
  #-----------------------------------------------------------------------------
  def pbSetupPlaques
    n = @commands.length
    @np = n
    sx = @gw.to_f / OstinatoTitle::HI_W
    sy = @gh.to_f / OstinatoTitle::HI_H
    @baseZ = sy
    @pz = []
    @glow = []
    @flash = 0.0
    @lastIndex = -1
    dy = OstinatoTitle.stack_dy(n)
    cx = ((OstinatoTitle::BTN_CX + OstinatoTitle::BTN_OFF_X) * sx).round
    for i in 0...n
      key = OstinatoTitle.plaque_for(@commands[i])
      key = i % 6 if key < 0
      cy = ((OstinatoTitle::BTN_CY[[i, 5].min] + dy) * sy).round
      pbMakePlaqueSprite("plq#{i}", OstinatoTitle::BTN_IMG + key.to_s,       cx, cy, 4, 0, 255)
      pbMakePlaqueSprite("hal#{i}", OstinatoTitle::BTN_IMG + key.to_s + "h", cx, cy, 3, 1, 0)
      pbMakePlaqueSprite("sel#{i}", OstinatoTitle::BTN_IMG + key.to_s + "s", cx, cy, 5, 0, 0)
      pbMakePlaqueSprite("cry#{i}", OstinatoTitle::BTN_IMG + key.to_s + "c", cx, cy, 6, 1, 0)
      @pz[i] = sy
      @glow[i] = 0.0
    end
  end

  def pbMakePlaqueSprite(key, img, cx, cy, z, blend, opacity)
    nm = (pbResolveBitmap(img) rescue nil)
    return if !nm
    sp = Sprite.new(@viewport)
    begin
      sp.bitmap = Bitmap.new(nm)
      sp.ox = sp.bitmap.width / 2
      sp.oy = sp.bitmap.height / 2
      sp.x = cx
      sp.y = cy
      sp.z = z
      sp.blend_type = blend
      sp.opacity = opacity
      sp.zoom_x = @baseZ
      sp.zoom_y = @baseZ
      @sprites[key] = sp
    rescue
      sp.dispose
    end
  end

  def pbAnimatePlaques
    return if !@pz || !@np
    sy = @baseZ || 1.0
    if @lastIndex != @index
      @lastIndex = @index
      @flash = 1.0
    end
    @flash *= 0.90
    for i in 0...@np
      sel = (i == @index)
      want = sel ? sy * OstinatoTitle::SEL_ZOOM : sy
      @pz[i] += (want - @pz[i]) * OstinatoTitle::EASE
      tgt = sel ? 1.0 : 0.0
      @glow[i] += (tgt - @glow[i]) * OstinatoTitle::EASE
      g = @glow[i]
      # el halo late despacio; los cristales titilan mas rapido
      pulse = 0.84 + 0.16 * Math.sin(@t * 0.075)
      twink = 0.55 + 0.45 * (0.5 + 0.5 * Math.sin(@t * 0.115 + 0.7))
      a = @sprites["plq#{i}"]
      if a && !a.disposed?
        a.zoom_x = @pz[i]
        a.zoom_y = @pz[i]
        a.opacity = 235
      end
      b = @sprites["sel#{i}"]
      if b && !b.disposed?
        b.zoom_x = @pz[i]
        b.zoom_y = @pz[i]
        b.opacity = (255 * g).to_i
      end
      c = @sprites["hal#{i}"]
      if c && !c.disposed?
        c.zoom_x = @pz[i]
        c.zoom_y = @pz[i]
        c.opacity = (216 * g * pulse).to_i
      end
      d = @sprites["cry#{i}"]
      next if !d || d.disposed?
      d.zoom_x = @pz[i]
      d.zoom_y = @pz[i]
      v = 108 * g * twink + 70 * g * @flash
      v = 255 if v > 255
      d.opacity = v.to_i
    end
  end

  #-----------------------------------------------------------------------------
  def pbCheckResolution
    return if !@sprites || !@gw
    sz = OstinatoTitle.real_size
    return if sz[0] == @gw && sz[1] == @gh
    @gw = sz[0]
    @gh = sz[1]
    begin
      @viewport.rect = Rect.new(0, 0, @gw, @gh)
    rescue
    end
    pbDisposeUI
    pbSetupThread
    pbSetupPlaques if @commands && @commands.length > 0
    pbFitBackground
  end

  def pbDisposeUI
    return if !@sprites
    for k in @sprites.keys
      next if k[/\A(plq|sel|hal|cry|dot|thr)/].nil?
      s = @sprites[k]
      @sprites.delete(k)
      next if !s || s.disposed?
      # las esferitas comparten un unico bitmap; ese se libera aparte
      if k[/\A(plq|sel|hal|cry|thr)/] && s.bitmap && !s.bitmap.disposed?
        s.bitmap.dispose
      end
      s.dispose
    end
    @dotPhase = []
    @np = nil
  end

  def pbFreeShared
    @dotBmp.dispose if @dotBmp && !@dotBmp.disposed?
    @dotBmp = nil
  end

  #-----------------------------------------------------------------------------
  # Contrato que espera PokemonLoad
  #-----------------------------------------------------------------------------
  def pbStartScene(commands, showContinue, trainer, stats, mapid)
    @commands = commands
    @showContinue = showContinue
    @index = 0
    @t = 0
    @sprites = {}
    OstinatoTitle.ensure_bgm
    OstinatoTitle.suspend_resizer
    OstinatoTitle.raise_res
    begin
      Graphics.update
    rescue
    end
    sz = OstinatoTitle.real_size
    @gw = sz[0]
    @gh = sz[1]
    @viewport = Viewport.new(0, 0, @gw, @gh)
    @viewport.z = 99998
    pbSetupBackground
    pbSetupThread
    pbSetupPlaques
  end

  def pbStartScene2
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbStartDeleteScene
    @commands = []
    @showContinue = false
    @index = 0
    @t = 0
    @sprites = {}
    OstinatoTitle.ensure_bgm
    OstinatoTitle.suspend_resizer
    OstinatoTitle.raise_res
    begin
      Graphics.update
    rescue
    end
    sz = OstinatoTitle.real_size
    @gw = sz[0]
    @gh = sz[1]
    @viewport = Viewport.new(0, 0, @gw, @gh)
    @viewport.z = 99998
    pbSetupBackground
    pbSetupThread
  end

  def pbSetParty(trainer); end

  def pbChoose(commands)
    if !@np || @np != commands.length
      @commands = commands
      @index = 0
      pbDisposeUI
      pbSetupThread
      pbSetupPlaques
    end
    @index = 0 if !@index || @index >= commands.length
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::UP)
        @index = (@index - 1 + @np) % @np
        pbPlayCursorSE rescue nil
      elsif Input.trigger?(Input::DOWN)
        @index = (@index + 1) % @np
        pbPlayCursorSE rescue nil
      elsif Input.trigger?(Input::C)
        pbPlayDecisionSE rescue nil
        return @index
      end
    end
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeUI
    pbDisposeSpriteHash(@sprites)
    pbFreeShared
    @viewport.dispose
    OstinatoTitle.restore_res
    OstinatoTitle.resume_resizer
  end

  def pbCloseScene
    pbDisposeUI
    pbDisposeSpriteHash(@sprites)
    pbFreeShared
    @viewport.dispose
    OstinatoTitle.restore_res
    OstinatoTitle.resume_resizer
  end
end

#===============================================================================
# Pantalla de logros (aun vacia, lista para rellenar)
#===============================================================================
class OstinatoAchievementsScene
  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @sprites["bg"] = Sprite.new(@viewport)
    b = Bitmap.new(Graphics.width, Graphics.height)
    b.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(29, 34, 54))
    begin
      b.font.name = "Georgia"
    rescue
      pbSetSystemFont(b)
    end
    b.font.size = [(Graphics.height * 24) / 384, 14].max
    pbDrawShadowText(b, 0, (Graphics.height * 10) / 100, Graphics.width, 40,
                     _INTL("LOGROS"), Color.new(247, 236, 208), Color.new(52, 36, 24), 1)
    pbDrawShadowText(b, 0, Graphics.height / 2 - 20, Graphics.width, 40,
                     _INTL("Aún no hay logros disponibles."),
                     Color.new(214, 202, 176), Color.new(52, 36, 24), 1)
    pbDrawShadowText(b, 0, Graphics.height - 60, Graphics.width, 40,
                     _INTL("Pulsa B para volver"),
                     Color.new(170, 158, 136), Color.new(52, 36, 24), 1)
    @sprites["bg"].bitmap = b
  end

  def pbScene
    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
      break if Input.trigger?(Input::B) || Input.trigger?(Input::C)
    end
  end

  def pbEndScene
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

def pbOstinatoAchievements
  scene = OstinatoAchievementsScene.new
  scene.pbStartScene
  scene.pbScene
  scene.pbEndScene
end

#===============================================================================
# Botones: nombres y orden, igual que en el dibujo
#===============================================================================
MenuHandlers.add(:load_screen, :continue, {
  "name"      => _INTL("Continuar"),
  "order"     => 20,
  "condition" => proc { |screen| next screen.showContinue },
  "effect"    => proc { |screen|
    screen.scene.pbEndScene
    Game.load(screen.save_data)
    next :exit
  }
})

MenuHandlers.add(:load_screen, :achievements, {
  "name"  => _INTL("Logros"),
  "order" => 30,
  "effect" => proc { |screen|
    pbFadeOutIn(99999) { pbOstinatoAchievements }
    next false
  }
})

MenuHandlers.add(:load_screen, :options, {
  "name"  => _INTL("Configuración"),
  "order" => 40,
  "effect" => proc { |screen|
    pbFadeOutIn(99999) {
      OstinatoTitle.at_low_res {
        begin
          if Settings::USE_NEW_OPTIONS_UI
            UI::Options.new(true).main
          else
            scene = PokemonOption_Scene.new
            optscreen = PokemonOptionScreen.new(scene)
            optscreen.pbStartScreen(true)
          end
        rescue
        end
      }
    }
    next false
  }
})

MenuHandlers.add(:load_screen, :credits, {
  "name"  => _INTL("Créditos"),
  "order" => 50,
  "effect" => proc { |screen|
    pbFadeOutIn(99999) {
      OstinatoTitle.at_low_res {
        old_scene = $scene
        begin
          sc = Scene_Credits.new
          $scene = sc
          sc.main
        rescue
        ensure
          $scene = old_scene
        end
      }
    }
    OstinatoTitle.ensure_bgm   # los creditos cambian la musica
    next false
  }
})

MenuHandlers.add(:load_screen, :quit, {
  "name"  => _INTL("Salir"),
  "order" => 60,
  "effect" => proc { |screen|
    screen.scene.pbEndScene
    $scene = nil
    next :exit
  }
})

# Fuera del menu pedido, sin borrar su codigo
MenuHandlers.add(:load_screen, :mystery_gift, {
  "name" => _INTL("Regalo Misterioso"), "order" => 70,
  "condition" => proc { |screen| next false }
})
MenuHandlers.add(:load_screen, :language, {
  "name" => _INTL("Idioma"), "order" => 80,
  "condition" => proc { |screen| next false }
})
