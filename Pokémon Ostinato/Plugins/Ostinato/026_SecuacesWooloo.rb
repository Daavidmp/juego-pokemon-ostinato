#===============================================================================
# Pokemon Ostinato - Villa Bambalina: los secuaces, el Silenciador y el Wooloo
#
#   Despues de la obra (SW 83) y de Tacet (SW 91), al acercarse Kaia a la
#   fuente de la plaza (mapa 12) dos secuaces estan molestando a un Wooloo.
#   Kaia les dice que paren; se rien, prueban el invento de la jefa (el
#   Silenciador) con el Wooloo, que se oscurece y se vuelve agresivo, y se van.
#   Sale "ENTER CALMAR" junto al Wooloo: con Enter, combate de jefe.
#
#   El combate de jefe (OstJefe): al empezar se ve al Wooloo normal y en
#   pantalla se oscurece (onda del aparato, aura, tinte morado, temblor, grito
#   distorsionado); despues sube todas sus caracteristicas +2. Su ficha es la
#   barra de jefe de arriba (Graphics/UI/Ostinato/Jefe/barra_jefe.png). No se
#   puede huir ni capturar. Si se gana, el Wooloo se calma y se une al equipo;
#   si se pierde, se cura el equipo y se puede volver a intentar.
#
#   Eventos del mapa 12 (por nombre): "SecuazChico", "SecuazChica",
#   "WoolooSilenciado". Interruptores: 92 = escena vista (los secuaces ya no
#   estan y el Wooloo sigue oscuro), 93 = Wooloo calmado y en el equipo.
#   Textos: recursos/guion_secuaces_wooloo.txt (SecTxt). Musica: Audio/BGM
#   Secuaces y Combate silenciado; SE Silenciador encendido/onda.
#===============================================================================
module OstSecuaces
  MAPA       = 12
  SW_OBRA    = 83
  SW_TACET   = 91
  SW_ESCENA  = 92
  SW_CALMADO = 93
  NIVEL      = 9
  KAIA_EN    = [29, 16]              # donde se para Kaia, mirando a la fuente
  SALIDA     = [40, 12]              # por donde se van los secuaces
  DIR_JEFE   = "Graphics/UI/Ostinato/Jefe/"
  CARTEL     = "Graphics/Titles/BamCalmar.png"

  ARTES = {
    "izq"  => ["DlgSecChico.png", 40, 465, "DlgNomSecuaz"],
    "izq2" => ["DlgSecChica.png", 174, 465, "DlgNomSecuaz"],
    "der"  => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }

  def self.en_mapa?; return $game_map && $game_map.map_id == MAPA; end
  def self.chico; return OstMapa.evento("SecuazChico"); end
  def self.chica; return OstMapa.evento("SecuazChica"); end
  def self.wooloo; return OstMapa.evento("WoolooSilenciado"); end

  # lo oscuro que esta el Wooloo del mapa (0 normal, 1 del todo)
  def self.oscuro; return @oscuro || 0.0; end
  def self.oscuro=(v); @oscuro = v; end

  def self.t(i, lado); return ["SecTxt%02d" % i, lado]; end

  #--- cuando toca ------------------------------------------------------------
  def self.toca_escena?
    return false if !en_mapa? || $game_switches[SW_ESCENA] || !$game_switches[SW_OBRA]
    w = wooloo
    return false if !w || !chico
    return (($game_player.x - w.x).abs + ($game_player.y - w.y).abs) <= 4
  end

  def self.puede_calmar?
    return false if !en_mapa? || !$game_switches[SW_ESCENA] || $game_switches[SW_CALMADO]
    w = wooloo
    return false if !w
    dx = (w.x - $game_player.x).abs; dy = (w.y - $game_player.y).abs
    return false if dx + dy != 1
    # Kaia tiene que estar mirandolo
    fx = $game_player.x + ($game_player.direction == 6 ? 1 : ($game_player.direction == 4 ? -1 : 0))
    fy = $game_player.y + ($game_player.direction == 2 ? 1 : ($game_player.direction == 8 ? -1 : 0))
    return fx == w.x && fy == w.y
  end

  def self.comprobar
    return if @corriendo || !$game_map || !$game_player
    @oscuro = ($game_switches[SW_ESCENA] && !$game_switches[SW_CALMADO]) ? 1.0 : 0.0 if !@en_escena
    calmar = puede_calmar? && !$game_player.moving?
    cartel(calmar)
    return if $game_player.moving?
    return if $game_temp && ($game_temp.message_window_showing || $game_temp.player_transferring || $game_temp.in_battle)
    que = nil
    que = :escena if toca_escena?
    que = :calmar if !que && calmar && Input.trigger?(Input::USE)
    return if !que
    @corriendo = true
    begin
      que == :escena ? escena : combate
    rescue StandardError => e
      echoln("OstSecuaces: #{e.class}: #{e.message}\n#{e.backtrace[0, 5].join("\n")}") rescue nil
    ensure
      @corriendo = false
      @en_escena = false
    end
  end

  #--- ENTER CALMAR junto al Wooloo -------------------------------------------
  def self.cartel(ver)
    if !ver
      OstDlg.soltar(@cartel) if @cartel
      @cartel = nil
      return
    end
    if !@cartel || @cartel.disposed?
      vp = (Spriteset_Map.viewport rescue nil)
      return if !vp
      @cartel = Sprite.new(vp)
      @cartel.bitmap = OstDlg.bmp(CARTEL)
      return if !@cartel.bitmap
      @cartel.z = 2000
    end
    return if !@cartel.bitmap
    w = @cartel.bitmap.width / 3
    cuadro = (Graphics.frame_count / 30) % 2
    @cartel.src_rect = Rect.new(cuadro * w, 0, w, @cartel.bitmap.height)
    @cartel.x = $game_player.screen_x - w / 2
    @cartel.y = $game_player.screen_y - 64 - @cartel.bitmap.height
  end

  #--- efectos sobre el mapa --------------------------------------------------
  def self.vp_mapa; return (Spriteset_Map.viewport rescue nil); end

  def self.tira(ruta, cuadros)
    vp = vp_mapa
    return nil if !vp
    s = Sprite.new(vp)
    s.bitmap = OstMini.bmp(ruta)
    return nil if !s.bitmap
    w = s.bitmap.width / cuadros
    s.ox = w / 2; s.oy = s.bitmap.height / 2
    s.src_rect = Rect.new(0, 0, w, s.bitmap.height)
    s.z = 900
    return s
  end

  def self.cuadro(s, i, cuadros)
    return if !s || s.disposed?
    w = s.bitmap.width / cuadros
    s.src_rect = Rect.new(i * w, 0, w, s.bitmap.height)
  end

  def self.esperar(seg); OstDlg.esperar(seg); end

  # el aparato se enciende, suelta la onda y el Wooloo se va oscureciendo
  def self.silenciar
    c = chica; w = wooloo
    ap = tira(DIR_JEFE + "aparato.png", 4)
    if ap && c
      ap.zoom_x = ap.zoom_y = 2
      ap.x = c.screen_x + 32; ap.y = c.screen_y + 32 - 26     # en el suelo, en la casilla libre de su lado
    end
    OstMini.se("Silenciador encendido", nil, 90)
    20.times { |k| cuadro(ap, k < 10 ? 0 : 1, 4); OstDlg.tick }
    40.times { |k| cuadro(ap, 2 + (k / 6) % 2, 4); OstDlg.tick }
    # la onda, del aparato al Wooloo
    onda = tira(DIR_JEFE + "onda.png", 4)
    OstMini.se("Silenciador onda", nil, 95)
    if onda && w
      40.times do |k|
        f = k / 40.0
        onda.x = ap.x + (w.screen_x - ap.x) * f
        onda.y = ap.y + (w.screen_y - 24 - ap.y) * f
        cuadro(onda, [k / 10, 3].min, 4)
        onda.zoom_x = onda.zoom_y = 1.0 + f * 1.5
        onda.opacity = 255 - [k - 28, 0].max * 20
        OstDlg.tick
      end
    end
    OstDlg.soltar(onda) if onda
    begin; $game_screen.start_shake(4, 8, 30); rescue; end
    # se oscurece poco a poco, temblando
    @en_escena = true
    90.times do |k|
      @oscuro = k / 90.0
      cuadro(ap, 2 + (k / 5) % 2, 4)
      if w && k % 20 == 0
        w.instance_variable_set(:@x_offset_temblor, 0)
      end
      OstDlg.tick
    end
    @oscuro = 1.0
    begin; pbSEPlay("Cries/WOOLOO", 90, 55); rescue; end
    begin; $game_screen.start_flash(Color.new(60, 0, 90, 160), 20); rescue; end
    esperar(0.6)
    OstDlg.soltar(ap) if ap
  end

  #--- la escena --------------------------------------------------------------
  def self.escena
    @en_escena = true
    @oscuro = 0.0
    sonaba = false
    begin
      $game_system.bgm_memorize
      pbBGMPlay("Secuaces", 80)
      sonaba = true
    rescue
    end
    # Kaia se acerca hasta delante del Wooloo
    pasos = OstMapa.camino($game_player, KAIA_EN[0], KAIA_EN[1]) || []
    OstinatoLaboratorio.mover($game_player, pasos) if pasos.length > 0
    $game_player.turn_up
    esperar(0.3)
    a = chico; b = chica; w = wooloo
    OstMapa.mirarse(a, w) if a && w
    OstMapa.mirarse(b, w) if b && w
    # le dan la lata
    OstDlg.run([t(0, "izq"), t(1, "izq2"), t(2, "izq")], ARTES)
    begin; pbSEPlay("Cries/WOOLOO", 70, 120); rescue; end
    w.jump(0, 0) rescue nil
    esperar(0.5)
    OstDlg.run([t(3, "der")], ARTES)
    OstMapa.mirarse(a, $game_player) if a
    OstMapa.mirarse(b, $game_player) if b
    OstDlg.run([t(4, "izq2"), t(5, "izq"), t(6, "izq2"), t(7, "izq2"), t(8, "izq"), t(9, "izq2")], ARTES)
    OstMapa.mirarse(b, w) if b && w
    silenciar
    OstDlg.run([t(10, "izq"), t(11, "izq2"), t(12, "izq")], ARTES)
    # se van riendose
    [a, b].each_with_index do |e, i|
      next if !e
      e.through = true
      pasos = OstMapa.camino(e, SALIDA[0], SALIDA[1] + i) || []
      e.move_speed = 4 rescue nil
      begin; pbMoveRoute(e, pasos); rescue; end
    end
    n = 0
    while [a, b].any? { |e| e && e.move_route_forcing } && n < 600
      OstDlg.tick; n += 1
    end
    [a, b].each { |e| OstMapa.quitar(e) if e }
    $game_switches[SW_ESCENA] = true
    $game_map.need_refresh = true
    if sonaba
      begin; $game_system.bgm_restore; rescue; end
    end
    esperar(0.4)
    OstDlg.run([t(13, "der")], ARTES)
    @oscuro = 1.0
  end

  #--- el combate ---------------------------------------------------------------
  def self.combate
    cartel(false)
    pk = Pokemon.new(:WOOLOO, NIVEL)
    ganado = false
    OstJefe.activo = true
    begin
      setBattleRule("canLose")
      setBattleRule("cannotRun")
      setBattleRule("disablePokeBalls")
      setBattleRule("backdrop", "bambalina")
      $PokemonGlobal.nextBattleBGM = "Combate silenciado"
      ganado = WildBattle.start(pk)
    rescue StandardError => e
      echoln("OstSecuaces: el combate no ha podido empezar: #{e.message}") rescue nil
    ensure
      OstJefe.activo = false
    end
    OstDlg.esperar(0.3)
    if ganado
      calmado
    else
      begin; $player.heal_party; rescue; end
      OstDlg.run([t(16, "der")], ARTES)
    end
  end

  # el Wooloo vuelve a su color y se une al equipo
  def self.calmado
    @en_escena = true
    @oscuro = 0.0              # ya se calmo en el combate (OstJefe.calmar)
    begin; pbSEPlay("Cries/WOOLOO", 85, 100); rescue; end
    wooloo.jump(0, 0) rescue nil
    esperar(0.6)
    OstDlg.run([t(14, "der"), t(15, "der"), t(18, "der")], ARTES)
    nuevo = Pokemon.new(:WOOLOO, NIVEL)
    begin
      pbAddPokemonSilent(nuevo)
    rescue
      $player.party.push(nuevo) if $player.party.length < Settings::MAX_PARTY_SIZE
    end
    begin; pbMEPlay("Pkmn get"); rescue; end
    OstDlg.run([t(17, "cap")], {})
    OstMapa.quitar(wooloo)
    $game_switches[SW_CALMADO] = true
    $game_map.need_refresh = true
  end
