# Saca de 016 solo lo que se prueba y lo ejecuta con imitaciones minimas
src = File.read(ARGV[0]).gsub("\r\n", "\n")
mod = src[/^module OstCombate\n.*?^end\n/m]
class Color; attr_reader :alpha; def initialize(r = 0, g = 0, b = 0, a = 255); @alpha = a; end; end
class Bitmap
  attr_reader :width, :height
  def initialize(w, h, pies); @width, @height, @pies = w, h, pies; end   # pies = fila de abajo con dibujo
  def disposed?; false; end
  def get_pixel(x, y); Color.new(0, 0, 0, (y <= @pies && x >= 40 && x < 150) ? 255 : 0); end
end
eval(mod.sub(/^  def self\.con\n.*?^  end\n/m, ""))
$game_map = Struct.new(:map_id).new(17)
fail "suelo" unless OstCombate.suelo?
b = Bitmap.new(192, 192, 135)
fail "vacio #{OstCombate.vacio_abajo(b)}" unless OstCombate.vacio_abajo(b) == 56
# zoom por sprite: el modulo de 016
zoom = src[/^module OstCombateZoom\n.*?^end\n/m]
def OstCombate.activo?; true; end
eval(zoom)
class Fake; include OstCombateZoom; def initialize(i, s); @index, @sideSize = i, s; end; end
fail "k doble" unless Fake.new(1, 2).ost_k == 2 && Fake.new(1, 1).ost_k == 3
fail "suelo doble" unless Fake.new(3, 2).ost_suelo_y == 550 && Fake.new(1, 2).ost_suelo_y == 605
fail "suelo individual tunel" unless Fake.new(1, 1).ost_suelo_y == 470
fail "propio sin suelo" unless Fake.new(0, 2).ost_suelo_y.nil?
$game_map.map_id = 9
fail "fuera del tunel" unless Fake.new(1, 1).ost_suelo_y.nil? && Fake.new(1, 2).ost_suelo_y == 605
# donde queda el rival: imagen anclada por abajo -> fila de abajo con dibujo en el suelo
y = 605 + OstCombate.vacio_abajo(b) * 2
fail "pies" unless y - 56 * 2 == 605
# fichas: enteras dentro de 1920x1080 y por encima de la barra
fr = [793, 279]; fp = [782, 306]
OstCombate::DOBLE_FICHAS.each_with_index do |(x, y2), i|
  w, h = (i.even? ? fp : fr).map { |v| (v * OstCombate::DOBLE_FICHA).round }
  fail "ficha #{i} fuera" if x < 0 || y2 < 0 || x + w > 1920 || (i.even? && y2 + h > OstCombate::BARRA2_Y)
end
puts "OK: escala x2 en dobles, pies (#{OstCombate.vacio_abajo(b)} filas vacias) y fichas dentro de pantalla"
