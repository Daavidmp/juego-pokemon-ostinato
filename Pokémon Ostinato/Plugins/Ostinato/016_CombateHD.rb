#===============================================================================
# Pokemon Ostinato - El combate a pantalla completa (1920x1080) con la
# interfaz de David (2026-11, al estilo de Espada/Escudo)
#
#   Mientras dura el combate la pantalla sube a 1920x1080 (OstinatoHD), en vez
#   de ir en el recuadro de 512 centrado (008_Pantallas512). Lo que se abre
#   desde el combate (mochila, equipo) baja un momento a la resolucion normal
#   y se ve como siempre.
#
#   La escena: los fondos de combate se amplian para llenar el ancho si son
#   pequenos (los de 1920x1080 van tal cual), y los Pokemon y entrenadores se
#   amplian ESCALA veces, un numero entero para que el pixel se vea limpio
#   (los Pokemon del rival, ESCALA_RIVAL: estan mas lejos).
#   Tus Pokemon (y Kaia) van cortados por abajo: el corte, justo en el borde
#   de abajo de la pantalla.
#
#   La interfaz: piezas en Graphics/UI/Ostinato/Combate/ sacadas del
#   ostinato_combate_sin_interfaz_texto.kra de David (fichas, tiras del equipo,
#   botones, plantilla de los ataques, X/Y) y de la maqueta de Claude Design
#   (banda de los mensajes, aviso de habilidad). El texto se escribe encima con
#   Barlow (Fonts/OstTitulo, OstEtiqueta, OstTexto y OstNombre, licencia OFL).
#   Todos los combates la usan, tambien el del jefe (026).
#
#   Todas las medidas estan en la pantalla de 1920x1080.
#===============================================================================
module OstCombate
  DIR    = "Graphics/UI/Ostinato/Combate/"
  F_TITULO   = "OstTitulo"   # Barlow Semi Condensed Bold: botones, ataques, habilidad
  F_ETIQUETA = "OstEtiqueta" # Barlow Semi Condensed SemiBold: mensajes, eficacia
  F_TEXTO    = "OstTexto"    # Barlow Regular: numeros
  F_NOMBRE   = "OstNombre"   # Barlow Medium: nombres
  ESCALA = 3                 # Pokemon y entrenadores (sus PNG ya van a x2)
  ESCALA_RIVAL = 2           # los Pokemon del rival (estan mas lejos): 2/3 de los tuyos
  ANCHO  = 1920
  ALTO   = 1080
  MENSAJE_Y = ALTO - 144     # la banda oscura de los mensajes

  # centro de los pies de cada lado; los tuyos, el corte en el borde de abajo
  PROPIO = [760, ALTO]
  RIVAL  = [1374, 418]

  # Combates dobles: los Pokemon a su tamano de siempre (x3) y cada uno en su
  # sitio; los rivales, por la fila de abajo de su dibujo (sus pies).
  DOBLE_ESCALA = 3
  DOBLE = [[760, ALTO], [1300, 605], [1160, ALTO], [900, 550]]   # indice 0..3: [x, y]
  DOBLE_FICHA = 0.8          # las fichas, apiladas: las tuyas abajo a la izquierda, las del rival arriba a la derecha
  DOBLE_FICHAS = [[0, 852], [1506, 18], [0, 956], [1506, 104]]
  # Los fondos no tienen losas (como en Pokemon Anil): el Pokemon y el entrenador
  # rivales se apoyan por los pies en el suelo del fondo, aqui.
  # SIN_SUELO: mapas cuyo fondo si tenga losas (ninguno por ahora)
  SIN_SUELO = []
  SUELO_RIVAL_Y = 576         # (560 se veia flotando un pelin)
  SUELO_RIVAL_X = 1010        # en individuales, el rival y su entrenador
  SUELO_ENTRENADOR_Y = 567
  PIES_EN_SOMBRA = 10         # los pies del rival, esto por debajo del centro de su sombra
  # el entrenador rival de un doble: entre DOBLE[1] y DOBLE[3], pies a su altura
  DOBLE_ENTRENADOR = [1100, 584]
  # fondos con el suelo mas abajo: mapa => lo que baja el lado rival
  BAJAR_SUELO = { 9 => 84 }   # ruta 1: a 576 los pies caian en los arbustos del bosque

  def self.bajar_suelo
    return ($game_map && BAJAR_SUELO[$game_map.map_id]) || 0
  end

  # La letra de la interfaz nueva, por la altura de sus mayusculas
  def self.letra(bitmap, nombre, cap)
    bitmap.font.name = nombre
    bitmap.font.size = (cap / 0.7).round
    bitmap.font.bold = false
    bitmap.font.italic = false
    begin
      bitmap.font.outline = false
      bitmap.font.shadow = false
    rescue
    end
  end

  # Escribe con la linea base en "base" (Barlow: la caja de la linea mide
  # 1,2 veces el tamano y la linea base queda a 1 tamano de su borde de arriba)
  def self.escribe(bitmap, x, base, txt, alin = 0, ancho = 800, color = Color.new(35, 35, 35))
    t = bitmap.font.size
    bitmap.font.color = color
    bitmap.draw_text(x, base - t, ancho, (t * 1.2).round, txt.to_s, alin)
  end

  def self.rival_doble?; return @rival_doble; end
  def self.rival_doble=(v); @rival_doble = v; end

  def self.suelo?
    return !($game_map && SIN_SUELO.include?($game_map.map_id))
  end

  # filas vacias que tiene un dibujo por debajo de lo que se ve (sus pies)
  def self.vacio_abajo(bm)
    return 0 if !bm || bm.disposed?
    @vacio ||= {}
    @vacio.clear if @vacio.size > 64
    return @vacio[bm.object_id] if @vacio.key?(bm.object_id)
    n = 0
    (bm.height - 1).downto(0) do |y|
      lleno = false
      0.step(bm.width - 1, 2) do |x|
        if bm.get_pixel(x, y).alpha > 0
          lleno = true
          break
        end
      end
      break if lleno
      n += 1
    end
    n = 0 if n >= bm.height
    @vacio[bm.object_id] = n
    return n
  end

  @activo = false
  def self.activo?; return @activo; end

  # La animacion de entrada (015) deja la pantalla ya a 1920: el combate la
  # aprovecha en vez de bajarla y subirla otra vez
  def self.dejar_subida(antes)
    @pendiente = antes
  end

  def self.con
    return yield if @activo
    antes = @pendiente || OstinatoHD.subir
    @pendiente = nil
    @antes = antes
    @activo = true
    begin
      return yield
    ensure
      if @temporal
        # el combate acabo con la pantalla ya bajada (el fundido final):
        # fuera las bandas de 512, del todo
        OstUI.salir while OstUI.activo?
        @temporal = false
      else
        OstinatoHD.bajar(@antes) if @antes
      end
      @activo = false
      @antes = nil
    end
  end

  # Lo que se abre desde el combate y esta hecho para 512 (mochila, equipo):
  # se baja a la resolucion normal mientras esta abierto.
  def self.en_pequeno
    return yield if !@activo || !@antes
    OstinatoHD.bajar(@antes)
    @activo = false
    begin
      return yield
    ensure
      @antes = OstinatoHD.subir
      @activo = true
    end
  end

  # caja del dibujo (lo no transparente) de un bitmap, mirando de 2 en 2
  def self.caja(bm)
    x0 = bm.width; y0 = bm.height; x1 = 0; y1 = 0
    (0...bm.height).step(2) do |y|
      (0...bm.width).step(2) do |x|
        next if bm.get_pixel(x, y).alpha < 30
        x0 = x if x < x0; x1 = x if x > x1
        y0 = y if y < y0; y1 = y if y > y1
      end
    end
    return [0, 0, bm.width - 1, bm.height - 1] if x1 < x0
    return [x0, y0, x1, y1]
  end

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

  def self.tipo_id(tipo)
    begin
      return GameData::Type.get(tipo).id.to_s
    rescue
      return "NORMAL"
    end
  end
end

#-------------------------------------------------------------------------------
# Entrada: el combate va a 1920x1080
#-------------------------------------------------------------------------------
def pbBattleAnimation(*args, &block)
  return ostui_pbBattleAnimation(*args) if !block
  ostui_pbBattleAnimation(*args) { OstCombate.con(&block) }
end

module OstUI
  class << self
    alias ostcomb_con con
    def con(&blk)
      return OstCombate.en_pequeno { ostcomb_con(&blk) } if OstCombate.activo?
      return ostcomb_con(&blk)
    end
  end
end

