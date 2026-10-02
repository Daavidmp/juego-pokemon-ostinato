#===============================================================================
# Pokemon Ostinato - El combate a pantalla completa (1920x1080) con la
# interfaz nueva (rojo, negro y blanco, con tramas y manchas de tinta)
#
#   Mientras dura el combate la pantalla sube a 1920x1080 (OstinatoHD), en vez
#   de ir en el recuadro de 512 centrado (008_Pantallas512). Lo que se abre
#   desde el combate (mochila, equipo) baja un momento a la resolucion normal
#   y se ve como siempre.
#
#   La escena: los fondos de combate se amplian para llenar el ancho si son
#   pequenos (los de 1920x1080 van tal cual), y los Pokemon y entrenadores se
#   amplian ESCALA veces, un numero entero para que el pixel se vea limpio.
#
#   La interfaz: piezas en Graphics/UI/Ostinato/Combate/ sacadas de las
#   maquetas de Firefly (Descargas\interfaz_combate): las fichas, la barra de
#   mensaje, la de los cuatro botones y la de ataques, el boton seleccionado,
#   los botones de ataque de cada tipo (ataques/ataque_TIPO.png) y los iconos
#   de tipo (tipos/TIPO.png). El texto se escribe encima con la fuente Bangers
#   (Fonts/Bangers-Regular.ttf, licencia OFL).
#
#   Todas las medidas estan en la pantalla de 1920x1080.
#===============================================================================
module OstCombate
  DIR    = "Graphics/UI/Ostinato/Combate/"
  FUENTE = "Bangers"
  ESCALA = 3                 # Pokemon y entrenadores (sus PNG ya van a x2)
  BASE_ESCALA = 3            # las bases de los fondos antiguos de 512
  ANCHO  = 1920
  ALTO   = 1080
  BARRA_Y = ALTO - 282       # donde empieza la barra de ataques
  BARRA2_Y = ALTO - 346      # la barra de mensaje y botones (con sus manchas por arriba)

  # centro de los pies de cada lado (como las bases de la v21)
  PROPIO = [554, 735]        # entero, de pie en el centro de su losa
  RIVAL  = [1374, 418]

  @activo = false
  def self.activo?; return @activo; end

  def self.con
    return yield if @activo
    antes = OstinatoHD.subir
    @antes = antes
    @activo = true
    begin
      return yield
    ensure
      if @temporal
        # el combate acabo con la pantalla ya bajada (el fundido final)
        OstUI.salir
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

  # [centro x, centro y, ancho] de las losas: los ovalos de estilo_elegido.png
  LOSAS = [[554, 814, 760], [1374, 407, 690]]   # la propia: y = su borde de abajo, apoyado en la barra

  # Un ovalo de pixel (se amplia despues): borde oscuro, filo y relleno
  def self.ovalo(w, h, relleno, filo, borde)
    b = Bitmap.new(w, h)
    a = w / 2.0
    c = h / 2.0
    [[0, borde], [1, filo], [3, relleno]].each do |m, col|
      h.times do |y|
        yy = (y + 0.5 - c) / (c - m)
        next if yy.abs >= 1
        hw = (a - m) * Math.sqrt(1 - yy * yy)
        b.fill_rect((a - hw).round, y, (2 * hw).round, 1, col)
      end
    end
    return b
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

  def self.fuente(bitmap, tam)
    bitmap.font.name = FUENTE
    bitmap.font.size = tam
    bitmap.font.bold = false
    bitmap.font.italic = false
    begin
      bitmap.font.outline = false
      bitmap.font.shadow = false
    rescue
    end
  end

  # Texto con un contorno grueso (se dibuja varias veces desplazado)
  def self.texto(bitmap, x, y, w, h, txt, alin = 0, color = Color.new(255, 255, 255),
                 borde = nil, grosor = 3)
    if borde
      c = bitmap.font.color
      bitmap.font.color = borde
      (-grosor..grosor).step(grosor) do |dx|
        (-grosor..grosor).step(grosor) do |dy|
          next if dx == 0 && dy == 0
          bitmap.draw_text(x + dx, y + dy, w, h, txt, alin)
        end
      end
      bitmap.font.color = c
    end
    bitmap.font.color = color
    bitmap.draw_text(x, y, w, h, txt, alin)
  end

  # Parte un texto en lineas que quepan en ancho
  def self.lineas(bitmap, txt, ancho)
    ret = []
    txt.to_s.split("\n").each do |parrafo|
      actual = ""
      parrafo.split(" ").each do |p|
        prueba = actual.empty? ? p : actual + " " + p
        if bitmap.text_size(prueba).width > ancho && !actual.empty?
          ret.push(actual)
          actual = p
        else
          actual = prueba
        end
      end
      ret.push(actual) if !actual.empty?
    end
    return ret
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
      ret = ((index & 1) == 0) ? OstCombate::PROPIO.clone : OstCombate::RIVAL.clone
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
        # Kaia va cortada por la cintura: su borde de abajo, escondido tras la barra
        ret = [OstCombate::PROPIO[0] - 40, OstCombate::BARRA2_Y + 110]
      else
        ret = [OstCombate::RIVAL[0], OstCombate::RIVAL[1] + TRAINER_FOE_OFFSET_Y * k]
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
      # Las losas, cuadradas con la interfaz: del tamano y en el sitio de los
      # ovalos de la maqueta, con el Pokemon de pie en su centro. La propia de
      # los fondos de 512 esta cortada por abajo (la tapaba la barra vieja):
      # se completa con su reflejo.
      2.times do |side|
        base = @sprites["base_#{side}"]
        next if !base || !base.bitmap
        bm = base.bitmap
        x0, y0, x1, y1 = OstCombate.caja(bm)
        if side == 0 && y1 >= bm.height - 2
          # se dibuja un ovalo entero con sus colores (relleno, filo y borde)
          relleno = bm.get_pixel((x0 + x1) / 2, y1 - 2)
          filo    = bm.get_pixel((x0 + x1) / 2, y0 + 3)
          borde   = bm.get_pixel((x0 + x1) / 2, y0)
          entero = OstCombate.ovalo(290, 66, relleno, filo, borde)
          base.bitmap = entero
          bm = entero
          x0, y0, x1, y1 = 0, 0, bm.width - 1, bm.height - 1
        end
        ancho = OstCombate::LOSAS[side][2]
        bz = ancho.to_f / [x1 - x0 + 1, 1].max
        base.zoom_x = bz
        base.zoom_y = bz
        base.ox = (x0 + x1) / 2
        # la animacion de entrada coloca la propia por su borde de abajo
        base.oy = (side == 0) ? y1 + 1 : (y0 + y1) / 2
        base.x = OstCombate::LOSAS[side][0]
        base.y = OstCombate::LOSAS[side][1]
      end
    end
    @sprites["cmdBar_bg"].visible = false if @sprites["cmdBar_bg"]
    @sprites["cmdBar_bg"].opacity = 0 if @sprites["cmdBar_bg"]
  end

  # La barra de mensaje y la ventana del texto
  alias ostcomb_pbInitSprites pbInitSprites
  def pbInitSprites
    ostcomb_pbInitSprites
    return if !OstCombate.activo?
    box = @sprites["messageBox"]
    if box
      # con setBitmap: al refrescarse (al volver del equipo) no vuelve al de 512
      box.setBitmap(OstCombate::DIR + "barra_mensaje")
      box.x = 0
      box.y = OstCombate::BARRA2_Y
    end
    w = @sprites["messageWindow"]
    if w
      w.x = 92
      w.y = OstCombate::BARRA2_Y + 128
      w.width = 1030
      w.height = 200
      w.baseColor = Color.new(20, 20, 20)
      w.shadowColor = Color.new(200, 200, 200)
      if w.contents
        OstCombate.fuente(w.contents, 50)
        w.contents.font.color = Color.new(20, 20, 20)
      end
      w.lineHeight = 60 if w.respond_to?(:lineHeight=)
      # pbMessageDisplay la vuelve a pegar abajo: se le guarda su sitio
      w.instance_variable_set(:@ost_sitio, [w.x, w.y, w.width, w.height])
      # la ventana vuelve a la fuente del sistema al cambiar de texto: se le
      # pone la grande justo antes de cada mensaje
      def w.setText(value)
        OstCombate.fuente(self.contents, 50) if self.contents && !self.contents.disposed?
        @oldfont = nil
        super
      end
    end
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
      s.zoom_x = OstCombate::ESCALA
      s.zoom_y = OstCombate::ESCALA
    end
  end