end

# el Wooloo del mapa se ve oscuro mientras esta silenciado
class Sprite_Character
  alias ostsec_update update
  def update
    ostsec_update
    ch = @character
    return if !ch.is_a?(Game_Event) || ch.name != "WoolooSilenciado"
    f = OstSecuaces.oscuro
    self.tone.set(-55 * f, -85 * f, -10 * f, 90 * f)
    self.color.set(90, 10, 120, (35 + 25 * Math.sin(Graphics.frame_count / 8.0)) * f)
    self.x += (rand(3) - 1) if f > 0.3 && Graphics.frame_count % 3 == 0
  end
end

class Scene_Map
  alias ostsec_update update
  def update
    ostsec_update
    OstSecuaces.comprobar
  end
end

#===============================================================================
# El combate de jefe
#===============================================================================
module OstJefe
  DIR = "Graphics/UI/Ostinato/Jefe/"
  BAJAR = 110
  STATS = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
  def self.activo?; return @activo; end
  def self.activo=(v); @activo = v; @hecho = false; @f = 0.0; end
  def self.oscuro; return @f || 0.0; end

  # sprites propios dentro de la escena del combate
  # el aura va en los sprites de la escena con nombre de "mundo" (shadow_8..11):
  # asi la camara de combate (018) la mueve y la amplia junto con el Pokemon
  def self.montar(scene)
    vp = scene.instance_variable_get(:@viewport)
    sps = scene.instance_variable_get(:@sprites)
    @aura = []
    4.times do |i|
      s = Sprite.new(vp); s.bitmap = OstMini.bmp(DIR + "aura#{i}.png")
      s.ox = 256; s.oy = 470; s.opacity = 0; s.visible = false
      @aura.push(s)
      sps["shadow_#{8 + i}"] = s if sps
    end
    @onda = Sprite.new(vp); @onda.bitmap = OstMini.bmp(DIR + "onda.png"); @onda.opacity = 0
    @onda.ox = 32; @onda.oy = 32; @onda.src_rect = Rect.new(0, 0, 64, 64)
  end

  def self.soltar
    (@aura || []).each { |s| begin; s.dispose if !s.disposed?; rescue; end }
    begin; @onda.dispose if @onda; rescue; end
    @aura = nil; @onda = nil
  end

  # cada fotograma del combate: el Wooloo y el fondo con lo oscuro que toque
  def self.tick(scene)
    return if !@aura
    sp = scene.sprites["pokemon_1"] rescue nil
    f = oscuro
    if sp && !sp.disposed?
      # bucle sin cortes: 0-1-2-1-0... fundiendo cada cuadro con el siguiente
      orden = [0, 1, 2, 1]
      t = System.uptime * 5.0
      fase = t - t.floor
      ka = orden[t.floor % 4]; kb = orden[(t.floor + 1) % 4]
      vaiven = Math.sin(System.uptime * 2.3)
      ancho = (sp.src_rect.width * OstCamara::SZX.bind(sp).call).abs
      pies = OstCamara::SY.bind(sp).call + (sp.src_rect.height - sp.oy) * OstCamara::SZY.bind(sp).call
      @aura.each_with_index do |a, i|
        next if a.disposed?
        peso = (i == ka ? 1.0 - fase : 0.0) + (i == kb ? fase : 0.0)
        a.visible = peso > 0.01 && f > 0.02 && sp.visible && sp.opacity > 0
        a.x = OstCamara::SX.bind(sp).call
        a.y = pies + 10
        a.z = [sp.z - 1, 0].max
        base = [ancho * 1.35 / 512.0, 0.25].max
        a.zoom_x = base * (1.0 + 0.04 * vaiven)
        a.zoom_y = base * (1.0 + 0.06 * Math.sin(System.uptime * 3.1 + 1.0))
        a.opacity = 170 * f * peso
      end
    end
    bg = scene.sprites["battle_bg"] rescue nil
    bg.tone.set(-45 * f, -55 * f, -15 * f, 40 * f) if bg && !bg.disposed?
  end

  def self.pulso=(v); @pulso = v; end
  def self.tinte(sprite)
    f = oscuro
    @pulso = (@pulso || 0) * 0.92
    return if f <= 0 && @pulso < 0.01
    sprite.tone.set(-75 * f, -85 * f, -45 * f, 0)
    sprite.color.set(110, 20, 150, (18 + 14 * Math.sin(Graphics.frame_count / 6.0)) * f + 110 * @pulso)
  end

  def self.esperar(scene, seg)
    (seg * 60).round.times { scene.pbUpdate }
  end

  # la transformacion, al empezar el combate
  def self.transformar(battle)
    return if @hecho
    @hecho = true
    scene = battle.scene
    montar(scene)
    @f = 0.0
    sp = scene.sprites["pokemon_1"]
    vp = scene.instance_variable_get(:@viewport)
    b = battle.battlers[1]
    esperar(scene, 0.6)
    begin; pbSEPlay("Cries/WOOLOO", 80, 100); rescue; end
    esperar(scene, 0.8)
    # la onda del Silenciador llega desde fuera de la pantalla
    cx, cy = getSpriteCenter(sp)
    OstMini.se("Silenciador onda", nil, 100)
    50.times do |k|
      fr = k / 50.0
      @onda.x = -100 + (cx + 100) * fr; @onda.y = cy + 200 * (1 - fr)
      @onda.src_rect = Rect.new([k / 12, 3].min * 64, 0, 64, 64)
      @onda.zoom_x = @onda.zoom_y = 3 + fr * 6
      @onda.opacity = 255
      @onda.z = sp.z + 5
      scene.pbUpdate
    end
    @onda.opacity = 0
    # se oscurece temblando, con el grito cada vez mas grave
    ox0 = vp.ox; oy0 = vp.oy
    150.times do |k|
      @f = OstMini.suave(k / 150.0)
      vp.ox = ox0 + (rand(2 + (8 * @f).round) - (1 + 4 * @f).round)
      vp.oy = oy0 + (rand(2 + (6 * @f).round) - (1 + 3 * @f).round)
      begin; pbSEPlay("Cries/WOOLOO", 60, 100 - (50 * @f).round); rescue; end if k == 50 || k == 100
      OstJefe.pulso = 1.0 if k % 30 == 0
      scene.pbUpdate
    end
    vp.ox = ox0; vp.oy = oy0
    @f = 1.0
    begin; pbSEPlay("Cries/WOOLOO", 100, 45); rescue; end
    OstJefe.pulso = 1.0
    esperar(scene, 0.6)
    battle.pbDisplay(_INTL("¡El Wooloo se ha vuelto agresivo!"))
    # todas sus caracteristicas +2
    STATS.each { |s| b.stages[s] = 2 if b.stages.key?(s) }
    begin; battle.pbCommonAnimation("StatUp", b); rescue; end
    battle.pbDisplay(_INTL("¡Todas sus características han subido mucho!"))
  end