#-------------------------------------------------------------------------------
# Donde va cada uno
#-------------------------------------------------------------------------------
class Battle::Scene
  class << self
    alias ostcomb_pbBattlerPosition pbBattlerPosition
    def pbBattlerPosition(index, sideSize = 1)
      return ostcomb_pbBattlerPosition(index, sideSize) if !OstCombate.activo?
      k = OstCombate::ESCALA
      if sideSize == 2 && OstCombate::DOBLE[index]
        ret = OstCombate::DOBLE[index].clone
        ret[1] += OstCombate.bajar_suelo if index.odd?
        return ret
      end
      ret = ((index & 1) == 0) ? OstCombate::PROPIO.clone : OstCombate::RIVAL.clone
      ret[0] = OstCombate::SUELO_RIVAL_X if (index & 1) == 1 && sideSize == 1 && OstCombate.suelo?
      case sideSize
      when 2
        ret[0] += BATTLER_OFFSET_2_X[index] * k
        ret[1] += BATTLER_OFFSET_2_Y[index] * k
      when 3
        ret[0] += BATTLER_OFFSET_3_X[index] * k
        ret[1] += BATTLER_OFFSET_3_Y[index] * k
      end
      return ret
    end

    alias ostcomb_pbTrainerPosition pbTrainerPosition
    def pbTrainerPosition(side, index = 0, sideSize = 1)
      return ostcomb_pbTrainerPosition(side, index, sideSize) if !OstCombate.activo?
      k = OstCombate::ESCALA
      if side == 0
        # Kaia va cortada por la cintura: su borde de abajo, en el borde de la pantalla
        ret = [OstCombate::PROPIO[0] - 40, OstCombate::ALTO + 2]
      else
        ret = [OstCombate::RIVAL[0], OstCombate::RIVAL[1] + TRAINER_FOE_OFFSET_Y * k]
        ret = [OstCombate::SUELO_RIVAL_X, OstCombate::SUELO_ENTRENADOR_Y] if OstCombate.suelo? && sideSize == 1
        ret[1] = OstCombate::SUELO_ENTRENADOR_Y if OstCombate.suelo?
        # combate doble contra un solo entrenador: en medio de sus dos Pokemon
        # y en su mismo suelo, no en el sitio del individual (flotaba)
        ret = OstCombate::DOBLE_ENTRENADOR.clone if OstCombate.rival_doble? && sideSize == 1
        ret[1] += OstCombate.bajar_suelo if OstCombate.suelo?
      end
      case sideSize
      when 2
        ret[0] += TRAINER_OFFSET_2_X[(2 * index) + side] * k
        ret[1] += TRAINER_OFFSET_2_Y[(2 * index) + side] * k
      when 3
        ret[0] += TRAINER_OFFSET_3_X[(2 * index) + side] * k
        ret[1] += TRAINER_OFFSET_3_Y[(2 * index) + side] * k
      end
      return ret
    end
  end

  # Fondo y bases: los de 512 se amplian a lo ancho; los de 1920, tal cual
  alias ostcomb_pbCreateBackdropSprites pbCreateBackdropSprites
  def pbCreateBackdropSprites
    OstCombate.rival_doble = (@battle.pbSideSize(1) == 2) rescue false
    ostcomb_pbCreateBackdropSprites
    return if !OstCombate.activo?
    bg = @sprites["battle_bg"]
    if bg && bg.bitmap
      z = (bg.bitmap.width < OstCombate::ANCHO - 20) ? OstCombate::ANCHO.to_f / bg.bitmap.width : 1.0
      alto = bg.bitmap.height * z
      ["battle_bg", "battle_bg2"].each do |k|
        s = @sprites[k]
        next if !s
        s.zoom_x = z
        s.zoom_y = z
        s.y = ((OstCombate::ALTO - alto) / 2).round
      end
      @sprites["battle_bg2"].x = -OstCombate::ANCHO if @sprites["battle_bg2"]
      # Sin losas, como en Pokemon Anil: los Pokemon pisan el suelo del fondo
      # y llevan su sombra debajo.
      2.times do |side|
        base = @sprites.delete("base_#{side}")
        base.dispose if base && !base.disposed?
      end
    end
    @sprites["cmdBar_bg"].visible = false if @sprites["cmdBar_bg"]
    @sprites["cmdBar_bg"].opacity = 0 if @sprites["cmdBar_bg"]
  end

  # La banda oscura de los mensajes (abajo, a la derecha de tu ficha) y el
  # texto, en blanco
  alias ostcomb_pbInitSprites pbInitSprites
  def pbInitSprites
    ostcomb_pbInitSprites
    return if !OstCombate.activo?
    box = @sprites["messageBox"]
    if box
      # con setBitmap: al refrescarse (al volver del equipo) no vuelve al de 512
      box.setBitmap(OstCombate::DIR + "banda_mensaje")
      box.x = 0
      box.y = OstCombate::MENSAJE_Y
    end
    w = @sprites["messageWindow"]
    if w
      w.x = 548
      w.y = OstCombate::MENSAJE_Y + 4
      w.width = 1340
      w.height = 140
      w.baseColor = Color.new(255, 255, 255)
      w.shadowColor = Color.new(0, 0, 0, 160)
      if w.contents
        OstCombate.letra(w.contents, OstCombate::F_ETIQUETA, 30)
        w.contents.font.color = Color.new(255, 255, 255)
      end
      w.lineHeight = 56 if w.respond_to?(:lineHeight=)
      # pbMessageDisplay la vuelve a pegar abajo: se le guarda su sitio
      w.instance_variable_set(:@ost_sitio, [w.x, w.y, w.width, w.height])
      # la ventana vuelve a la fuente del sistema al cambiar de texto: se le
      # pone la suya justo antes de cada mensaje
      def w.setText(value)
        OstCombate.letra(self.contents, OstCombate::F_ETIQUETA, 30) if self.contents && !self.contents.disposed?
        @oldfont = nil
        super
      end
      # la flecha de "pulsa para seguir", algo mas grande
      def w.moveCursor
        super
        return if !@pausesprite || @pausesprite.disposed?
        @pausesprite.zoom_x = @pausesprite.zoom_y = 1.4
        @pausesprite.x += 30
      end
    end
  end

  # Los mensajes llevan su color dentro (shadowc3tag con MESSAGE_BASE_COLOR, el
  # gris oscuro de la v21): sobre la banda oscura, blanco con sombra negra
  def shadowc3tag(base, shadow)
    if OstCombate.activo? && base == MESSAGE_BASE_COLOR
      base = Color.new(255, 255, 255)
      shadow = Color.new(0, 0, 0, 160)
    end
    return super(base, shadow)
  end

  # Entrenadores, a la escala de los Pokemon
  alias ostcomb_pbCreateTrainerBackSprite pbCreateTrainerBackSprite
  def pbCreateTrainerBackSprite(idxTrainer, trainerType, numTrainers = 1)
    ostcomb_pbCreateTrainerBackSprite(idxTrainer, trainerType, numTrainers)
    s = @sprites["player_#{idxTrainer + 1}"]
    if OstCombate.activo? && s
      s.zoom_x = OstCombate::ESCALA
      s.zoom_y = OstCombate::ESCALA
    end
  end

  alias ostcomb_pbCreateTrainerFrontSprite pbCreateTrainerFrontSprite
  def pbCreateTrainerFrontSprite(idxTrainer, trainerType, numTrainers = 1)
    ostcomb_pbCreateTrainerFrontSprite(idxTrainer, trainerType, numTrainers)
    s = @sprites["trainer_#{idxTrainer + 1}"]
    if OstCombate.activo? && s
      s.zoom_x = s.zoom_y = OstCombate.zoom_entrenador(s.bitmap)
    end
  end
end

module OstCombate
  # Los pictures de siempre miden 144 de alto y se amplian x3. Los que ya
  # vienen en alta (sacados del dibujo original sin pasar a 144) se dibujan
  # a su tamano, para no perder detalle: a 432 de alto, zoom 1.
  def self.zoom_entrenador(bm)
    return ESCALA if !bm || bm.disposed? || bm.height < 288
    return ESCALA * 144.0 / bm.height
  end
end

#-------------------------------------------------------------------------------
# Pokemon y sus sombras, ampliados (las animaciones siguen viendo su zoom 1)
#-------------------------------------------------------------------------------
module OstCombateZoom
  def ost_k
    return 1 if !OstCombate.activo?
    # los del rival, mas lejos: mas pequenos (tambien entero, pixel limpio)
    return OstCombate::ESCALA_RIVAL if @index && @index.odd?
    return OstCombate::DOBLE_ESCALA if @sideSize && @sideSize > 1
    return OstCombate::ESCALA
  end

  # el rival, apoyado por sus pies (dobles, y fondos con el suelo mas abajo)
  def ost_suelo_y
    return nil if !OstCombate.activo? || !@index || @index.even?
    return OstCombate::DOBLE[@index][1] + OstCombate.bajar_suelo if @sideSize == 2 && OstCombate::DOBLE[@index]
    return OstCombate::SUELO_RIVAL_Y + OstCombate.bajar_suelo if OstCombate.suelo? && (!@sideSize || @sideSize == 1)
    return nil
  end

  def zoom_x=(v)
    @ost_zx = v
    super(v * ost_k)
  end

  def zoom_y=(v)
    @ost_zy = v
    super(v * ost_k)
  end

  def zoom_x; return @ost_zx || 1.0; end
  def zoom_y; return @ost_zy || 1.0; end

  # los desplazamientos de las medidas de cada especie, a la misma escala
  def ost_escalar_posicion
    return if !OstCombate.activo?
    p = Battle::Scene.pbBattlerPosition(@index, @sideSize)
    k = ost_k
    if instance_variable_defined?(:@spriteX) && self.is_a?(Battle::Scene::BattlerSprite)
      @spriteX = p[0] + (@spriteX - p[0]) * k
      @spriteY = p[1] + (@spriteY - p[1]) * k
    else
      self.x = p[0] + (self.x - p[0]) * k
      self.y = p[1] + (self.y - p[1]) * k
    end
    self.zoom_x = zoom_x
    self.zoom_y = zoom_y
    if self.is_a?(Battle::Scene::BattlerSprite)
      self.x = @spriteX
      self.y = @spriteY
    end
  end
end

