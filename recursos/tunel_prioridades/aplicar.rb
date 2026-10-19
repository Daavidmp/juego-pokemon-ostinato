# Uso: rmxp.ps1 -Script aplicar.rb [-Datos "escribir=1"] (skill mapas-rmxp). Ya aplicado el 2026-10-16: volver a ejecutarlo deja lo mismo.
# Paso y prioridad del tunel (mapas 15-18). ARGS["escribir"] == "1" escribe; si no, solo comprueba.
PRIO = {   # mapa => [[x, y, prioridad]]
  15 => (10..13).map { |x| [x, 2, 2] },                                   # boca de arriba: tapa la cabeza en la fila 3
  16 => (16..19).map { |x| [x, 3, 2] } + [[16, 4, 1], [19, 4, 1]],          # arco de la carretera y sus patas
  17 => [[40, 16, 2], [41, 16, 2]],                                          # boca de la via
  18 => []                                                                   # la via de la izquierda: Kaia va por delante
}
BLOQ = {   # casillas que pasan a no pisarse (dibujo de un objeto en suelo pisable)
  15 => [],
  16 => [[14, 5], [14, 6], [14, 9], [14, 10], [14, 11], [14, 12], [14, 13],   # el poste de la acera
         [7, 31], [7, 32], [7, 33],                                           # el agua del canal
         [8, 30], [9, 30]],                                                   # la parte de arriba de los bidones
  17 => [[12, 12], [14, 11], [15, 11], [16, 11],                             # el techo del autobus
         [20, 14], [20, 15], [24, 14], [24, 15]],                            # los postes de abajo del puente
  18 => [[6, 3], [7, 3], [8, 3], [13, 3], [14, 3], [16, 3]] +                # los pies de las tuberias
        (3..10).map { |x| [x, 15] }                                          # el techo del vagon y el tope
}
tss = Marshal.load(File.binread(BASE + "Data/Tilesets.rxdata"))
mapas = {}
PRIO.keys.each { |m| mapas[m] = Marshal.load(File.binread(BASE + format("Data/Map%03d.rxdata", m))) }

def pisable(map, t, x, y)
  return false if x < 0 || y < 0 || x >= map.width || y >= map.height
  [2, 1, 0].each do |c|
    id = map.data[x, y, c]
    return false if t.passages[id] & 0x0f == 0x0f
    return true if t.priorities[id] == 0
  end
  return true
end
def bits(map, t, x, y)
  id = map.data[x, y, 0]; return t.passages[id] & 0x0f
end
# casillas a las que se llega desde las salidas del mapa (respetando los bits por direccion)
def alcanzables(map, t, extra_bloq)
  dirs = { 1 => [0, 1, 8], 2 => [-1, 0, 4], 4 => [1, 0, 2], 8 => [0, -1, 1] }
  ini = map.events.values.select { |e| e.name =~ /Salida|Bajar|Subir|Seguir|Volver/ }.map { |e| [e.x, e.y] }
  vistos = {}; cola = ini.dup; ini.each { |p| vistos[p] = true }
  until cola.empty?
    x, y = cola.shift
    dirs.each do |b, (dx, dy, op)|
      nx, ny = x + dx, y + dy
      next if vistos[[nx, ny]] || extra_bloq.include?([nx, ny])
      next if nx < 0 || ny < 0 || nx >= map.width || ny >= map.height
      next if bits(map, t, x, y) & b != 0 || bits(map, t, nx, ny) & op != 0
      next unless pisable(map, t, nx, ny)
      vistos[[nx, ny]] = true; cola << [nx, ny]
    end
  end
  vistos
end

mapas.each do |m, map|
  t = tss[map.tileset_id]
  OUT << "MAPA #{m} (tileset #{map.tileset_id}); id 0: paso #{t.passages[0]} prio #{t.priorities[0]}"
  antes = alcanzables(map, t, [])
  despues = alcanzables(map, t, BLOQ[m])
  perdidas = antes.keys - despues.keys - BLOQ[m]
  OUT << "  alcanzables #{antes.size} -> #{despues.size}; casillas que se quedan sin llegar (aparte de las bloqueadas): #{perdidas.inspect}"
  # lo que tiene que seguir alcanzable: eventos (desde una casilla vecina) 
  map.events.values.each do |e|
    ok = [[0, 0], [0, 1], [0, -1], [1, 0], [-1, 0]].any? { |dx, dy| despues[[e.x + dx, e.y + dy]] }
    OUT << "  !! evento #{e.name} (#{e.x},#{e.y}) se queda sin acceso" unless ok
  end
  BLOQ[m].each do |x, y|
    id = map.data[x, y, 0]
    OUT << "  bloquear (#{x},#{y}) id #{id}: paso #{t.passages[id]} -> 15" + (map.data[x, y, 1] != 0 || map.data[x, y, 2] != 0 ? " (OJO capas 1-2 ocupadas)" : "")
    usos = mapas.select { |mm, mp| mp.tileset_id == map.tileset_id }.sum { |mm, mp| c = 0; mp.width.times { |a| mp.height.times { |b| c += 1 if mp.data[a, b, 0] == id } }; c }
    OUT << "    OJO: el tile #{id} se usa #{usos} veces" if usos != 1
    t.passages[id] = 15
  end
  PRIO[m].each do |x, y, p|
    id = map.data[x, y, 0]
    OUT << "  prioridad (#{x},#{y}) id #{id}: #{t.priorities[id]} -> #{p} (paso #{t.passages[id]})"
    t.priorities[id] = p
  end
end
if ARGS["escribir"] == "1"
  dir = ENV["LOCALAPPDATA"].to_s.tr(92.chr, "/") + "/rmxp_motor/copias/"
  Dir.mkdir(dir) rescue nil
  File.binwrite(dir + "Tilesets.rxdata", File.binread(BASE + "Data/Tilesets.rxdata"))
  File.binwrite(BASE + "Data/Tilesets.rxdata", Marshal.dump(tss))
  OUT << "ESCRITO Tilesets.rxdata (copia en %LOCALAPPDATA%/rmxp_motor/copias/)"
else
  OUT << "(prueba: no se ha escrito nada)"
end