end

class Battle
  alias ostjefe_pbBattleLoop pbBattleLoop
  def pbBattleLoop
    if OstJefe.activo?
      begin
        OstJefe.transformar(self)
      rescue StandardError => e
        echoln("OstJefe: #{e.class}: #{e.message}") rescue nil
      end
    end
    ostjefe_pbBattleLoop
  ensure
    OstJefe.soltar if OstJefe.activo?
  end
end

class Battle::Scene
  alias ostjefe_pbFrameUpdate pbFrameUpdate
  def pbFrameUpdate(cw = nil)
    ostjefe_pbFrameUpdate(cw)
    OstJefe.tick(self) if OstJefe.activo?
  end
end

class Battle::Scene::BattlerSprite
  alias ostjefe_update update
  def update(*args)
    ostjefe_update(*args)
    OstJefe.tinte(self) if OstJefe.activo? && @index && @index.odd?
  end
end

# la ficha del rival es la barra de jefe, arriba del todo
class Battle::Scene::PokemonDataBox
  OST_JEFE = { :pos => [55, 4], :fondo => "../Jefe/barra_jefe",
               :nombre => [490, 66, 1100, 84], :nivel => [120, 66, 320, 84],
               :nivel_texto => "Lv.%d", :nivel_alin => 1,
               :vida => [350, 164, 1255, 30], :estado => [130, 150] }
  alias ostjefe_ost_datos ost_datos
  def ost_datos
    return OST_JEFE if OstJefe.activo? && @battler && @battler.index.odd?
    return ostjefe_ost_datos
  end