class Battle::Scene::BattlerSprite
  prepend OstCombateZoom
  alias ostcomb_pbSetPosition pbSetPosition
  def pbSetPosition
    ostcomb_pbSetPosition
    ost_escalar_posicion if @_iconBitmap
    suelo = @_iconBitmap ? ost_suelo_y : nil
    # la imagen se ancla por abajo: su fila de abajo con dibujo, en el suelo (un poco dentro de la sombra,
    # que si no parecia que flotaba)
    self.y = suelo + OstCombate.vacio_abajo(@_iconBitmap.bitmap) * ost_k + OstCombate::PIES_EN_SOMBRA if suelo
    # los tuyos: el corte de abajo de su dibujo, justo en el borde de abajo de
    # la pantalla (sin barra que lo tape, no puede quedar mas arriba)
    if @_iconBitmap && OstCombate.activo? && @index && @index.even?
      self.y = OstCombate::ALTO + OstCombate.vacio_abajo(@_iconBitmap.bitmap) * ost_k
    end
  end
end

class Battle::Scene::BattlerShadowSprite
  prepend OstCombateZoom
  alias ostcomb_pbSetPosition pbSetPosition
  def pbSetPosition
    ostcomb_pbSetPosition
    ost_escalar_posicion if @_iconBitmap
    suelo = @_iconBitmap ? ost_suelo_y : nil
    self.y = suelo if suelo      # la sombra, centrada en los pies
  end
end

#-------------------------------------------------------------------------------
# Las fichas: las del dibujo de David (blancas, con el borde inclinado). El
# nombre, el nivel y los PS se escriben encima; las barras de vida y de
# experiencia las pinta el codigo. Debajo de la ficha de abajo de cada lado, la
# tira del equipo: una Poke Ball por Pokemon (amarilla si tiene un problema de
# estado, gris si esta debilitado). La del rival, solo contra entrenadores.
#
#   :nombre, :nivel => [x, linea base]; :numeros => [x, y] de su recuadro
#   (la linea base va a OST_NUM_BASE dentro); :vida, :exp => [x, y, ancho, alto].
#-------------------------------------------------------------------------------
class Battle::Scene::PokemonDataBox
  OST_RIVAL = { :pos => [1403, 24], :fondo => "ficha_rival",
                :nombre => [62, 49], :nivel => [418, 54], :vida => [62, 66, 404, 15] }
  OST_PROPIA = { :pos => [0, 921], :fondo => "ficha_propia",
                 :nombre => [16, 50], :nivel => [372, 55], :vida => [16, 59, 404, 15],
                 :numeros => [16, 61], :exp => [245, 80, 175, 9] }
  OST_NUM_BASE = 52
  OST_TEXTO  = Color.new(35, 35, 35)
  OST_HUECO  = Color.new(222, 222, 222)       # lo que falta de la barra de vida
  OST_COLORES = [Color.new(30, 248, 14), Color.new(250, 200, 40),
                 Color.new(250, 130, 30), Color.new(230, 40, 40)]
  # las Poke Balls de la tira: x de cada hueco y su y (tira_propia / tira_rival)
  OST_BOLAS = { true => [[4, 23, 42, 61, 80, 99], 3], false => [[17, 37, 57, 78, 98, 118], 3] }

  alias ostcomb_initialize initialize
  def initialize(battler, sideSize, viewport = nil)
    @ost = OstCombate.activo?
    @ost_lado = sideSize
    ostcomb_initialize(battler, sideSize, viewport)
  end

  def ost_datos
    return (@battler.index.even?) ? OST_PROPIA : OST_RIVAL
  end

  # la tira del equipo va debajo de la ficha de abajo de cada lado; la del
  # rival, solo si es un entrenador
  def ost_con_tira?
    lado = @battler.index & 1
    n = (@battler.battle.pbSideSize(lado) rescue 1)
    return false if @battler.index != lado + 2 * (n - 1)
    return true if lado == 0
    return (@battler.battle.trainerBattle? rescue false)
  end

  alias ostcomb_initializeDataBoxGraphic initializeDataBoxGraphic
  def initializeDataBoxGraphic(sideSize)
    return ostcomb_initializeDataBoxGraphic(sideSize) if !@ost
    d = ost_datos
    @show_hp_numbers = @battler.index.even?
    @show_exp_bar    = @battler.index.even?
    @show_hp_percent = false
    @databoxBitmap&.dispose
    @databoxBitmap = AnimatedBitmap.new(OstCombate::DIR + d[:fondo])
    @spriteX = d[:pos][0]
    @spriteY = d[:pos][1]
    @ost_esc = 1.0
    # en dobles, mas pequenas y una encima de otra, sin salirse de la pantalla
    if sideSize > 1 && OstCombate::DOBLE_FICHAS[@battler.index]
      @ost_esc = OstCombate::DOBLE_FICHA
      @spriteX, @spriteY = OstCombate::DOBLE_FICHAS[@battler.index]
    end
    @spriteBaseX = 0
  end

  alias ostcomb_initializeOtherGraphics initializeOtherGraphics
  def initializeOtherGraphics(viewport)
    return ostcomb_initializeOtherGraphics(viewport) if !@ost
    d = ost_datos
    @numbersBitmap = AnimatedBitmap.new("Graphics/UI/Battle/icon_numbers")
    @hpBarBitmap   = AnimatedBitmap.new("Graphics/UI/Battle/overlay_hp")
    @expBarBitmap  = AnimatedBitmap.new("Graphics/UI/Battle/overlay_exp")
    @hpNumbers = BitmapSprite.new(300, 70, viewport)
    @sprites["hpNumbers"] = @hpNumbers
    @hpPercent = BitmapSprite.new(4, 4, viewport)
    @sprites["hpPercent"] = @hpPercent
    v = d[:vida]
    @hpBar = Sprite.new(viewport)
    @hpBarDisplay = Bitmap.new(v[2], v[3])
    @hpBar.bitmap = @hpBarDisplay
    @sprites["hpBar"] = @hpBar
    @expBar = Sprite.new(viewport)
    e = d[:exp] || [0, 0, 4, 4]
    @ostExp = Bitmap.new(e[2], e[3])
    @ostExp.fill_rect(0, 0, e[2], e[3], Color.new(60, 170, 240))
    @expBar.bitmap = @ostExp
    @sprites["expBar"] = @expBar
    if ost_con_tira?
      @ostLinea = Sprite.new(viewport)
      @ostLinea.bitmap = Bitmap.new(140, 27)
      @sprites["ostLinea"] = @ostLinea
    end
    @contents = Bitmap.new(@databoxBitmap.width, @databoxBitmap.height)
    self.bitmap  = @contents
    self.visible = false
    self.z       = DATABOX_BASE_Z + ((@battler.index / 2) * 5)
    if @ost_esc != 1.0
      [self, @hpBar, @expBar, @hpNumbers].each { |sp| sp.zoom_x = sp.zoom_y = @ost_esc }
    end
  end

  alias ostcomb_dispose dispose
  def dispose
    @ostExp&.dispose
    @ostLinea.bitmap.dispose if @ostLinea && !@ostLinea.disposed? && @ostLinea.bitmap
    ostcomb_dispose
  end

  # la tira: la tuya pegada al borde izquierdo, la del rival al derecho (los
  # dos, el mismo que el de la ficha), y justo debajo de la ficha
  def ost_tira_xy(bx, by)
    e = @ost_esc || 1.0
    alto = (@databoxBitmap.height * e).round
    if @battler.index.even?
      return [bx, by + alto]
    end
    return [bx + (@databoxBitmap.width * e).round - @ostLinea.bitmap.width, by + alto - 1]
  end

  alias ostcomb_x_set x=
  def x=(value)
    return ostcomb_x_set(value) if !@ost
    Sprite.instance_method(:x=).bind(self).call(value)
    d = ost_datos
    e = @ost_esc || 1.0
    @hpBar.x = value + (d[:vida][0] * e).round
    @expBar.x = value + ((d[:exp] ? d[:exp][0] : 0) * e).round
    @hpNumbers.x = value + ((d[:numeros] ? d[:numeros][0] : 0) * e).round
    @hpPercent.x = value
    if @ostLinea
      @ostLinea.x = ost_tira_xy(value, self.y)[0]
    end
  end

  alias ostcomb_y_set y=
  def y=(value)
    return ostcomb_y_set(value) if !@ost
    Sprite.instance_method(:y=).bind(self).call(value)
    d = ost_datos
    e = @ost_esc || 1.0
    @hpBar.y = value + (d[:vida][1] * e).round
    @expBar.y = value + ((d[:exp] ? d[:exp][1] : 0) * e).round
    @hpNumbers.y = value + ((d[:numeros] ? d[:numeros][1] : 0) * e).round
    @hpPercent.y = value
    if @ostLinea
      @ostLinea.y = ost_tira_xy(self.x, value)[1]
    end
  end

  alias ostcomb_refresh refresh
  def refresh
    return ostcomb_refresh if !@ost
    self.bitmap.clear
    return if !@battler.pokemon
    d = ost_datos
    b = self.bitmap
    b.blt(0, 0, @databoxBitmap.bitmap, Rect.new(0, 0, @databoxBitmap.width, @databoxBitmap.height))
    v = d[:vida]
    b.fill_rect(v[0], v[1], v[2], v[3], OST_HUECO)
    OstCombate.letra(b, OstCombate::F_NOMBRE, 24)
    nombre = @battler.name.to_s
    OstCombate.escribe(b, d[:nombre][0], d[:nombre][1], nombre, 0, 330, OST_TEXTO)
    OstCombate.letra(b, OstCombate::F_TEXTO, 35)
    OstCombate.escribe(b, d[:nivel][0], d[:nivel][1], @battler.level.to_s, 0, 90, OST_TEXTO)
    # el estado (el icono de la v21, x2), detras del nombre
    if @battler.status != :NONE
      begin
        if @battler.status == :POISON && @battler.statusCount > 0
          s = GameData::Status.count - 1
        else
          s = GameData::Status.get(@battler.status).icon_position
        end
        if s >= 0
          OstCombate.letra(b, OstCombate::F_NOMBRE, 24)
          x = d[:nombre][0] + b.text_size(nombre).width + 12
          ic = Bitmap.new("Graphics/UI/Battle/icon_statuses")
          b.stretch_blt(Rect.new(x, d[:nombre][1] - 26, ic.width * 2, STATUS_ICON_HEIGHT * 2), ic,
                        Rect.new(0, s * STATUS_ICON_HEIGHT, ic.width, STATUS_ICON_HEIGHT))
          ic.dispose
        end
      rescue
      end
    end
    ost_tira
    refresh_hp
    refresh_exp
  end

  alias ostcomb_refresh_hp refresh_hp
  def refresh_hp
    return ostcomb_refresh_hp if !@ost
    @hpNumbers.bitmap.clear
    return if !@battler.pokemon
    d = ost_datos
    if @show_hp_numbers && d[:numeros]
      nb = @hpNumbers.bitmap
      # "PS/total" de un tiron, pegado a la izquierda: la "/" cae donde toque
      OstCombate.letra(nb, OstCombate::F_TEXTO, 29)
      OstCombate.escribe(nb, 0, OST_NUM_BASE, "#{self.hp.round}/#{@battler.totalhp}", 0, 300, OST_TEXTO)
    end
    v = d[:vida]
    w = 0
    if self.hp > 0
      w = (v[2] * self.hp.to_f / @battler.totalhp).round
      w = 2 if w < 2
    end
    idx, _sig, _mezcla = pbHPBarZoneInfo(self.hp, @battler.totalhp, HP_COLOR_COUNT)
    col = OST_COLORES[[idx, 3].min]
    @hpBarDisplay.clear
    @hpBarDisplay.fill_rect(0, 0, v[2], v[3], col)
    @hpBar.src_rect.width = w
  end

  alias ostcomb_databox_z_set z=
  def z=(value)
    ostcomb_databox_z_set(value)
    return if !@ostLinea || @ostLinea.disposed?
    @ostLinea.z = value   # la tira, con su ficha
  end

  # la tira del equipo
  def ost_tira
    return if !@ostLinea || @ostLinea.disposed?
    b = @ostLinea.bitmap
    b.clear
    propio = @battler.index.even?
    base = OstCombate.bmp(propio ? "tira_propia" : "tira_rival")
    b.blt(0, 0, base, base.rect)
    equipo = []
    begin
      equipo = @battler.battle.pbParty(@battler.index)
    rescue
    end
    xs, y = OST_BOLAS[propio]
    xs.each_with_index do |x, i|
      pk = equipo[i]
      next if !pk || pk.egg?
      n = (pk.fainted?) ? "bola_debil" : (pk.status != :NONE) ? "bola_estado" : "bola"
      bm = OstCombate.bmp(n)
      b.blt(x, y, bm, bm.rect)
    end
    @ostLinea.x, @ostLinea.y = ost_tira_xy(self.x, self.y)
  end

  alias ostcomb_refresh_exp refresh_exp
  def refresh_exp
    return ostcomb_refresh_exp if !@ost
    return if !@show_exp_bar || !ost_datos[:exp]
    @expBar.src_rect.width = (exp_fraction * ost_datos[:exp][2]).round
  end