end

#-------------------------------------------------------------------------------
# Pokemon y sus sombras, ampliados (las animaciones siguen viendo su zoom 1)
#-------------------------------------------------------------------------------
module OstCombateZoom
  def ost_k
    return (OstCombate.activo?) ? OstCombate::ESCALA : 1
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
    k = OstCombate::ESCALA
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
  end
end

class Battle::Scene::BattlerShadowSprite
  prepend OstCombateZoom
  alias ostcomb_pbSetPosition pbSetPosition
  def pbSetPosition
    ostcomb_pbSetPosition
    ost_escalar_posicion if @_iconBitmap
  end
end

#-------------------------------------------------------------------------------
# Las fichas
#-------------------------------------------------------------------------------
class Battle::Scene::PokemonDataBox
  # [x, y] de la ficha y, dentro, todo lo demas
  # (medido sobre las piezas de Descargas\interfaz_combate\piezas2, colocadas
  # como en estilo_elegido.png)
  OST_RIVAL = { :pos => [79, 13], :fondo => "ficha_rival",
                :nombre => [60, 70, 370, 84], :nivel => [470, 76, 200, 84],
                :nivel_texto => "Lv.%d", :nivel_alin => 1,
                :vida => [322, 200, 312, 34], :bloques => 8, :estado => [70, 150],
                :bolitas => [137, 280, 58], :flecha => [61, 340] }
  OST_PROPIA = { :pos => [1112, 474], :fondo => "ficha_propia",
                 :nombre => [112, 40, 390, 84], :nivel => [604, 48, 130, 84],
                 :nivel_texto => "%d", :nivel_alin => 0,
                 :vida => [382, 140, 298, 26], :numeros => [400, 178, 280, 66],
                 :exp => [258, 272, 394, 11], :estado => [110, 200] }
  OST_COLORES = [Color.new(70, 200, 80), Color.new(250, 200, 40),
                 Color.new(250, 130, 30), Color.new(230, 40, 40)]

  alias ostcomb_initialize initialize
  def initialize(battler, sideSize, viewport = nil)
    @ost = OstCombate.activo?
    ostcomb_initialize(battler, sideSize, viewport)
  end

  def ost_datos
    return (@battler.index.even?) ? OST_PROPIA : OST_RIVAL
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
    # en dobles, una ficha debajo de otra
    paso = (@battler.index.even?) ? -150 : 150
    @spriteY += (@battler.index / 2) * paso if sideSize > 1
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
    OstCombate.fuente(@hpNumbers.bitmap, 52)
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
    # el rival: las bolitas de su equipo y la flecha, debajo de la ficha
    if d[:bolitas]
      @ostLinea = Sprite.new(viewport)
      @ostLinea.bitmap = Bitmap.new(720, 420)
      @sprites["ostLinea"] = @ostLinea
    end
    @contents = Bitmap.new(@databoxBitmap.width, @databoxBitmap.height)
    self.bitmap  = @contents
    self.visible = false
    self.z       = DATABOX_BASE_Z + ((@battler.index / 2) * 5)
    OstCombate.fuente(self.bitmap, 64)
  end

  alias ostcomb_dispose dispose
  def dispose
    @ostExp&.dispose
    @ostLinea.bitmap.dispose if @ostLinea && !@ostLinea.disposed? && @ostLinea.bitmap
    ostcomb_dispose
  end

  alias ostcomb_x_set x=
  def x=(value)
    return ostcomb_x_set(value) if !@ost
    Sprite.instance_method(:x=).bind(self).call(value)
    d = ost_datos
    @hpBar.x = value + d[:vida][0]
    @expBar.x = value + (d[:exp] ? d[:exp][0] : 0)
    @hpNumbers.x = value + (d[:numeros] ? d[:numeros][0] : 0)
    @hpPercent.x = value
    @ostLinea.x = value if @ostLinea
  end

  alias ostcomb_y_set y=
  def y=(value)
    return ostcomb_y_set(value) if !@ost
    Sprite.instance_method(:y=).bind(self).call(value)
    d = ost_datos
    @hpBar.y = value + d[:vida][1]
    @expBar.y = value + (d[:exp] ? d[:exp][1] : 0)
    @hpNumbers.y = value + (d[:numeros] ? d[:numeros][1] : 0)
    @hpPercent.y = value
    @ostLinea.y = value if @ostLinea
  end

  alias ostcomb_refresh refresh
  def refresh
    return ostcomb_refresh if !@ost
    self.bitmap.clear
    return if !@battler.pokemon
    d = ost_datos
    self.bitmap.blt(0, 0, @databoxBitmap.bitmap, Rect.new(0, 0, @databoxBitmap.width, @databoxBitmap.height))
    b = self.bitmap
    # nombre: blanco con contorno negro, sobre el rojo
    n = d[:nombre]
    OstCombate.fuente(b, 64)
    nombre = @battler.name
    OstCombate.texto(b, n[0], n[1], n[2], n[3], nombre.upcase, 0,
                     Color.new(255, 255, 255), Color.new(0, 0, 0), 3)
    # nivel: negro sobre el blanco
    l = d[:nivel]
    OstCombate.fuente(b, 66)
    OstCombate.texto(b, l[0], l[1], l[2], l[3], format(d[:nivel_texto], @battler.level), d[:nivel_alin],
                     Color.new(20, 20, 20))
    ost_bolitas
    # estado (el icono de la v21, ampliado)
    if @battler.status != :NONE
      begin
        if @battler.status == :POISON && @battler.statusCount > 0
          s = GameData::Status.count - 1
        else
          s = GameData::Status.get(@battler.status).icon_position
        end
        if s >= 0
          ic = Bitmap.new("Graphics/UI/Battle/icon_statuses")
          e = d[:estado]
          b.stretch_blt(Rect.new(e[0], e[1], ic.width * 3, STATUS_ICON_HEIGHT * 3), ic,
                        Rect.new(0, s * STATUS_ICON_HEIGHT, ic.width, STATUS_ICON_HEIGHT))
          ic.dispose
        end
      rescue
      end
    end
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
      OstCombate.fuente(@hpNumbers.bitmap, 52)
      OstCombate.texto(@hpNumbers.bitmap, 0, 0, d[:numeros][2], d[:numeros][3],
                       "#{self.hp.round}/ #{@battler.totalhp}", 2, Color.new(255, 255, 255), Color.new(0, 0, 0), 3)
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
    claro = Color.new([col.red + 50, 255].min, [col.green + 50, 255].min, [col.blue + 50, 255].min)
    if d[:bloques]
      # el rival: la vida en bloques, como en la maqueta; los vacios, grises
      n = d[:bloques]
      hueco = 6
      bw = (v[2] - hueco * (n - 1)) / n
      llenos = (self.hp <= 0) ? 0 : [(n * self.hp.to_f / @battler.totalhp).ceil, 1].max
      n.times do |k|
        x = k * (bw + hueco)
        c = (k < llenos) ? col : Color.new(70, 70, 70)
        @hpBarDisplay.fill_rect(x, 0, bw, v[3], c)
        @hpBarDisplay.fill_rect(x, 0, bw, [v[3] / 4, 2].max, claro) if k < llenos
      end
      @hpBar.src_rect.width = v[2]
    else
      @hpBarDisplay.fill_rect(0, 0, v[2], v[3], col)
      @hpBarDisplay.fill_rect(0, 0, v[2], [v[3] / 4, 2].max, claro)
      @hpBar.src_rect.width = w
    end
  end

  alias ostcomb_databox_z_set z=
  def z=(value)
    ostcomb_databox_z_set(value)
    @ostLinea.z = 40 if @ostLinea && !@ostLinea.disposed?   # por detras de los Pokemon
  end

  def ost_bolitas
    return if !@ostLinea || @ostLinea.disposed?
    @ostLinea.z = 40
    d = ost_datos
    b = @ostLinea.bitmap
    b.clear
    f = OstCombate.bmp("flecha")
    b.stretch_blt(Rect.new(d[:flecha][0], d[:flecha][1], 400, f.height), f, f.rect)   # mas corta: no llega a tu Pokemon
    equipo = []
    begin
      equipo = @battler.battle.pbParty(@battler.index)
    rescue
    end
    bx, by, paso = d[:bolitas]
    lado = 50
    6.times do |i|
      pk = equipo[i]
      if pk && !pk.egg?
        bm = OstCombate.bmp(pk.fainted? ? "bolita_gris" : "bolita")
        b.stretch_blt(Rect.new(bx + i * paso, by, lado, lado), bm, bm.rect)
      else
        bm = OstCombate.bmp("bolita_gris")
        b.stretch_blt(Rect.new(bx + i * paso, by, lado, lado), bm, bm.rect, 90)
      end
    end
  end

  alias ostcomb_refresh_exp refresh_exp
  def refresh_exp
    return ostcomb_refresh_exp if !@ost
    return if !@show_exp_bar || !ost_datos[:exp]
    @expBar.src_rect.width = (exp_fraction * ost_datos[:exp][2]).round
  end
