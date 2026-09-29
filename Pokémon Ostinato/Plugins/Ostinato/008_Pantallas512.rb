#===============================================================================
# Pokemon Ostinato - Las pantallas de menu y los combates, centrados
#
#   El juego va a 682x384 (16:9), pero las pantallas de La Base de Sky (mochila,
#   equipo, datos, Pokedex, PC, tienda, opciones, combates...) estan dibujadas
#   para 512x384 y colocan todo con coordenadas fijas: a 682 se quedaban
#   pegadas a la izquierda, con el fondo cortado y un trozo negro a la derecha.
#
#   Rehacerlas una a una seria enorme, asi que mientras una de ellas esta
#   abierta se le hace creer que la pantalla mide 512: Graphics.width devuelve
#   512, cada Viewport nuevo se corre al centro, y los lados se tapan con dos
#   bandas negras, como un 4:3 dentro de una pantalla 16:9. El mapa, los
#   dialogos del prologo y las escenas propias siguen a pantalla completa.
#
#   Todas esas pantallas se abren con pbFadeOutIn, y los combates con
#   pbBattleAnimation: se enganchan ahi. Lo que se abre a mano se puede
#   envolver en OstUI.con { ... }.
#===============================================================================
module OstUI
  ANCHO = 512
  @nivel = 0

  def self.activo?
    return @nivel > 0
  end

  def self.ancho_real
    return Settings::SCREEN_WIDTH
  end

  # cuanto se corre todo a la derecha para quedar centrado
  def self.dx
    return (ancho_real - ANCHO) / 2
  end

  def self.con
    return yield if ancho_real <= ANCHO
    poner_bandas if @nivel == 0
    @nivel += 1
    begin
      return yield
    ensure
      @nivel -= 1
      quitar_bandas if @nivel == 0
    end
  end

  # El viewport en el que caen las ventanas y sprites que se crean sin uno:
  # si no, se dibujarian en coordenadas de pantalla, pegados a la izquierda.
  def self.vista
    if !@vista || @vista.disposed?
      @vista = Viewport.new(0, 0, ANCHO, Graphics.height)   # se corre solo al centro
      @vista.z = 100_000
    end
    return @vista
  end

  # Las bandas se crean ANTES de activar el modo, con la pantalla real.
  def self.poner_bandas
    quitar_bandas
    alto = Settings::SCREEN_HEIGHT
    @bandas_vp = Viewport.new(0, 0, ancho_real, alto)
    @bandas_vp.z = 999_999
    @bandas = []
    [[0, dx], [dx + ANCHO, ancho_real - dx - ANCHO]].each do |x, w|
      next if w <= 0
      s = Sprite.new(@bandas_vp)
      s.bitmap = Bitmap.new(w, alto)
      s.bitmap.fill_rect(0, 0, w, alto, Color.new(0, 0, 0))
      s.x = x
      @bandas.push(s)
    end
  end

  def self.quitar_bandas
    (@bandas || []).each do |s|
      next if s.disposed?
      s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
      s.dispose
    end
    @bandas = nil
    @bandas_vp.dispose if @bandas_vp && !@bandas_vp.disposed?
    @bandas_vp = nil
    @vista.dispose if @vista && !@vista.disposed?
    @vista = nil
  end
end

class << Graphics
  alias_method :ostui_width, :width unless method_defined?(:ostui_width)
  def width
    return OstUI::ANCHO if OstUI.activo?
    return ostui_width
  end
end

class Viewport
  alias_method :ostui_initialize, :initialize unless method_defined?(:ostui_initialize)
  def initialize(*args)
    if OstUI.activo?
      if args.length == 4
        args = [args[0] + OstUI.dx, args[1], args[2], args[3]]
      elsif args.length == 1 && args[0].is_a?(Rect)
        r = args[0]
        args = [Rect.new(r.x + OstUI.dx, r.y, r.width, r.height)]
      elsif args.empty?
        args = [OstUI.dx, 0, OstUI::ANCHO, Settings::SCREEN_HEIGHT]
      end
    end
    ostui_initialize(*args)
  end
end

class Sprite
  alias_method :ostui_initialize, :initialize unless method_defined?(:ostui_initialize)
  def initialize(viewport = nil)
    viewport = OstUI.vista if viewport.nil? && OstUI.activo?
    ostui_initialize(viewport)
  end
end

class Plane
  alias_method :ostui_initialize, :initialize unless method_defined?(:ostui_initialize)
  def initialize(viewport = nil)
    viewport = OstUI.vista if viewport.nil? && OstUI.activo?
    ostui_initialize(viewport)
  end
end

class SpriteWindow
  alias_method :ostui_initialize, :initialize unless method_defined?(:ostui_initialize)
  def initialize(viewport = nil)
    viewport = OstUI.vista if viewport.nil? && OstUI.activo?
    ostui_initialize(viewport)
  end
end

alias ostui_pbFadeOutIn pbFadeOutIn
def pbFadeOutIn(*args, &block)
  return ostui_pbFadeOutIn(*args) if !block
  ostui_pbFadeOutIn(*args) { OstUI.con(&block) }
end

alias ostui_pbFadeOutInWithUpdate pbFadeOutInWithUpdate
def pbFadeOutInWithUpdate(*args, &block)
  return ostui_pbFadeOutInWithUpdate(*args) if !block
  ostui_pbFadeOutInWithUpdate(*args) { OstUI.con(&block) }
end

alias ostui_pbBattleAnimation pbBattleAnimation
def pbBattleAnimation(*args, &block)
  return ostui_pbBattleAnimation(*args) if !block
  ostui_pbBattleAnimation(*args) { OstUI.con(&block) }
end

#-------------------------------------------------------------------------------
# Lo poco de Sky que mira Settings::SCREEN_WIDTH (682) en vez de Graphics.width:
# dentro de estas pantallas tiene que ser el ancho que se esta mostrando.
#-------------------------------------------------------------------------------
class Battle::Scene
  # la base del rival; con 682 se iba fuera de la pantalla de combate
  def self.FOE_BASE_X; Graphics.width - 128; end
end

class PokemonPokedex_Scene
  def self.DEXSEARCH_TITLE_X;        Graphics.width / 2; end
  def self.DEXSEARCH_START_X;        Graphics.width / 2; end
  def self.DEXSEARCH_CANCEL_X;       Graphics.width - 80; end
  def self.DEXSEARCH_PARAM_TITLE_X;  Graphics.width / 2; end
  def self.DEXSEARCH_PARAM_CANCEL_X; Graphics.width - 80; end
end

# el texto de la entrada de la Pokedex se calculaba al cargar, con 682
begin
  PokemonPokedexInfo_Scene::PAGE_INFO_COORDS[:dex_entry_text] = [40, 246, OstUI::ANCHO - 80, 4]
rescue
end