end

#-------------------------------------------------------------------------------
# Los cuatro botones (Luchar, Pokemon, Mochila, Huir): pildoras blancas a la
# derecha, una debajo de otra; la elegida, negra con la letra blanca y un
# pelin mas grande. Los iconos son los del dibujo de David (icono_*).
#-------------------------------------------------------------------------------
class Battle::Scene::CommandMenu
  OST_X     = 1555                   # borde izquierdo de las pildoras
  OST_Y     = [609, 726, 843, 959]   # borde de arriba de cada fila
  OST_W     = 351
  OST_H     = 103
  OST_PAD   = 24                     # el margen de la sombra en boton.png
  OST_FILA  = [0, 2, 1, 3]           # de arriba abajo, con los indices de la v21
  OST_ICONO = [["icono_luchar", 213, 1], ["icono_mochila", 197, 1],
               ["icono_pokemon", 197, 1], ["icono_huir", 197, 3]]   # por indice
  OST_GRANDE = 1.03                  # la elegida

  def ost_filas; return OST_FILA; end

  def ost_centro(i)
    f = OST_FILA.index(i) || i
    return [OST_X + OST_W / 2.0, OST_Y[f] + OST_H / 2.0]
  end

  alias ostcomb_initialize initialize
  def initialize(viewport, z)
    @ost = OstCombate.activo?
    return ostcomb_initialize(viewport, z) if !@ost
    Battle::Scene::MenuBase.instance_method(:initialize).bind(self).call(viewport)
    self.x = 0
    self.y = 0
    @textos = []
    @ostZoom = [1.0, 1.0, 1.0, 1.0]
    @ostXY = Sprite.new(viewport)
    @ostXY.bitmap = OstCombate.bmp("xy")
    @ostXY.x = 1676
    @ostXY.y = 466
    addSprite("xy", @ostXY)
    @ostFondo = []
    @ostIcono = []
    @ostLetras = []
    @ostZona = Bitmap.new(OST_W, OST_H)
    @buttons = Array.new(4) do |i|
      cx, cy = ost_centro(i)
      f = Sprite.new(viewport)
      f.bitmap = OstCombate.bmp("boton")
      f.ox = OST_PAD + OST_W / 2.0
      f.oy = OST_PAD + OST_H / 2.0
      f.x = cx
      f.y = cy
      addSprite("fondo_#{i}", f)
      @ostFondo[i] = f
      nombre, ix, iy = OST_ICONO[i]
      ic = Sprite.new(viewport)
      ic.bitmap = OstCombate.bmp("" + nombre)
      ic.ox = OST_W / 2.0 - ix
      ic.oy = OST_H / 2.0 - iy
      ic.x = cx
      ic.y = cy
      addSprite("icono_#{i}", ic)
      @ostIcono[i] = ic
      l = Sprite.new(viewport)
      l.bitmap = Bitmap.new(OST_W, OST_H)
      l.ox = OST_W / 2.0
      l.oy = OST_H / 2.0
      l.x = cx
      l.y = cy
      addSprite("letras_#{i}", l)
      @ostLetras[i] = l
      # la zona para el raton (invisible), del tamano de la pildora
      s = Sprite.new(viewport)
      s.bitmap = @ostZona
      s.x = OST_X
      s.y = OST_Y[OST_FILA.index(i)]
      s.opacity = 0
      addSprite("zona_#{i}", s)
      next s
    end
    self.z = z
    refresh
  end

  alias ostcomb_dispose dispose
  def dispose
    @ostLetras&.each { |l| l.bitmap.dispose if l && !l.disposed? && l.bitmap }
    ostcomb_dispose
    @ostZona&.dispose
  end

  alias ostcomb_z_set z=
  def z=(value)
    return ostcomb_z_set(value) if !@ost
    Battle::Scene::MenuBase.instance_method(:z=).bind(self).call(value)
    @ostXY.z = value + 1
    4.times do |i|
      @ostFondo[i].z = value + 1
      @ostIcono[i].z = value + 2
      @ostLetras[i].z = value + 3
    end
  end

  alias ostcomb_setTexts setTexts
  def setTexts(value)
    return ostcomb_setTexts(value) if !@ost
    @textos = value
    refresh
  end

  alias ostcomb_refresh refresh
  def refresh
    return ostcomb_refresh if !@ost
    4.times do |i|
      t = @textos[i + 1]
      hay = !nil_or_empty?(t)
      sel = (i == @index)
      @ostFondo[i].bitmap = OstCombate.bmp(sel ? "boton_sel" : "boton")
      b = @ostLetras[i].bitmap
      b.clear
      if hay
        OstCombate.letra(b, OstCombate::F_TITULO, 28)
        OstCombate.escribe(b, 39, 64, t.to_s, 0, 220,
                           sel ? Color.new(255, 255, 255) : Color.new(35, 35, 35))
      end
      ["fondo_#{i}", "icono_#{i}", "letras_#{i}", "zona_#{i}"].each do |k|
        @visibility[k] = hay
        @sprites[k].visible = @visible && hay if @sprites[k]
      end
    end
  end

  def update
    super
    return if !@ost || !@ostFondo
    4.times do |i|
      meta = (i == @index) ? OST_GRANDE : 1.0
      @ostZoom[i] += (meta - @ostZoom[i]) * 0.35
      [@ostFondo[i], @ostIcono[i], @ostLetras[i]].each do |s|
        s.zoom_x = s.zoom_y = @ostZoom[i] if s && !s.disposed?
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Los ataques: la pildora de la capa "Lucha" del .kra de David, con lo blanco
# del color del tipo (el circulo grande de su tabla) y el icono del tipo; el
# nombre y la eficacia encima y los PP en la parte negra. Una debajo de otra;
# la elegida sale un poco hacia la izquierda con la flecha delante.
#-------------------------------------------------------------------------------
class Battle::Scene::FightMenu
  OST_X      = 1299
  OST_Y      = [651, 754, 858, 964]
  OST_W      = 603
  OST_H      = 91
  OST_PAD    = 16                  # el margen de la sombra en ataques/*.png
  OST_GIRO   = 0.7                 # crece desde aqui (por el lado de los PP)
  OST_FLECHA = [1218, 15]
  OST_PP_X   = 512                 # centro de los PP en la parte negra
  OST_BLANCO = ["POISON", "GROUND", "GHOST", "DRAGON", "DARK"]   # texto en blanco

  def ost_filas; return [0, 1, 2, 3]; end

  alias ostcomb_initialize initialize
  def initialize(viewport, z)
    @ost = OstCombate.activo?
    return ostcomb_initialize(viewport, z) if !@ost
    Battle::Scene::MenuBase.instance_method(:initialize).bind(self).call(viewport)
    self.x = 0
    self.y = 0
    @battler   = nil
    @shiftMode = 0
    @ostZoom = [1.0, 1.0, 1.0, 1.0]
    @ostDx = [0.0, 0.0, 0.0, 0.0]
    @ostY = Sprite.new(viewport)
    @ostY.bitmap = OstCombate.bmp("y")
    @ostY.x = 1676
    @ostY.y = 527
    addSprite("y", @ostY)
    @ostPildora = []
    @ostLetras = []
    @ostZona = Bitmap.new(OST_W, OST_H)
    @buttons = Array.new(Pokemon::MAX_MOVES) do |i|
      p = Sprite.new(viewport)
      p.bitmap = OstCombate.bmp("ataques/NORMAL")
      p.ox = OST_PAD + OST_W * OST_GIRO
      p.oy = OST_PAD + OST_H / 2.0
      p.x = OST_X + OST_W * OST_GIRO
      p.y = OST_Y[i] + OST_H / 2.0
      addSprite("pildora_#{i}", p)
      @ostPildora[i] = p
      l = Sprite.new(viewport)
      l.bitmap = Bitmap.new(OST_W, OST_H)
      l.ox = OST_W * OST_GIRO
      l.oy = OST_H / 2.0
      l.x = p.x
      l.y = p.y
      addSprite("letras_#{i}", l)
      @ostLetras[i] = l
      s = Sprite.new(viewport)
      s.bitmap = @ostZona
      s.x = OST_X
      s.y = OST_Y[i]
      s.opacity = 0
      addSprite("button_#{i}", s)
      next s
    end
    @ostFlecha = Sprite.new(viewport)
    @ostFlecha.bitmap = OstCombate.bmp("flecha")
    @ostFlecha.x = OST_FLECHA[0]
    @ostFlecha.y = OST_Y[0] + OST_FLECHA[1]
    addSprite("flecha", @ostFlecha)
    # (PROVISIONAL, hasta que David dibuje el suyo) el boton de megaevolucionar,
    # encima de los ataques: blanco si se puede, negro si ya esta elegido
    @ostMega = Sprite.new(viewport)
    @ostMega.bitmap = Bitmap.new(OST_MEGA[2], OST_MEGA[3])
    @ostMega.x = OST_MEGA[0]
    @ostMega.y = OST_MEGA[1]
    addSprite("mega", @ostMega)
    @visibility["mega"] = false
    self.z = z
  end

  OST_MEGA = [1330, 568, 330, 64]    # x, y, ancho, alto del boton provisional

  def ost_mega; return @ostMega; end

  # una pildora con los extremos redondos (fila a fila, con un pelin de suavizado)
  def ost_pildora(b, color)
    w = b.width; h = b.height; r = h / 2.0
    h.times do |y|
      dy = (y + 0.5 - r).abs
      next if dy > r
      dx = Math.sqrt(r * r - dy * dy)
      x0 = r - dx
      b.fill_rect(x0.ceil, y, (w - 2 * x0.ceil), 1, color)
      fr = x0.ceil - x0
      if fr > 0.05
        c = Color.new(color.red, color.green, color.blue, (color.alpha * fr).round)
        b.fill_rect(x0.floor, y, 1, 1, c)
        b.fill_rect(w - x0.ceil, y, 1, 1, c)
      end
    end
  end

  def ost_dibujar_mega
    return if !@ostMega || @ostMega.disposed?
    b = @ostMega.bitmap
    b.clear
    puede = (@mode == 1 || @mode == 2)
    @visibility["mega"] = puede
    @ostMega.visible = @visible && puede
    return if !puede
    elegida = (@mode == 2)
    ost_pildora(b, elegida ? Color.new(0, 0, 0) : Color.new(255, 255, 255))
    OstCombate.letra(b, OstCombate::F_TITULO, 24)
    texto = elegida ? _INTL("¡Megaevolución!") : _INTL("Megaevolucionar")
    OstCombate.escribe(b, 0, 44, texto, 1, b.width,
                       elegida ? Color.new(255, 255, 255) : Color.new(35, 35, 35))
  end

  alias ostcomb_dispose dispose
  def dispose
    @ostLetras&.each { |l| l.bitmap.dispose if l && !l.disposed? && l.bitmap }
    @ostMega.bitmap.dispose if @ostMega && !@ostMega.disposed? && @ostMega.bitmap
    ostcomb_dispose
    @ostZona&.dispose
  end

  alias ostcomb_z_set z=
  def z=(value)
    return ostcomb_z_set(value) if !@ost
    Battle::Scene::MenuBase.instance_method(:z=).bind(self).call(value)
    @ostY.z = value + 1
    @ostMega.z = value + 1 if @ostMega
    @ostPildora.each { |s| s.z = value + 1 }
    @ostLetras.each { |s| s.z = value + 2 }
    @ostFlecha.z = value + 3
  end

  def ost_tipo(move)
    t = OstCombate.tipo_id(move.display_type(@battler)) rescue "NORMAL"
    t = "NORMAL" if !pbResolveBitmap(OstCombate::DIR + "ataques/" + t)
    return t
  end

  # "Supereficaz", "Poco eficaz"... contra el rival, si solo queda uno delante
  def ost_eficacia(move)
    return "" if !move || !@battler
    return "" if move.respond_to?(:statusMove?) && move.statusMove?
    rivales = @battler.battle.allOtherSideBattlers(@battler.index).select { |b| b && !b.fainted? }
    return "" if rivales.length != 1
    tipo = move.display_type(@battler)
    ef = Effectiveness.calculate(tipo, *rivales[0].pbTypes(true))
    return _INTL("No afecta") if Effectiveness.ineffective?(ef)
    return _INTL("Poco eficaz") if Effectiveness.not_very_effective?(ef)
    return _INTL("Supereficaz") if Effectiveness.super_effective?(ef)
    return _INTL("Eficaz")
  rescue StandardError
    return ""
  end

  def ost_dibujar(i)
    moves = (@battler) ? @battler.moves : []
    m = moves[i]
    hay = !!(m && m.id)
    b = @ostLetras[i].bitmap
    b.clear
    if hay
      t = ost_tipo(m)
      @ostPildora[i].bitmap = OstCombate.bmp("ataques/" + t)
      color = OST_BLANCO.include?(t) ? Color.new(255, 255, 255) : Color.new(35, 35, 35)
      OstCombate.letra(b, OstCombate::F_TITULO, 24)
      nombre = m.name.to_s
      # si no cabe hasta la parte negra, mas pequena
      cap = 24
      while cap > 16 && b.text_size(nombre).width > 300
        cap -= 1
        OstCombate.letra(b, OstCombate::F_TITULO, cap)
      end
      ef = ost_eficacia(m)
      # sin la linea de la eficacia (ataques de estado, o en dobles), el nombre en medio
      OstCombate.escribe(b, 98, ef.empty? ? 57 : 42, nombre, 0, 320, color)
      if !ef.empty?
        OstCombate.letra(b, OstCombate::F_ETIQUETA, 14)
        OstCombate.escribe(b, 99, 71, ef, 0, 300, color)
      end
      if m.total_pp > 0
        frac = m.pp.to_f / m.total_pp
        col = (m.pp == 0) ? Color.new(255, 90, 90) : (frac <= 0.25) ? Color.new(255, 160, 70) :
              (frac <= 0.5) ? Color.new(255, 225, 80) : Color.new(255, 255, 255)
        OstCombate.letra(b, OstCombate::F_TEXTO, 29)
        OstCombate.escribe(b, OST_PP_X - 100, 60, "#{m.pp}/#{m.total_pp}", 1, 200, col)
      end
    end
    ["pildora_#{i}", "letras_#{i}", "button_#{i}"].each do |k|
      @visibility[k] = hay
      @sprites[k].visible = @visible && hay if @sprites[k]
    end
  end

  alias ostcomb_refreshButtonNames refreshButtonNames
  def refreshButtonNames
    return ostcomb_refreshButtonNames if !@ost
    Pokemon::MAX_MOVES.times { |i| ost_dibujar(i) }
  end

  alias ostcomb_refreshSelection refreshSelection
  def refreshSelection
    return ostcomb_refreshSelection if !@ost
    Pokemon::MAX_MOVES.times { |i| ost_dibujar(i) }
    @ostFlecha.y = OST_Y[@index] + OST_FLECHA[1] if OST_Y[@index]
  end

  alias ostcomb_refreshMoveData refreshMoveData
  def refreshMoveData(move)
    return ostcomb_refreshMoveData(move) if !@ost
  end

  alias ostcomb_refreshMegaEvolutionButton refreshMegaEvolutionButton
  def refreshMegaEvolutionButton
    return ostcomb_refreshMegaEvolutionButton if !@ost
    ost_dibujar_mega
  end

  alias ostcomb_refreshShiftButton refreshShiftButton
  def refreshShiftButton
    return ostcomb_refreshShiftButton if !@ost
  end

  def update
    super
    return if !@ost || !@ostPildora
    Pokemon::MAX_MOVES.times do |i|
      sel = (i == @index)
      @ostZoom[i] += ((sel ? 1.035 : 1.0) - @ostZoom[i]) * 0.35
      @ostDx[i] += ((sel ? -10.0 : 0.0) - @ostDx[i]) * 0.35
      [@ostPildora[i], @ostLetras[i]].each do |s|
        next if !s || s.disposed?
        s.zoom_x = s.zoom_y = @ostZoom[i]
        s.x = OST_X + OST_W * OST_GIRO + @ostDx[i].round
      end
    end
    if @ostFlecha && !@ostFlecha.disposed?
      @ostFlecha.y = OST_Y[@index] + OST_FLECHA[1] if OST_Y[@index]
      @ostFlecha.opacity += (255 - @ostFlecha.opacity) * 0.35
    end
  end