end

#-------------------------------------------------------------------------------
# Los cuatro botones (Luchar, Mochila, Pokemon, Huir)
#-------------------------------------------------------------------------------
class Battle::Scene::CommandMenu
  OST_BOTONES = [[1402, 879], [1738, 882], [1400, 1006], [1741, 1010]]
  OST_ICONOS  = ["icono_luchar", "icono_mochila", "icono_pokemon", "icono_huir"]

  alias ostcomb_initialize initialize
  def initialize(viewport, z)
    @ost = OstCombate.activo?
    return ostcomb_initialize(viewport, z) if !@ost
    Battle::Scene::MenuBase.instance_method(:initialize).bind(self).call(viewport)
    self.x = 0
    self.y = OstCombate::BARRA2_Y
    @textos = []
    fondo = Sprite.new(viewport)
    fondo.bitmap = OstCombate.bmp("barra")
    fondo.y = OstCombate::BARRA2_Y
    addSprite("fondo", fondo)
    @ostSel = Sprite.new(viewport)
    @ostSel.bitmap = OstCombate.bmp("boton_sel")
    @ostSel.ox = @ostSel.bitmap.width / 2
    @ostSel.oy = @ostSel.bitmap.height / 2
    addSprite("sel", @ostSel)
    @ostTexto = BitmapSprite.new(OstCombate::ANCHO, 346, viewport)
    @ostTexto.y = OstCombate::BARRA2_Y
    addSprite("texto", @ostTexto)
    # zonas para el raton (invisibles)
    @ostZona = Bitmap.new(320, 110)
    @buttons = Array.new(4) do |i|
      s = Sprite.new(viewport)
      s.bitmap = @ostZona
      s.x = OST_BOTONES[i][0] - 160
      s.y = OST_BOTONES[i][1] - 55
      s.opacity = 0
      addSprite("zona_#{i}", s)
      next s
    end
    self.z = z
    refresh
  end

  alias ostcomb_dispose dispose
  def dispose
    ostcomb_dispose
    @ostZona&.dispose
  end

  alias ostcomb_z_set z=
  def z=(value)
    return ostcomb_z_set(value) if !@ost
    Battle::Scene::MenuBase.instance_method(:z=).bind(self).call(value)
    @ostSel.z = value + 1
    @ostTexto.z = value + 2
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
    p = OST_BOTONES[@index] || OST_BOTONES[0]
    @ostSel.x = p[0]
    @ostSel.y = p[1]
    b = @ostTexto.bitmap
    b.clear
    # la pregunta, en el panel blanco
    if @textos[0]
      OstCombate.fuente(b, 56)
      OstCombate.lineas(b, @textos[0].to_s.gsub("\n", " "), 980).each_with_index do |linea, i|
        OstCombate.texto(b, 92, 124 + i * 64, 1000, 64, linea, 0, Color.new(20, 20, 20))
      end
    end
    # cada boton: su palabra y su icono, en negro (como en la maqueta)
    OstCombate.fuente(b, 62)
    4.times do |i|
      t = @textos[i + 1]
      next if !t
      q = OST_BOTONES[i]
      ty = q[1] - OstCombate::BARRA2_Y
      txt = t.to_s.upcase
      ic = OstCombate.bmp(OST_ICONOS[i])
      ancho = b.text_size(txt).width + 14 + ic.width
      x0 = q[0] - ancho / 2
      OstCombate.texto(b, x0, ty - 36, ancho, 72, txt, 0, Color.new(15, 15, 15))
      b.blt(x0 + ancho - ic.width, ty - ic.height / 2, ic, ic.rect)
    end
  end
