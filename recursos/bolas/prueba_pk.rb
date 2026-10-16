class Scene_Map; def update; end; end
load ARGV[0]
M = OstPkTunel
G = File.read("paso18.txt").split("\n")
M.instance_variable_set(:@mapa, 18); M.instance_variable_set(:@pk, {})
suelo = []; orilla = []
43.times { |x| 24.times { |y| next if G[y][x] != "."; (M.en_zona?(x, y, M::AGUA[18]) ? orilla : suelo) << [x, y] } }
M.instance_variable_set(:@suelo, suelo); M.instance_variable_set(:@orilla, orilla)
def M.ocupada?(x, y); false; end
rnd = Random.new(5); cuenta = Hash.new(0)
400.times do
  d = M.elegir(4, 14, rnd); next if !d
  raise "cerca" if (d[:x] - 4).abs + (d[:y] - 14).abs < M::LEJOS
  raise "agua fuera de la orilla" if d[:agua] && !M.en_zona?(d[:x], d[:y], M::AGUA[18])
  cuenta[d[:especie]] += 1
end
puts "reparto mapa 18: #{cuenta.sort_by { |_, v| -v }.inspect}"
# comportamientos: Kaia en (10,10), Pokemon en (12,10)
d = { :modo => :miedoso }; puts "miedoso huye primero hacia: #{M.direcciones(d, 12, 10, 10, 10, rnd).first} (6 = derecha, lejos de Kaia)"
d = { :modo => :agresivo }; puts "agresivo va primero hacia: #{M.direcciones(d, 12, 10, 10, 10, rnd).first} (4 = izquierda, hacia Kaia)"
d = { :modo => :agresivo }; puts "lejos (12 casillas) se mueve al azar: #{M.direcciones(d, 22, 10, 10, 10, rnd).inspect}"
puts "OK"