end

#-------------------------------------------------------------------------------
# A quien se ataca (dobles): las mismas pildoras de los cuatro botones, una por
# Pokemon (primero los rivales, de izquierda a derecha, y luego los tuyos); la
# que se elige, negra. La pregunta, en la banda de los mensajes.
#-------------------------------------------------------------------------------
class Battle::Scene::TargetMenu
  attr_accessor :ost_quien     # el nombre del que ataca, para la pregunta
  attr_accessor :ost_nombres   # los de todos, para escribir en gris los que no se pueden elegir
  attr_reader   :ost_orden     # los indices de los Pokemon, de arriba abajo

  def ost_filas; return @ost_orden; end

  OST_ICONO_LADO = 80     # el icono de cada pildora, a la derecha del nombre
  OST_ICONO_X    = 287    # su centro dentro de la pildora

  # El icono de cada Pokemon, sacado de su sprite de frente (fijo): recortado
  # por lo dibujado y encogido hasta caber en OST_ICONO_LADO. Se guardan por
  # Pokemon mientras dura el combate.
  def ost_poner_iconos(battlers)
    @ost_iconos ||= {}
    @ost_icono_de = {}
    battlers.each_with_index do |bt, i|
      next if !bt || bt.fainted?
      pk = (bt.respond_to?(:displayPokemon) && bt.displayPokemon) || bt.pokemon
      next if !pk
      clave = [pk.species, pk.form, pk.shiny?, pk.gender]
      @ost_iconos[clave] ||= ost_hacer_icono(pk)
      @ost_icono_de[i] = @ost_iconos[clave]
    end
  end

  def ost_hacer_icono(pk)
    ab = GameData::Species.sprite_bitmap_from_pokemon(pk, false) rescue nil
    return nil if !ab
    bm = ab.bitmap
    x0 = bm.width; y0 = bm.height; x1 = -1; y1 = -1
    bm.height.times do |y|
      bm.width.times do |x|
        next if bm.get_pixel(x, y).alpha < 40
        x0 = x if x < x0; x1 = x if x > x1
        y0 = y if y < y0; y1 = y if y > y1
      end
    end
    if x1 < 0
      ab.dispose
      return nil
    end
    w = x1 - x0 + 1; h = y1 - y0 + 1
    k = [OST_ICONO_LADO.to_f / w, OST_ICONO_LADO.to_f / h].min
    dw = (w * k).round; dh = (h * k).round
    icono = Bitmap.new(OST_ICONO_LADO, OST_ICONO_LADO)
    icono.stretch_blt(Rect.new((OST_ICONO_LADO - dw) / 2, (OST_ICONO_LADO - dh) / 2, dw, dh),
                      bm, Rect.new(x0, y0, w, h))
    ab.dispose
    return icono
  end

  alias ostcomb_initialize initialize
  def initialize(viewport, z, sideSizes)
    @ost = OstCombate.activo? && sideSizes.max <= 2
    return ostcomb_initialize(viewport, z, sideSizes) if !@ost
    Battle::Scene::MenuBase.instance_method(:initialize).bind(self).call(viewport)
    @sideSizes = sideSizes
    @texts = []
    @mode = 0
    self.x = 0
    self.y = 0
    rivales = []
    propios = []
    (sideSizes.max * 2).times do |i|
      next if sideSizes[i % 2] <= i / 2
      x = Battle::Scene.pbBattlerPosition(i, sideSizes[i % 2])[0] rescue i
      (i.odd? ? rivales : propios).push([x, i])
    end
    @ost_orden = rivales.sort.map { |a| a[1] } + propios.sort.map { |a| a[1] }
    @ostZoom = {}
    @ostFondo = {}
    @ostLetras = {}
    @ostZona = Bitmap.new(Battle::Scene::CommandMenu::OST_W, Battle::Scene::CommandMenu::OST_H)
    banda = Sprite.new(viewport)
    banda.bitmap = OstCombate.bmp("banda_mensaje")
    banda.y = OstCombate::MENSAJE_Y
    addSprite("banda", banda)
    @ostPregunta = BitmapSprite.new(OstCombate::ANCHO, 144, viewport)
    @ostPregunta.y = OstCombate::MENSAJE_Y
    addSprite("pregunta", @ostPregunta)
    cm = Battle::Scene::CommandMenu
    maximo = (sideSizes[0] > sideSizes[1]) ? (sideSizes[0] - 1) * 2 : (sideSizes[1] * 2) - 1
    @buttons = Array.new(maximo + 1) do |i|
      fila = @ost_orden.index(i)
      next nil if !fila || !cm::OST_Y[fila]
      cx = cm::OST_X + cm::OST_W / 2.0
      cy = cm::OST_Y[fila] + cm::OST_H / 2.0
      f = Sprite.new(viewport)
      f.bitmap = OstCombate.bmp("boton")
      f.ox = cm::OST_PAD + cm::OST_W / 2.0
      f.oy = cm::OST_PAD + cm::OST_H / 2.0
      f.x = cx
      f.y = cy
      addSprite("fondo_#{i}", f)
      @ostFondo[i] = f
      l = Sprite.new(viewport)
      l.bitmap = Bitmap.new(cm::OST_W, cm::OST_H)
      l.ox = cm::OST_W / 2.0
      l.oy = cm::OST_H / 2.0
      l.x = cx
      l.y = cy
      addSprite("letras_#{i}", l)
      @ostLetras[i] = l
      @ostZoom[i] = 1.0
      s = Sprite.new(viewport)
      s.bitmap = @ostZona
      s.x = cm::OST_X
      s.y = cm::OST_Y[fila]
      s.opacity = 0
      addSprite("zona_#{i}", s)
      next s
    end
    self.z = z
    refresh
  end

  alias ostcomb_dispose dispose
  def dispose
    @ostLetras&.each_value { |l| l.bitmap.dispose if l && !l.disposed? && l.bitmap }
    ostcomb_dispose
    @ostZona&.dispose
    @ost_iconos&.each_value { |b| b.dispose if b && !b.disposed? }
  end

  alias ostcomb_z_set z=
  def z=(value)
    return ostcomb_z_set(value) if !@ost
    Battle::Scene::MenuBase.instance_method(:z=).bind(self).call(value)
    @sprites["banda"].z = value + 1 if @sprites["banda"]
    @ostPregunta.z = value + 2 if @ostPregunta
    @ostFondo&.each_value { |s| s.z = value + 1 }
    @ostLetras&.each_value { |s| s.z = value + 2 }
  end

  alias ostcomb_refresh refresh
  def refresh
    return ostcomb_refresh if !@ost
    b = @ostPregunta.bitmap
    b.clear
    quien = @ost_quien.to_s
    pregunta = quien.empty? ? _INTL("¿A quién?") : _INTL("¿A quién ataca {1}?", quien)
    OstCombate.letra(b, OstCombate::F_ETIQUETA, 30)
    OstCombate.escribe(b, 560, 86, pregunta, 0, 1300, Color.new(255, 255, 255))
    @ostFondo.each_key do |i|
      vale = !nil_or_empty?(@texts[i])
      nombre = vale ? @texts[i] : (@ost_nombres || [])[i]
      hay = !nil_or_empty?(nombre)
      sel = vale && (@mode == 1 || i == @index)
      @ostFondo[i].bitmap = OstCombate.bmp(sel ? "boton_sel" : "boton")
      l = @ostLetras[i].bitmap
      l.clear
      if hay
        OstCombate.letra(l, OstCombate::F_TITULO, 28)
        color = sel ? Color.new(255, 255, 255) : vale ? Color.new(35, 35, 35) : Color.new(160, 160, 160)
        OstCombate.escribe(l, 39, 64, nombre.to_s, 0, 200, color)
        ic = @ost_icono_de && @ost_icono_de[i]
        if ic && !ic.disposed?
          cm = Battle::Scene::CommandMenu
          l.blt(OST_ICONO_X - OST_ICONO_LADO / 2, (cm::OST_H - OST_ICONO_LADO) / 2, ic, ic.rect,
                vale ? 255 : 110)
        end
      end
      ["fondo_#{i}", "letras_#{i}", "zona_#{i}"].each do |k|
        @visibility[k] = hay
        @sprites[k].visible = @visible && hay if @sprites[k]
      end
    end
  end

  def update
    super
    return if !@ost || !@ostFondo
    @ostFondo.each_key do |i|
      sel = !nil_or_empty?(@texts[i]) && (@mode == 1 || i == @index)
      @ostZoom[i] += ((sel ? Battle::Scene::CommandMenu::OST_GRANDE : 1.0) - @ostZoom[i]) * 0.35
      [@ostFondo[i], @ostLetras[i]].each { |s| s.zoom_x = s.zoom_y = @ostZoom[i] if s && !s.disposed? }
    end
  end