end

#-------------------------------------------------------------------------------
# Los ataques
#-------------------------------------------------------------------------------
class Battle::Scene::FightMenu
  OST_BOTONES = [[268, 894], [670, 894], [262, 1006], [666, 1006]]
  OST_CIRCULO = [68, 49]           # el hueco del icono, dentro del boton
  OST_PP      = [931, 864, 255, 164]
  OST_DESC    = [1268, 858, 612, 196]

  alias ostcomb_initialize initialize
  def initialize(viewport, z)
    @ost = OstCombate.activo?
    return ostcomb_initialize(viewport, z) if !@ost
    Battle::Scene::MenuBase.instance_method(:initialize).bind(self).call(viewport)
    self.x = 0
    self.y = OstCombate::BARRA_Y
    @battler   = nil
    @shiftMode = 0
    fondo = Sprite.new(viewport)
    fondo.bitmap = OstCombate.bmp("barra_ataques")
    fondo.y = OstCombate::BARRA_Y
    addSprite("background", fondo)
    @buttons = Array.new(Pokemon::MAX_MOVES) do |i|
      s = Sprite.new(viewport)
      s.bitmap = OstCombate.bmp("ataques/ataque_NORMAL")
      s.ox = s.bitmap.width / 2
      s.oy = s.bitmap.height / 2
      s.x = OST_BOTONES[i][0]
      s.y = OST_BOTONES[i][1]
      addSprite("button_#{i}", s)
      next s
    end
    @ostIconos = Array.new(Pokemon::MAX_MOVES) do |i|
      s = Sprite.new(viewport)
      s.bitmap = OstCombate.bmp("tipos/NORMAL")
      s.ox = s.bitmap.width / 2
      s.oy = s.bitmap.height / 2
      s.zoom_x = s.zoom_y = 0.84
      addSprite("icono_#{i}", s)
      next s
    end
    @overlay = BitmapSprite.new(OstCombate::ANCHO, 282, viewport)
    @overlay.y = OstCombate::BARRA_Y
    addSprite("overlay", @overlay)
    @infoOverlay = BitmapSprite.new(OstCombate::ANCHO, 282, viewport)
    @infoOverlay.y = OstCombate::BARRA_Y
    addSprite("infoOverlay", @infoOverlay)
    self.z = z
  end

  alias ostcomb_z_set z=
  def z=(value)
    return ostcomb_z_set(value) if !@ost
    Battle::Scene::MenuBase.instance_method(:z=).bind(self).call(value)
    @buttons.each { |s| s.z = value + 1 }
    @ostIconos.each { |s| s.z = value + 2 }
    @overlay.z = value + 3
    @infoOverlay.z = value + 3
  end

  def ost_colocar
    @buttons.each_with_index do |s, i|
      sel = (i == @index)
      dx = sel ? 14 : 0
      s.x = OST_BOTONES[i][0] + dx
      s.y = OST_BOTONES[i][1] - (sel ? 4 : 0)
      s.tone = sel ? Tone.new(30, 30, 30) : Tone.new(-55, -55, -55, 60)
      s.zoom_x = s.zoom_y = sel ? 1.06 : 1.0
      s.opacity = (@ostVacio && @ostVacio[i]) ? 110 : 255
      ic = @ostIconos[i]
      ic.x = s.x - s.ox + OST_CIRCULO[0]
      ic.y = s.y - s.oy + OST_CIRCULO[1]
      ic.visible = @visible && @visibility["button_#{i}"] && !(@ostVacio && @ostVacio[i])
      @visibility["icono_#{i}"] = @visibility["button_#{i}"] && !(@ostVacio && @ostVacio[i])
    end
  end

  alias ostcomb_refreshButtonNames refreshButtonNames
  def refreshButtonNames
    return ostcomb_refreshButtonNames if !@ost
    moves = (@battler) ? @battler.moves : []
    b = @overlay.bitmap
    b.clear
    OstCombate.fuente(b, 46)
    @buttons.each_with_index do |s, i|
      next if !moves[i]
      x = OST_BOTONES[i][0] + ((i == @index) ? 10 : 0)
      y = OST_BOTONES[i][1] - OstCombate::BARRA_Y
      OstCombate.texto(b, x - 100, y - 30, 280, 60, moves[i].name.upcase, 1,
                       Color.new(255, 255, 255), Color.new(0, 0, 0), 3)
    end
  end

  alias ostcomb_refreshSelection refreshSelection
  def refreshSelection
    return ostcomb_refreshSelection if !@ost
    moves = (@battler) ? @battler.moves : []
    @buttons.each_with_index do |s, i|
      @ostVacio ||= []
      if !moves[i]
        # hueco sin ataque: el boton gris y apagado, sin icono
        @ostVacio[i] = true
        @visibility["button_#{i}"] = true
        s.visible = @visible
        s.bitmap = OstCombate.bmp("ataques/ataque_NORMAL")
        next
      end
      @ostVacio[i] = false
      @visibility["button_#{i}"] = true
      s.visible = @visible
      t = OstCombate.tipo_id(moves[i].display_type(@battler))
      s.bitmap = OstCombate.bmp("ataques/ataque_#{t}")
      @ostIconos[i].bitmap = OstCombate.bmp("tipos/#{t}")
    end
    ost_colocar
    refreshButtonNames
    refreshMoveData(moves[@index])
  end

  alias ostcomb_refreshMoveData refreshMoveData
  def refreshMoveData(move)
    return ostcomb_refreshMoveData(move) if !@ost
    b = @infoOverlay.bitmap
    b.clear
    return if !move
    yb = OstCombate::BARRA_Y
    # PP y tipo, en blanco sobre la caja negra
    pp = OST_PP
    OstCombate.fuente(b, 50)
    if move.total_pp > 0
      frac = move.pp.to_f / move.total_pp
      col = (move.pp == 0) ? Color.new(255, 80, 80) : (frac <= 0.25) ? Color.new(255, 150, 60) :
            (frac <= 0.5) ? Color.new(255, 220, 60) : Color.new(255, 255, 255)
      OstCombate.texto(b, pp[0], pp[1] - yb + 18, pp[2], 60, "PP  #{move.pp}/#{move.total_pp}", 1, col)
    end
    tipo = GameData::Type.get(move.display_type(@battler)).name rescue ""
    OstCombate.fuente(b, 44)
    OstCombate.texto(b, pp[0], pp[1] - yb + 90, pp[2], 56, tipo.upcase, 1, Color.new(255, 255, 255))
    # descripcion, potencia y precision
    de = OST_DESC
    gm = GameData::Move.try_get(move.id) rescue nil
    texto = (gm) ? gm.description.to_s : ""
    # la letra mas grande que deje el texto en tres lineas
    tam = 40
    lineas = []
    while tam >= 28
      OstCombate.fuente(b, tam)
      lineas = OstCombate.lineas(b, texto, de[2] - 20)
      break if lineas.length <= 3
      tam -= 2
    end
    lineas = lineas[0, 3]
    lineas.each_with_index do |l, i|
      OstCombate.texto(b, de[0] + 6, de[1] - yb + 4 + i * (tam + 4), de[2] - 12, tam + 6, l, 0, Color.new(30, 30, 30))
    end
    pot = (gm && gm.power.to_i > 1) ? gm.power.to_s : "-"
    pre = (gm && gm.accuracy.to_i > 0) ? gm.accuracy.to_s : "-"
    cat = ["F\u00CDSICO", "ESPECIAL", "ESTADO"][gm ? gm.category : 2] rescue ""
    # una franja negra abajo con los datos, en tres columnas
    fy = de[1] - yb + 146
    b.fill_rect(de[0] - 4, fy, de[2] + 8, 48, Color.new(15, 15, 15))
    OstCombate.fuente(b, 36)
    tercio = (de[2] + 8) / 3
    [["POT", pot], ["PREC", pre], [cat, nil]].each_with_index do |(et, val), k|
      txt = val ? "#{et} #{val}" : et
      OstCombate.texto(b, de[0] - 4 + k * tercio, fy + 2, tercio, 46, txt, 1,
                       (k == 2) ? Color.new(255, 200, 60) : Color.new(255, 255, 255))
    end
  end

  alias ostcomb_refreshMegaEvolutionButton refreshMegaEvolutionButton
  def refreshMegaEvolutionButton
    return ostcomb_refreshMegaEvolutionButton if !@ost
  end

  alias ostcomb_refreshShiftButton refreshShiftButton
  def refreshShiftButton
    return ostcomb_refreshShiftButton if !@ost
  end
