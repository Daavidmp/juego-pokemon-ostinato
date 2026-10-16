class Game_Player; def update_command_new; end; end
class Scene_Map; def update; end; end
load ARGV[0]
G = File.read("paso18.txt").split("\n")
pas = proc { |x, y, d, nx, ny| nx >= 0 && ny >= 0 && nx < 43 && ny < 24 && G[ny][nx] == "." && G[y][x] == "." }
# 1) camino por el laberinto: de la galeria de arriba a Kaia en la estacion
r = OstOjos.camino(8, 3, 4, 14, pas)
raise "sin camino" if !r
puts "camino galeria->estacion: #{r.length} pasos, acaba en #{r.last.inspect} (Kaia en [4,14])"
raise "no acaba al lado" unless (r.last[0] - 4).abs + (r.last[1] - 14).abs == 1
r.each { |x, y| raise "pisa pared #{[x, y]}" if G[y][x] != "." }
r.each_cons(2) { |a, b| raise "salto" if (a[0] - b[0]).abs + (a[1] - b[1]).abs != 1 }
# 2) sin camino posible (Kaia encerrada): nil
G2 = G.map(&:dup); G2[13][3] = G2[13][5] = G2[12][4] = G2[14][3] = G2[14][5] = G2[15][4] = "#"
pas2 = proc { |x, y, d, nx, ny| nx >= 0 && ny >= 0 && nx < 43 && ny < 24 && G2[ny][nx] == "." }
puts "encerrada: #{OstOjos.camino(8, 3, 4, 14, pas2).inspect}"
# 3) elegir: lejos de Kaia, en sitios oscuros o de agua segun el tipo
OstOjos.instance_variable_set(:@mapa, 18)
OstOjos.instance_variable_set(:@oscuras, (0...43).flat_map { |x| (0...24).map { |y| [x, y] } }.select { |x, y| G[y][x] == "." && !(x.between?(23, 32) && y.between?(19, 22)) })
OstOjos.instance_variable_set(:@agua, [[23, 20], [24, 21], [31, 21], [32, 20]])
OstOjos.instance_variable_set(:@ojos, [])
cuenta = Hash.new(0); rnd = Random.new(3)
500.times do
  o = OstOjos.elegir(4, 14, rnd)
  next if !o
  raise "demasiado cerca" if (o[:x] - 4).abs + (o[:y] - 14).abs < OstOjos::LEJOS
  raise "cian fuera del agua" if o[:tipo] == 3 && !OstOjos.instance_variable_get(:@agua).include?([o[:x].to_i, o[:y].to_i])
  raise "nivel" unless o[:nivel].between?(10, 12)
  cuenta[o[:especie]] += 1
end
puts "reparto en 500 apariciones (mapa 18): #{cuenta.sort_by { |k, v| -v }.inspect}"
puts "OK"