end

#-------------------------------------------------------------------------------
# Los menus van en columna: arriba y abajo se mueven por las filas (la v21 los
# lleva en una rejilla de 2x2 con izquierda/derecha). Lo demas, igual que la v21.
#-------------------------------------------------------------------------------
class Battle::Scene
  def ost_fila_siguiente(cw, paso, valido = nil)
    filas = cw.ost_filas
    f = filas.index(cw.index) || 0
    loop do
      f += paso
      return cw.index if f < 0 || f >= filas.length
      i = filas[f]
      next if valido && !valido.call(i)
      return i
    end
  end

  # La fila de Poke Balls de la v21 al empezar contra un entrenador (encima de
  # la banda de "te desafia") no sale: el equipo ya va en las tiras de las fichas
  alias ostcomb_pbShowPartyLineup pbShowPartyLineup
  def pbShowPartyLineup(side, fullAnim = false)
    return if OstCombate.activo?
    ostcomb_pbShowPartyLineup(side, fullAnim)
  end

  alias ostcomb_pbCommandMenuEx pbCommandMenuEx
  def pbCommandMenuEx(idxBattler, texts, mode = 0)
    cw = @sprites["commandWindow"]
    return ostcomb_pbCommandMenuEx(idxBattler, texts, mode) if !OstCombate.activo? || !cw.respond_to?(:ost_filas)
    pbShowWindow(COMMAND_BOX)
    cw.setTexts(texts)
    cw.setIndexAndMode(@lastCmd[idxBattler], mode)
    pbSelectBattler(idxBattler)
    ret = -1
    mouseState = pbInitializeMouseState
    infoState = pbInitializeMouseState   # la barra "Y Info" (040)
    loop do
      oldIndex = cw.index
      pbUpdate(cw)
      if respond_to?(:ost_info_pedida?) && ost_info_pedida?(cw, infoState)
        ost_abrir_info(idxBattler)
        mouseState = pbInitializeMouseState
        infoState = pbInitializeMouseState
        next
      end
      if Input.trigger?(Input::UP)
        cw.index = ost_fila_siguiente(cw, -1, proc { |i| !nil_or_empty?(texts[i + 1]) })
      elsif Input.trigger?(Input::DOWN)
        cw.index = ost_fila_siguiente(cw, 1, proc { |i| !nil_or_empty?(texts[i + 1]) })
      end
      pbPlayCursorSE if cw.index != oldIndex
      clickedIndex = pbCheckMouseButtons(cw.buttons, mouseState)
      if clickedIndex
        cw.index = clickedIndex
        pbPlayDecisionSE
        ret = cw.index
        @lastCmd[idxBattler] = ret
        break
      end
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        ret = cw.index
        @lastCmd[idxBattler] = ret
        break
      elsif Input.trigger?(Input::BACK) && mode == 1
        pbPlayCancelSE
        break
      elsif Input.trigger?(Input::F9) && $DEBUG
        pbPlayDecisionSE
        ret = -2
        break
      end
    end
    return ret
  end

  alias ostcomb_pbFightMenu pbFightMenu
  def pbFightMenu(idxBattler, megaEvoPossible = false, &block)
    cw = @sprites["fightWindow"]
    return ostcomb_pbFightMenu(idxBattler, megaEvoPossible, &block) if !OstCombate.activo? || !cw.respond_to?(:ost_filas)
    battler = @battle.battlers[idxBattler]
    cw.battler = battler
    moveIndex = 0
    moveIndex = @lastMove[idxBattler] if battler.moves[@lastMove[idxBattler]]&.id
    cw.shiftMode = (@battle.pbCanShift?(idxBattler)) ? 1 : 0
    cw.setIndexAndMode(moveIndex, (megaEvoPossible) ? 1 : 0)
    needFullRefresh = true
    needRefresh = false
    mouseState = pbInitializeMouseState
    megaState = pbInitializeMouseState   # el del boton de mega: el de los ataques cuenta por indice
    loop do
      if needFullRefresh
        pbShowWindow(FIGHT_BOX)
        pbSelectBattler(idxBattler)
        needFullRefresh = false
      end
      if needRefresh
        if megaEvoPossible
          newMode = (@battle.pbRegisteredMegaEvolution?(idxBattler)) ? 2 : 1
          cw.mode = newMode if newMode != cw.mode
          cw.refresh
        end
        needRefresh = false
      end
      oldIndex = cw.index
      pbUpdate(cw)
      if Input.trigger?(Input::UP)
        cw.index = ost_fila_siguiente(cw, -1, proc { |i| battler.moves[i]&.id })
      elsif Input.trigger?(Input::DOWN)
        cw.index = ost_fila_siguiente(cw, 1, proc { |i| battler.moves[i]&.id })
      end
      pbPlayCursorSE if cw.index != oldIndex
      clickedIndex = pbCheckMouseButtons(cw.buttons, mouseState, proc { |i| battler.moves[i]&.id })
      # el boton (provisional) de megaevolucionar, con el raton: como la tecla ACTION
      megaClick = false
      if megaEvoPossible && !clickedIndex && cw.respond_to?(:ost_mega) && cw.ost_mega
        megaClick = !!pbCheckMouseButtons([cw.ost_mega], megaState) rescue false
      end
      if megaClick
        pbPlayDecisionSE
        break if yield(-2)
        needFullRefresh = respond_to?(:fight_action_handler) ? fight_action_handler(battler, idxBattler, cw) : true
        needRefresh = true
      elsif clickedIndex
        cw.index = clickedIndex
        pbPlayDecisionSE
        if yield cw.index
          break
        else
          needFullRefresh = true
          needRefresh = true
        end
      end
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        break if yield cw.index
        needFullRefresh = true
        needRefresh = true
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        fight_cancel_handler(battler, idxBattler, cw) if respond_to?(:fight_cancel_handler)
        break if yield(-1)
        needRefresh = true
      elsif Input.trigger?(Input::ACTION)
        if megaEvoPossible
          pbPlayDecisionSE
          break if yield(-2)
          needFullRefresh = respond_to?(:fight_action_handler) ? fight_action_handler(battler, idxBattler, cw) : true
          needRefresh = true
        end
      elsif Input.trigger?(Input::SPECIAL)
        if cw.shiftMode > 0
          pbPlayDecisionSE
          break if yield(-3)
          needRefresh = true
        end
      end
    end
    @lastMove[idxBattler] = cw.index
  end

  alias ostcomb_pbChooseTarget pbChooseTarget
  def pbChooseTarget(idxBattler, target_data, visibleSprites = nil)
    cw = @sprites["targetWindow"]
    if cw.respond_to?(:ost_quien=)
      cw.ost_quien = (@battle.battlers[idxBattler].name rescue nil)
      cw.ost_nombres = @battle.battlers.map { |bt| (bt && !bt.fainted?) ? bt.name : nil }
      begin
        cw.ost_poner_iconos(@battle.battlers)
      rescue StandardError => e
        echoln("OstCombate iconos: #{e.class}: #{e.message}")
      end
    end
    return ostcomb_pbChooseTarget(idxBattler, target_data, visibleSprites) if !OstCombate.activo? || !cw.respond_to?(:ost_filas) || !cw.ost_filas
    pbShowWindow(TARGET_BOX)
    texts = pbCreateTargetTexts(idxBattler, target_data)
    mode = (target_data.num_targets == 1) ? 0 : 1
    cw.setDetails(texts, mode)
    cw.index = pbFirstTarget(idxBattler, target_data)
    pbSelectBattler((mode == 0) ? cw.index : texts, 2)
    pbFadeInAndShow(@sprites, visibleSprites) if visibleSprites
    ret = -1
    mouseState = pbInitializeMouseState
    loop do
      oldIndex = cw.index
      pbUpdate(cw)
      clickedIndex = pbCheckMouseButtons(cw.buttons, mouseState, proc { |i| cw.buttons[i] && !texts[i].nil? })
      if clickedIndex
        cw.index = clickedIndex
        ret = cw.index
        pbPlayDecisionSE
        break
      end
      if mode == 0
        if Input.trigger?(Input::UP)
          cw.index = ost_fila_siguiente(cw, -1, proc { |i| !texts[i].nil? })
        elsif Input.trigger?(Input::DOWN)
          cw.index = ost_fila_siguiente(cw, 1, proc { |i| !texts[i].nil? })
        end
        if cw.index != oldIndex
          pbPlayCursorSE
          pbSelectBattler(cw.index, 2)
        end
      end
      if Input.trigger?(Input::USE)
        ret = cw.index
        pbPlayDecisionSE
        break
      elsif Input.trigger?(Input::BACK)
        ret = -1
        pbPlayCancelSE
        break
      end
    end
    pbSelectBattler(-1)
    return ret
  end