end

#-------------------------------------------------------------------------------
# El cartel de habilidad ("Mar Llamas de Fennekin"), al estilo de la interfaz
#-------------------------------------------------------------------------------
class Battle::Scene::AbilitySplashBar
  OST_Y = [380, 30]           # propio (sale por la izquierda), rival (por la derecha)

  alias ostcomb_initialize initialize
  def initialize(side, viewport = nil)
    ostcomb_initialize(side, viewport)
    @ost = OstCombate.activo?
    return if !@ost
    w = 640
    h = 128
    @ostBg = Bitmap.new(w, h)
    # placa negra cortada en diagonal, con el rojo dentro
    h.times do |y|
      d = (h - y) * 30 / h
      x0 = (side == 0) ? 0 : d
      x1 = (side == 0) ? w - d : w
      @ostBg.fill_rect(x0, y, x1 - x0, 1, Color.new(0, 0, 0))
      next if y < 8 || y > h - 9
      @ostBg.fill_rect(x0 + 8, y, x1 - x0 - 16, 1, Color.new(220, 35, 40))
    end
    @bgSprite.bitmap = @ostBg
    @bgSprite.src_rect = Rect.new(0, 0, w, h)
    @contents.dispose
    @contents = Bitmap.new(w, h)
    self.bitmap = @contents
    OstCombate.fuente(self.bitmap, 52)
    # la animacion la mueve medio ancho de pantalla: asi acaba pegada a su borde
    self.x = (side == 0) ? -(Graphics.width / 2) : Graphics.width + (Graphics.width / 2 - w)
    self.y = OST_Y[side]
  end

  alias ostcomb_dispose dispose
  def dispose
    ostcomb_dispose
    @ostBg&.dispose
  end

  alias ostcomb_refresh refresh
  def refresh
    return ostcomb_refresh if !@ost
    self.bitmap.clear
    return if !@battler
    alin = (@side == 0) ? 0 : 2
    OstCombate.fuente(self.bitmap, 52)
    OstCombate.texto(self.bitmap, 30, 8, 580, 60, @battler.abilityName.upcase, alin,
                     Color.new(255, 255, 255), Color.new(0, 0, 0), 3)
    OstCombate.fuente(self.bitmap, 38)
    OstCombate.texto(self.bitmap, 30, 66, 580, 50, _INTL("de {1}", @battler.name).upcase, alin,
                     Color.new(255, 255, 255), Color.new(0, 0, 0), 2)
  end
