# Simulador sin motor: imitaciones minimas de RGSS para ejecutar 025 de punta a punta
require 'json'
JUEGO = ARGV[0]
Dir.chdir(JUEGO)
$frames = []
$log = []
def echoln(s); $log << "ECHO #{s}"; end
class Tone;  attr_accessor :r,:g,:b,:gr; def initialize(*a); set(*a) if a.size>0; @r||=0;@g||=0;@b||=0;@gr||=0; end; def set(r=0,g=0,b=0,gr=0); @r,@g,@b,@gr=r,g,b,gr; end; end
class Color; attr_accessor :r,:g,:b,:a; def initialize(r=0,g=0,b=0,a=255); set(r,g,b,a); end; def set(r,g,b,a=255); @r,@g,@b,@a=r,g,b,a; end; end
class Rect;  attr_accessor :x,:y,:width,:height; def initialize(x=0,y=0,w=0,h=0); set(x,y,w,h); end; def set(x,y,w,h); @x,@y,@width,@height=x,y,w,h; end; end
class Bitmap
  attr_reader :width, :height, :path
  def initialize(a, b = nil)
    if b.nil?
      p = a.to_s; p += ".png" if !File.exist?(p) && File.exist?(p + ".png")
      raise "no existe #{a}" if !File.exist?(p)
      d = File.binread(p, 24); @width, @height = d[16, 8].unpack("NN"); @path = p
    else
      @width, @height = a, b; @path = nil; @fills = []
    end
    @disposed = false
  end
  def fill_rect(*a); (@fills ||= []) << a; end
  def fills; @fills; end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
  def clone; self; end
end
class Viewport
  attr_accessor :z
  def initialize(*a); @z = 0; end
  def dispose; end
  def disposed?; false; end
end
$sprites = []
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :zoom_x, :zoom_y, :angle, :mirror, :blend_type, :visible, :src_rect, :tone, :color
  attr_reader :viewport, :opacity
  def initialize(vp = nil)
    @viewport = vp; @x = @y = @z = @ox = @oy = 0; @zoom_x = @zoom_y = 1.0; @angle = 0; @mirror = false
    @blend_type = 0; @visible = true; @opacity = 255; @src_rect = Rect.new(0, 0, 0, 0); @tone = Tone.new; @color = Color.new(0, 0, 0, 0)
    @disposed = false; @srcset = false
    $sprites << self
  end
  def bitmap=(b); @bitmap = b; @src_rect = Rect.new(0, 0, b ? b.width : 0, b ? b.height : 0); end
  def opacity=(o); @opacity = [[o.to_i, 0].max, 255].min; end
  def dispose; @disposed = true; end
  def disposed?; @disposed; end
end
module Graphics
  @fc = 0; @w = 682; @h = 384
  def self.frame_count; @fc; end
  def self.width; @w; end
  def self.height; @h; end
  def self.resize_screen(w, h); @w, @h = w, h; end
  def self.fullscreen; true; end
  def self.update
    @fc += 1
    if @fc % 6 == 0 || $foto_ya
      $foto_ya = false
      vivos = $sprites.reject { |s| s.disposed? || !s.bitmap || s.opacity <= 0 || !s.visible }
      $frames << { "f" => @fc, "s" => vivos.map { |s| b = s.bitmap
        { "p" => b.path, "fill" => (b.path ? nil : b.fills), "bw" => b.width, "bh" => b.height,
          "sr" => [s.src_rect.x, s.src_rect.y, s.src_rect.width, s.src_rect.height], "x" => s.x, "y" => s.y, "z" => s.z,
          "vz" => s.viewport ? s.viewport.z : 0, "ox" => s.ox, "oy" => s.oy, "zx" => s.zoom_x, "zy" => s.zoom_y, "a" => s.angle,
          "m" => s.mirror, "o" => s.opacity, "bl" => s.blend_type, "t" => [s.tone.r, s.tone.g, s.tone.b, s.tone.gr],
          "c" => [s.color.r, s.color.g, s.color.b, s.color.a] } } }
    end
    raise "demasiados fotogramas" if @fc > 60 * 60 * 20
  end
end
module Input
  USE = :use
  @pulsada = false
  def self.update; @pulsada = ($pulsar_cada > 0 && Graphics.frame_count % $pulsar_cada == 0); end
  def self.press?(k); @pulsada; end
  def self.trigger?(k); @pulsada; end
end
$pulsar_cada = 45
module FileTest; def self.exist?(p); File.exist?(p); end; end
$se = []
def pbSEPlay(n, v = 100, t = 100); $se << [Graphics.frame_count, n, v, t]; end
$game_switches = {}
module OstinatoHD; def self.con; yield; end; end
module OstDlg
  def self.run(guion, artes, aj = nil)
    $log << "DLG #{guion.map(&:first).join(',')}"
    guion.each { |c, _| raise "falta #{c}" if !File.exist?("Graphics/Titles/#{c}.png") }
  end
end
src = File.read("Plugins/Ostinato/011_MiniSprigatito.rb")
eval(src[/^module OstMini\b.*?^end\r?$/m])
module OstMini
  def self.pantalla(bgm = nil)
    Graphics.resize_screen(1920, 1080)
    vp = Viewport.new(0, 0, 1920, 1080); vp.z = 99999
    telon = negro(vp); telon.opacity = 255
    yield vp, telon
  end
end
load "Plugins/Ostinato/025_ObraTeatro.rb"
# los subtitulos que se piden tienen que existir
module OstObra
  class << self
    alias sim_di di
    def di(c); raise "falta #{c}" if !File.exist?("Graphics/Titles/#{c}.png"); $log << "DI #{Graphics.frame_count} #{c}"; $foto_ya = true; sim_di(c); end
  end
end
t0 = Time.now
OstObra.empezar
$log.each { |l| puts l if l.start_with?("ECHO") }
puts "fotogramas: #{Graphics.frame_count} (#{(Graphics.frame_count / 60.0).round(1)} s a 60 fps), simulado en #{(Time.now - t0).round(1)} s"
puts "subtitulos: #{$log.count { |l| l.start_with?('DI') }}  sonidos: #{$se.size}  #{$log.grep(/DLG/).first}"
puts "switch 83: #{$game_switches[83]}"
File.write(ARGV[1], JSON.generate({ "frames" => $frames, "log" => $log, "se" => $se }))