end

#-------------------------------------------------------------------------------
# El aviso de habilidad ("Torrente"): una banda blanca fina con el borde
# inclinado y una franja negra por el lado por el que entra; solo el nombre de
# la habilidad. El tuyo, encima de tu ficha; el del rival, debajo de la suya.
#-------------------------------------------------------------------------------
class Battle::Scene::AbilitySplashBar
  OST_PAD   = 24                 # el margen de la sombra en banda_*.png
  OST_ANCHO = 540
  OST_X     = [-24, 1356]        # donde se queda (con el margen de la sombra)
  OST_Y     = [814, 134]         # individuales (el del rival, debajo de la tira de su equipo)
  OST_Y2    = [758, 194]         # dobles: por encima / por debajo de las dos fichas y la tira

  alias ostcomb_initialize initialize
  def initialize(side, viewport = nil)
    ostcomb_initialize(side, viewport)
    @ost = OstCombate.activo?
    return if !@ost
    fondo = OstCombate.bmp((side == 0) ? "banda_propia" : "banda_rival")
    @bgSprite.bitmap = fondo
    @bgSprite.src_rect = Rect.new(0, 0, fondo.width, fondo.height)
    @bgSprite.mirror = false
    @contents.dispose
    @contents = Bitmap.new(fondo.width, fondo.height)
    self.bitmap = @contents
    # la animacion la mueve medio ancho de pantalla: asi acaba en su sitio
    self.x = (side == 0) ? OST_X[0] - Graphics.width / 2 : OST_X[1] + Graphics.width / 2
    self.y = OST_Y[side]
  end

  alias ostcomb_refresh refresh
  def refresh
    return ostcomb_refresh if !@ost
    self.bitmap.clear
    return if !@battler
    dobles = (@battler.battle.pbSideSize(@side) > 1) rescue false
    self.y = (dobles ? OST_Y2 : OST_Y)[@side]
    b = self.bitmap
    OstCombate.letra(b, OstCombate::F_TITULO, 28)
    OstCombate.escribe(b, OST_PAD + 64, OST_PAD + 46, @battler.abilityName.to_s,
                       (@side == 0) ? 0 : 2, OST_ANCHO - 128, Color.new(35, 35, 35))
  end