end

# en el combate de jefe el Wooloo baja un poco: pisa el suelo de la plaza y la
# barra de arriba no le tapa la cabeza
class Battle::Scene
  class << self
    alias ostjefe_pbBattlerPosition pbBattlerPosition
    def pbBattlerPosition(index, sideSize = 1)
      ret = ostjefe_pbBattlerPosition(index, sideSize)
      if OstJefe.activo? && index.odd?
        ret = ret.dup
        ret[1] += OstJefe::BAJAR
      end
      return ret
    end
  end
end

#===============================================================================
# Al dejarlo sin vida el Wooloo no se debilita: cae un haz de luz calida, suben
# motas de luz, el aura y lo oscuro se van aclarando hasta su color de siempre,
# sale un anillo de luz de el y bala con su voz normal.
# Arte en Graphics/UI/Ostinato/Jefe/ (haz_luz, motas_luz, anillo_luz; se suman
# a la imagen: su negro no se ve). Sonido: Audio/SE "Luz calma".
# Prompts: recursos/prompts_wooloo_calma.txt
#===============================================================================
module OstJefe
  HAZ_POZO = [384, 1250]       # el centro del charco de luz dentro de haz_luz.png
  MOTA = 72                    # cada mota de motas_luz.png (6 seguidas)

  def self.calmar(scene, battler)
    sps = scene.sprites
    vp = scene.instance_variable_get(:@viewport)
    sp = sps["pokemon_#{battler.index}"]
    return if !sp || sp.disposed?
    OstCamara.a_general_ya if defined?(OstCamara)
    @pulso = 0
    begin; pbBGMFade(1.5); rescue; end
    begin; pbSEPlay("Luz calma", 100); rescue; end
    w = Graphics.width; h = Graphics.height
    cx, cy = getSpriteCenter(sp)
    pies = sp.y + (sp.src_rect.height - sp.oy) * sp.zoom_y
    ancho = sp.src_rect.width * sp.zoom_x
    alto = pies - cy
    cosas = []
    velo = Sprite.new(vp); cosas.push(velo)
    velo.bitmap = Bitmap.new(w, h); velo.bitmap.fill_rect(0, 0, w, h, Color.new(0, 0, 0))
    velo.z = [sp.z - 2, 0].max; velo.opacity = 0
    haz = Sprite.new(vp); cosas.push(haz)
    haz.bitmap = OstMini.bmp(DIR + "haz_luz.png")
    haz.blend_type = 1; haz.z = sp.z + 1; haz.opacity = 0
    haz.ox = HAZ_POZO[0]; haz.oy = HAZ_POZO[1]
    haz.x = cx; haz.y = pies
    haz.zoom_x = haz.zoom_y = (pies + 120) / HAZ_POZO[1].to_f
    haz.src_rect = Rect.new(0, 0, haz.bitmap.width, 0)
    anillo = Sprite.new(vp); cosas.push(anillo)
    anillo.bitmap = OstMini.bmp(DIR + "anillo_luz.png")
    anillo.blend_type = 1; anillo.z = sp.z + 2; anillo.opacity = 0
    anillo.ox = anillo.bitmap.width / 2; anillo.oy = anillo.bitmap.height / 2
    anillo.x = cx; anillo.y = cy
    motas_b = OstMini.bmp(DIR + "motas_luz.png")
    motas = []                 # [sprite, vx, vy, edad, vida]
    240.times do |t|
      # se oscurece un poco todo lo de alrededor
      velo.opacity = t < 180 ? 110 * [t / 30.0, 1.0].min : 110 * [1.0 - (t - 180) / 50.0, 0.0].max
      # el haz cae de arriba abajo y luego se apaga
      if t >= 10
        u = OstMini.sale([(t - 10) / 35.0, 1.0].min)
        haz.src_rect = Rect.new(0, 0, haz.bitmap.width, (haz.bitmap.height * u).round)
        brillo = 220 + 25 * Math.sin(t / 7.0)
        haz.opacity = t < 170 ? brillo * [(t - 10) / 30.0, 1.0].min : brillo * [1.0 - (t - 170) / 55.0, 0.0].max
      end
      # lo oscuro se va aclarando (el aura, el tinte y el fondo los lleva tick)
      @f = 1.0 - OstMini.suave([[(t - 40) / 100.0, 0.0].max, 1.0].min) if t >= 40 && t <= 140
      if t == 140
        @f = 0.0
        sp.tone.set(0, 0, 0, 0)
        sp.color.set(255, 250, 225, 210)
        anillo.opacity = 255
      end
      # motas de luz que suben desde el Wooloo
      if t >= 30 && t < 175 && motas_b
        2.times do
          m = Sprite.new(vp)
          m.bitmap = motas_b; m.blend_type = 1; m.z = sp.z + 3
          m.src_rect = Rect.new(rand(6) * MOTA, 0, MOTA, MOTA)
          m.ox = m.oy = MOTA / 2
          m.zoom_x = m.zoom_y = 0.35 + rand * 0.55
          m.x = cx + (rand - 0.5) * ancho * 0.9
          m.y = pies - rand * alto * 1.6
          m.opacity = 0
          motas.push([m, (rand - 0.5) * 0.8, -1.2 - rand * 2.2, 0, 45 + rand(40)])
        end
      end
      motas.each do |q|
        m = q[0]
        next if m.disposed?
        q[3] += 1
        m.x += q[1]; m.y += q[2]
        m.angle += 2 if m.src_rect.x != 3 * MOTA && m.src_rect.x != 4 * MOTA
        m.opacity = 255 * Math.sin(Math::PI * [q[3].to_f / q[4], 1.0].min)
        m.dispose if q[3] >= q[4]
      end
      # el anillo sale de el y se deshace; el destello blanco se apaga
      if t > 140
        u = OstMini.sale([(t - 140) / 50.0, 1.0].min)
        anillo.zoom_x = anillo.zoom_y = (0.1 + 1.4 * u) * ancho / 400.0
        anillo.opacity = 255 * (1 - u)
        sp.color.alpha = sp.color.alpha * 0.93
      end
      begin; pbSEPlay("Cries/WOOLOO", 90, 100); rescue; end if t == 150
      scene.pbUpdate
    end
    OstSecuaces.oscuro = 0.0     # y en el mapa sale ya con su color
    sp.color.set(0, 0, 0, 0)
    motas.each { |q| q[0].dispose if !q[0].disposed? }
    # su barra se va, como al debilitarse
    begin
      caja = Animation::DataBoxDisappear.new(sps, vp, battler.index)
      loop { caja.update; scene.pbUpdate; break if caja.animDone? }
      caja.dispose
    rescue
      sps["dataBox_#{battler.index}"].visible = false rescue nil
    end
  ensure
    (cosas || []).each do |s|
      next if s.disposed?
      s.bitmap.dispose if s.bitmap && s != haz && s != anillo && !s.bitmap.disposed?
      s.dispose
    end
  end
end

class Battle::Battler
  alias ostjefe_pbFaint pbFaint
  def pbFaint(showMessage = true)
    # el "se debilito" no: el Wooloo se calma (lo dice la escena)
    showMessage = false if OstJefe.activo? && opposes?
    ostjefe_pbFaint(showMessage)
  end
end

class Battle::Scene
  alias ostjefe_pbFaintBattler pbFaintBattler
  def pbFaintBattler(battler)
    return ostjefe_pbFaintBattler(battler) if !OstJefe.activo? || !battler.opposes?
    @briefMessage = false
    begin
      OstJefe.calmar(self, battler)
    rescue StandardError => e
      echoln("OstJefe.calmar: #{e.class}: #{e.message}") rescue nil
      @sprites["dataBox_#{battler.index}"].visible = false rescue nil
    end
    @battle.pbDisplay(_INTL("¡El Wooloo se ha calmado!"))
  end
end
