# Carga el código de Pokémon Ostinato (Essentials v21 + plugins) en un Ruby normal, sin RPG Maker ni ventana,
# para usar su motor de combate desde el servidor de Pokelocke (combate en línea, 2.4.0).
# Las clases gráficas de RGSS/mkxp-z se sustituyen por piezas de relleno que no pintan nada.
require 'zlib'

JUEGO = (ENV['OST_JUEGO'] || ARGV[0]).dup.force_encoding('UTF-8')

# --- relleno de RGSS / mkxp-z ---
class Relleno
  def initialize(*a, **k); end
  def method_missing(n, *a, **k, &b)
    return 0 if %i[width height x y z ox oy opacity zoom_x zoom_y angle size length].include?(n)
    return false if n.to_s.end_with?('?')
    self
  end
  def respond_to_missing?(*) = true
  %i[x y z ox oy width height opacity visible bitmap src_rect zoom_x zoom_y angle mirror color tone blend_type viewport
     font rect windowskin contents active pause cursor_rect back_opacity contents_opacity openness tileset autotiles
     map_data priorities flash_data bush_depth wave_amp].each do |m|
    define_method(m) { instance_variable_get("@#{m}") || (%i[visible active pause mirror].include?(m) ? false : 0) }
    define_method("#{m}=") { |v| instance_variable_set("@#{m}", v) }
  end
  %i[update draw_text fill_rect blt stretch_blt clear text_size set_pixel get_pixel hue_change gradient_fill_rect
     clear_rect flash].each { |m| define_method(m) { |*a, **k| self } }
  def dispose; end
  def disposed? = false
  def to_i = 0
  def to_a = []
  def each; end
  def self.method_missing(*) = nil
  def self.respond_to_missing?(*) = true
end
%w[Bitmap Sprite Viewport Plane Window Tilemap Font Table BitmapWrapper].each { |c| Object.const_set(c, Class.new(Relleno)) }
class Color
  attr_accessor :red, :green, :blue, :alpha
  def initialize(r = 0, g = 0, b = 0, a = 255) = (@red, @green, @blue, @alpha = r, g, b, a)
  def set(*a) = initialize(*a)
  # como en RGSS: cuatro doubles (para leer los .rxdata que los guardan, p. ej. las animaciones)
  def self._load(s) = new(*s.unpack('E4'))
  def _dump(_) = [@red, @green, @blue, @alpha].pack('E4')
end
class Tone < Color; def initialize(r = 0, g = 0, b = 0, a = 0) = super; end
class Rect
  attr_accessor :x, :y, :width, :height
  def initialize(x = 0, y = 0, w = 0, h = 0) = (@x, @y, @width, @height = x, y, w, h)
  def set(*a) = initialize(*a)
end
module Graphics
  def self.method_missing(*) = 0
  def self.respond_to_missing?(*) = true
  def self.width = 1920
  def self.height = 1080
  def self.frame_rate = 60
  def self.frame_count = 0
end
module Input
  def self.method_missing(*) = false
  def self.respond_to_missing?(*) = true
  def self.const_missing(n) = const_set(n, 1000 + n.to_s.sum)
end
module Audio
  def self.method_missing(*) = nil
  def self.respond_to_missing?(*) = true
end
module System
  def self.method_missing(*) = nil
  def self.respond_to_missing?(*) = true
  def self.data_directory = '.'
  def self.platform = 'Windows'
  def self.is_windows? = true
  def self.user_language = 'es_ES'
  def self.uptime = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  VERSION = '2.4.2'
end
module MKXP; def self.method_missing(*) = nil; end
class MKXPError < StandardError; end
module HTTPLite; def self.method_missing(*) = raise(MKXPError, 'sin red'); def self.const_missing(*) = raise(MKXPError, 'sin red'); end
class Win32API; def initialize(*); end; def call(*) = 0; end
module RPG; end
def load_data(f) = Marshal.load(File.binread(File.join(JUEGO, f)))
def save_data(*); end
def rgss_main; yield; end
def msgbox(*a) = $stderr.puts("[msgbox] #{a.join(' ')}")
def print(*a) = $stderr.puts("[print] #{a.join(' ')}")
$DEBUG = false

# --- el código del juego, en su orden (Scripts.rxdata y luego los plugins), sin Main ---
def cargar_ostinato(saltar: [])
  Dir.chdir(JUEGO)
  errores = []
  scripts = Marshal.load(File.binread('Data/Scripts.rxdata'))
  scripts.each do |_, nombre, comp|
    nombre = nombre.to_s.force_encoding('UTF-8')
    break if nombre == 'Main'
    next if saltar.any? { |s| nombre.include?(s) }
    codigo = Zlib::Inflate.inflate(comp).force_encoding('UTF-8')
    begin
      eval(codigo, TOPLEVEL_BINDING, nombre)
    rescue Exception => e
      errores << "#{nombre}: #{e.class}: #{e.message[0, 160]}"
    end
  end
  Marshal.load(File.binread('Data/PluginScripts.rxdata')).each do |plugin, _, archivos|
    archivos.each do |arch, comp|
      codigo = Zlib::Inflate.inflate(comp).force_encoding('UTF-8')
      begin
        eval(codigo, TOPLEVEL_BINDING, "#{plugin}/#{arch}")
      rescue Exception => e
        errores << "#{plugin}/#{arch}: #{e.class}: #{e.message[0, 160]}"
      end
    end
  end
  errores
end

if $0 == __FILE__
  errores = cargar_ostinato
  puts "#{errores.size} errores al cargar"
  errores.first(40).each { |e| puts "  #{e}" }
end

# lo que el combate espera de una partida en marcha (interruptores, variables, opciones...), sin partida
def preparar_partida
  GameData.load_all
  $game_temp      = Game_Temp.new
  $game_switches  = Game_Switches.new
  $game_variables = Game_Variables.new
  $game_self_switches = Game_SelfSwitches.new rescue nil
  $PokemonSystem  = PokemonSystem.new
  $PokemonGlobal  = PokemonGlobalMetadata.new rescue nil
  $PokemonTemp    = nil
  $game_system    = Game_System.new rescue nil
  $player         = Player.new('Pokelocke', GameData::TrainerType.keys.first)
end
module LBDSKY; VERSION = "?"; end