end

# La ventana de mensajes del combate se queda en la banda oscura
alias ostcomb_pbRepositionMessageWindow pbRepositionMessageWindow
def pbRepositionMessageWindow(msgwindow, linecount = 2)
  ostcomb_pbRepositionMessageWindow(msgwindow, linecount)
  s = msgwindow.instance_variable_get(:@ost_sitio)
  return if !s || !OstCombate.activo?
  msgwindow.x, msgwindow.y, msgwindow.width, msgwindow.height = s
end

#-------------------------------------------------------------------------------
# El equipo y la mochila desde el combate. El combate no los abre con
# pbFadeOutIn sino fundiendo sus propios sprites (pbFadeOutAndHide), asi que
# no pasaban por OstUI y se abrian a 1920 rotos. Aqui: en cuanto el combate
# queda a negro se baja a la resolucion normal con las bandas de 512, y se
# vuelve a subir justo antes de que reaparezca.
#-------------------------------------------------------------------------------
module OstCombate
  def self.bajar_un_momento
    return false if !@activo || !@antes
    OstinatoHD.bajar(@antes)
    @activo = false
    @temporal = true
    OstUI.entrar
    return true
  end

  def self.volver
    @temporal = false
    OstUI.salir
    @antes = OstinatoHD.subir
    @activo = true
  end
end

module OstUI
  def self.entrar
    return if ancho_real <= ANCHO
    poner_bandas if @nivel == 0
    @nivel += 1
  end

  def self.salir
    return if @nivel <= 0
    @nivel -= 1
    quitar_bandas if @nivel == 0
  end
end

class Battle::Scene
  def pbFadeOutAndHide(sprites)
    r = super
    @ost_abajo = (@ost_abajo || 0) + 1 if OstCombate.bajar_un_momento
    return r
  end

  def pbFadeInAndShow(sprites, visiblesprites = nil)
    if @ost_abajo && @ost_abajo > 0
      @ost_abajo -= 1
      OstCombate.volver
    end
    return visiblesprites ? super(sprites, visiblesprites) : super(sprites)
  end
end

#-------------------------------------------------------------------------------
# La entrada al combate: la v21 funde un negro de 512x384 y deja una barra
# negra donde iba su barra de mensajes. A 1920 el negro solo tapaba un trozo
# de la pantalla y la barra se quedaba encima de la nuestra: aqui el negro
# tapa la pantalla entera y la barra no sale.
#-------------------------------------------------------------------------------
class Battle::Scene::Animation::Intro
  def addNewSprite(x, y, name, origin = PictureOrigin::TOP_LEFT)
    pic = super
    return pic if !OstCombate.activo? || !name.to_s.include?("black_")
    if name.to_s.include?("black_bar")
      pic.setOpacity(0, 0)
    else
      b = @pictureSprites[@pictureSprites.length - 1].bitmap
      if b && b.width > 0
        pic.setZoomXY(0, 100.0 * Graphics.width / b.width + 1, 100.0 * Graphics.height / b.height + 1)
      end
    end
    return pic
  end
end

#-------------------------------------------------------------------------------
# Las animaciones de los ataques calculan el centro del Pokemon con su zoom.
# Nuestros Pokemon dicen tener zoom 1 (para que las animaciones no los
# encojan), asi que aqui se usa el zoom real: si no, el Pokemon se dibujaba
# mas abajo durante cada ataque y se salia por abajo.
#-------------------------------------------------------------------------------
alias ostcomb_getSpriteCenter getSpriteCenter
def getSpriteCenter(sprite)
  return ostcomb_getSpriteCenter(sprite) if !sprite || !sprite.respond_to?(:ost_k)
  return [0, 0] if sprite.disposed?
  return [sprite.x, sprite.y] if !sprite.bitmap || sprite.bitmap.disposed?
  k = sprite.ost_k
  cx = sprite.src_rect.width / 2
  cy = sprite.src_rect.height / 2
  return [sprite.x + (cx - sprite.ox) * sprite.zoom_x * k,
          sprite.y + (cy - sprite.oy) * sprite.zoom_y * k]
end

# Y la linea entre atacante y objetivo, que usa la mitad del alto del dibujo:
# con los Pokemon ampliados, la mitad del alto ampliado. Si no, el objetivo
# bajaba de golpe en cada ataque.
class PBAnimationPlayerX
  alias ostcomb_setLineTransform setLineTransform
  def setLineTransform(x1, y1, x2, y2, x3, y3, x4, y4)
    if OstCombate.activo?
      [[@usersprite, :u], [@targetsprite, :t]].each do |s, q|
        next if !s || !s.bitmap || s.bitmap.disposed? || !s.respond_to?(:ost_k)
        k = s.ost_k
        extra = s.bitmap.height * (k - 1) / 2.0
        q == :u ? (y3 -= extra) : (y4 -= extra)
      end
    end
    ostcomb_setLineTransform(x1, y1, x2, y2, x3, y3, x4, y4)
  end
end

#-------------------------------------------------------------------------------
# El ultimo mensaje ("Has ganado 40$ por vencer") se queda esperando a que
# pulses, y con el se quedaba el recuadro hasta salir del combate. Aqui se
# lee un momento, se cierra solo y el recuadro se quita.
#-------------------------------------------------------------------------------
class Battle
  alias ostcomb_pbGainMoney pbGainMoney
  def pbGainMoney
    return ostcomb_pbGainMoney if !OstCombate.activo?
    @ost_sin_pausa = true
    begin
      ostcomb_pbGainMoney
    ensure
      @ost_sin_pausa = false
    end
    @scene.pbShowWindow(Battle::Scene::BLANK) rescue nil
  end

  alias ostcomb_pbDisplayPaused pbDisplayPaused
  def pbDisplayPaused(msg, &block)
    return ostcomb_pbDisplayPaused(msg, &block) if !@ost_sin_pausa
    pbDisplay(msg, &block)
    # un poco mas que el resto de mensajes, para que se lea
    t = System.uptime
    @scene.pbUpdate while System.uptime - t < 0.6
  end
end

#-------------------------------------------------------------------------------
# Entrenadores que son dos personas con un solo picture (OkarPalace y Damian):
# los mensajes del combate hablan de ellos en plural ("te desafian",
# "sacan a"...). El verbo que va justo detras del nombre gana una "n".
#-------------------------------------------------------------------------------
module OstCombate
  PAREJAS = [:COLEGAS, :HERMANOS_CAMPISTAS]
  PRONOMBRES = "(?:te|le|les|se|lo|la|os|nos)"

  def self.plural(battle, msg)
    return msg if !msg.is_a?(String) || !battle.opponent
    battle.opponent.each do |t|
      next if !t || !PAREJAS.include?(t.trainer_type)
      nombre = Regexp.escape(t.full_name)
      msg = msg.gsub(/(#{nombre}(?:\s+#{PRONOMBRES})?\s+)([[:alpha:]]+[aeá])(?![[:alpha:]])/) { $1 + $2 + "n" }
    end
    return msg
  end
end

class Battle
  [:pbDisplay, :pbDisplayBrief, :pbDisplayPaused, :pbDisplayConfirm].each do |m|
    alias_method :"ostpareja_#{m}", m
    define_method(m) do |msg, *args, &block|
      send(:"ostpareja_#{m}", OstCombate.plural(self, msg), *args, &block)
    end
  end
end