end

# La ventana de mensajes del combate se queda en el panel blanco
alias ostcomb_pbRepositionMessageWindow pbRepositionMessageWindow
def pbRepositionMessageWindow(msgwindow, linecount = 2)
  ostcomb_pbRepositionMessageWindow(msgwindow, linecount)
  s = msgwindow.instance_variable_get(:@ost_sitio)
  return if !s || !OstCombate.activo?
  msgwindow.x, msgwindow.y, msgwindow.width, msgwindow.height = s
end

# El boton elegido late un poco, y el ataque elegido tambien
class Battle::Scene::CommandMenu
  def update
    super
    return if !@ost || !@ostSel || @ostSel.disposed?
    z = 1.0 + 0.035 * Math.sin(System.uptime * 7)
    @ostSel.zoom_x = z
    @ostSel.zoom_y = z
  end
end

class Battle::Scene::FightMenu
  def update
    super
    return if !@ost || !@buttons
    s = @buttons[@index]
    return if !s || s.disposed?
    z = 1.06 + 0.025 * Math.sin(System.uptime * 7)
    s.zoom_x = z
    s.zoom_y = z
  end
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
# Las animaciones de los ataques calculan el centro del Pokemon con su zoom.
# Nuestros Pokemon dicen tener zoom 1 (para que las animaciones no los
# encojan), asi que aqui se usa el zoom real: si no, el Pokemon se dibujaba
# mas abajo durante cada ataque y la barra lo tapaba.
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
