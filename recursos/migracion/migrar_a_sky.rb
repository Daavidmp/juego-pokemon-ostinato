# Migra Pokemon Ostinato de Essentials BES a La Base de Sky (v21.1). Version en Ruby de
# migrar_a_sky.py: hace los mismos pasos, sin depender del devkit de Python del otro equipo.
#
# No hace falta Ruby instalado: se ejecuta con el propio Game.exe de la v21 (mkxp-z trae
# Ruby 3.1 dentro). En una carpeta aparte, copia Game.exe y sus .dll, este archivo como
# tool.rb, y un mkxp.json con:   { "customScript": "tool.rb" }
# Al lanzar Game.exe se ejecuta y deja el informe en out.txt. Ojo: load_data del motor solo
# ve la carpeta del juego, por eso aqui se usa Marshal sobre rutas absolutas.
#
# Ademas de lo del .py: pasa todos los mapas del MapInfos de BES, quita del laboratorio los
# eventos de la fuga antigua (ahora la lleva el plugin), nombra los interruptores del
# prologo (78 y 101-104, porque Sky reserva del 39 al 50), pone Kaia como charset de la
# jugadora y SnapEdges en todos los mapas, y de los SE copia solo los propios.
RAIZ = "C:/Users/ASUS/Music/Pokemon Ostinato - migracion"
BES  = RAIZ + "/Pokémon Essentials BES"
def load_data(p) Marshal.load(File.binread(p)) end
def save_data(o, p) File.binwrite(p, Marshal.dump(o)) end
SKY  = RAIZ + "/Pokémon Ostinato"
$inf = []
def copiar(src, dst, pisar = true)
  if File.exist?(dst)
    return false if !pisar
    return false if File.size(src) == File.size(dst) && File.binread(src) == File.binread(dst)
  end
  d = File.dirname(dst)
  parts = []; while !File.directory?(d); parts.unshift(d); d = File.dirname(d); end
  parts.each { |p| Dir.mkdir(p) }
  File.binwrite(dst, File.binread(src))
  File.utime(File.atime(src), File.mtime(src), dst)
  true
end
def copiar_carpeta(sub, pisar = true, destino = nil)
  s = BES + "/" + sub; d = SKY + "/" + (destino || sub); n = 0
  Dir.glob("**/*", base: s).each do |rel|
    next if File.directory?(s + "/" + rel)
    n += 1 if copiar(s + "/" + rel, d + "/" + rel, pisar)
  end
  $inf << "%-28s %4d ficheros" % [sub + (pisar ? "" : " (sin pisar)"), n]
end
begin
# 1. mapas
data = SKY + "/Data"
Dir.children(data).each { |f| File.delete(data + "/" + f) if f =~ /\AMap\d{3}\.rxdata\z/ }
infos = load_data(BES + "/Data/MapInfos.rxdata")
MAPAS = infos.keys.sort
MAPAS.each { |m| copiar(BES + "/Data/Map%03d.rxdata" % m, data + "/Map%03d.rxdata" % m) }
%w(MapInfos.rxdata Tilesets.rxdata).each { |f| copiar(BES + "/Data/" + f, data + "/" + f) }
$inf << "mapas #{MAPAS.inspect}, MapInfos y Tilesets de Ostinato"
# La fuga de los iniciales la lleva el plugin (OstinatoFuga, en 006_Prologo.rb). Los eventos 3-6
# del laboratorio eran un primer intento cuyas rutas no llegaban a la puerta en este mapa.
lab = load_data(data + "/Map007.rxdata")
quitados = [3, 4, 5, 6].select { |k| lab.events[k] && lab.events[k].name =~ /Mudkip|Fennekin|Sprigatito|Fuga/ }
quitados.each { |k| lab.events.delete(k) }
save_data(lab, data + "/Map007.rxdata")
$inf << "Map007: quitados los eventos de la fuga #{quitados.inspect}"
# 2. System
sb = load_data(BES + "/Data/System.rxdata"); ss = load_data(data + "/System.rxdata")
propios = []
sb.switches.each_with_index do |n, i|
  next if !n || n.empty? || i < 1
  next if ss.switches[i] == n
  if ss.switches[i] && !ss.switches[i].empty?
    $inf << "OJO switch #{i}: Sky='#{ss.switches[i]}' BES='#{n}' (se queda el de Sky)"; next
  end
  ss.switches[i] = n; propios << i
end
%w(title_bgm start_map_id start_x start_y edit_map_id).each { |k| ss.instance_variable_set("@#{k}", sb.instance_variable_get("@#{k}")) }
# Sky reserva los interruptores 39-50: los del prologo, que en BES eran 40-44, pasan al 101-104
# y la salida del pueblo al 78 (el SW 0028 del guion, con el +50 de la fuga).
{ 78 => "Salida sur abierta", 101 => "Prologo: despertar visto", 102 => "Prologo: cocina vista",
  103 => "Prologo: puerta vista", 104 => "Prologo: laboratorio visto" }.each do |i, n|
  ss.switches[i] = n.dup.force_encoding("BINARY") if ss.switches[i].nil? || ss.switches[i].empty?
end
save_data(ss, data + "/System.rxdata")
$inf << "System: titulo '#{sb.title_bgm.name}', inicio #{sb.start_map_id},#{sb.start_x},#{sb.start_y}, switches con nombre de BES: #{propios.inspect}"
# 3. graficos
%w(Graphics/Tilesets Graphics/Autotiles Graphics/Titles).each { |s| copiar_carpeta(s) }
copiar(BES + "/Graphics/Pictures/FarolaLuz.png", SKY + "/Graphics/Pictures/FarolaLuz.png")
copiar_carpeta("Graphics/Characters", false)
%w(trchar000.png trchar001.png boy_run.png girl_run.png MUDKIP.png FENNEKIN.png SPRIGATITO.png).each { |f|
  copiar(BES + "/Graphics/Characters/" + f, SKY + "/Graphics/Characters/" + f) if File.exist?(BES + "/Graphics/Characters/" + f) }
tipos = {}
File.read(BES + "/PBS/trainertypes.txt", encoding: "bom|utf-8").each_line do |l|
  p = l.chomp.split(","); tipos[p[0].to_i] = p if p.length > 2 && p[0].strip =~ /\A\d+\z/
end
n = 0
Dir.children(BES + "/Graphics/Battlers/Trainers").each do |f|
  next if f !~ /\A(trainer|trback)(\d{3}|[A-Z0-9_]+)\.png\z/
  clase = $2; pre = $1
  nombre = clase =~ /\A\d+\z/ ? (tipos[clase.to_i] ? tipos[clase.to_i][1] : nil) : clase
  next if !nombre
  n += 1 if copiar(BES + "/Graphics/Battlers/Trainers/" + f, SKY + "/Graphics/Trainers/" + nombre + (pre == "trback" ? "_back" : "") + ".png")
end
$inf << "Graphics/Trainers            %4d sprites de entrenador" % n
# 4. audio
%w(Audio/BGM Audio/BGS Audio/ME).each { |s| copiar_carpeta(s, false) }
# de los SE solo los propios y los de las puertas de BES: el resto son los de Essentials, que Sky ya trae
["Ostinato fregando.wav", "Exit Door.ogg", "Entering Door.ogg"].each { |f| copiar(BES + "/Audio/SE/" + f, SKY + "/Audio/SE/" + f, false) }
["Victory - Trainer.ogg", "Victory - Wild Pokemon.ogg"].each { |f| copiar(BES + "/Audio/ME/" + f, SKY + "/Audio/BGM/" + f, false) }
# 5. PBS
pbs = SKY + "/PBS"
meta = File.read(pbs + "/metadata.txt", encoding: "bom|utf-8").gsub("\r\n", "\n")
poner = lambda do |bloque, clave, valor|
  re = /(^\[#{bloque}\]\n(?:(?!^\[).)*?)^#{clave} = .*?$/m
  if meta =~ re then meta = meta.sub(re) { $1 + "#{clave} = #{valor}" }
  else meta = meta.sub(/^\[#{bloque}\]\n/) { $& + "#{clave} = #{valor}\n" } end
end
[["Home","3,7,5,8"],["TrainerBattleBGM","Battle! (Trainer)"],["WildBattleBGM","Battle! (Wild Pokemon)"],
 ["TrainerVictoryBGM","Victory - Trainer"],["WildVictoryBGM","Victory - Wild Pokemon"],["BicycleBGM","Bike"],["SurfBGM","Surf"]].each { |k, v| poner.call(0, k, v) }
poner.call(1, "WalkCharset", "trchar000"); poner.call(1, "RunCharset", "boy_run"); poner.call(1, "CycleCharset", "boy_bike")
# la entrenadora es Kaia: anda con su charset, y corre con el mismo para no cambiar de chica al correr
poner.call(2, "WalkCharset", "kaia"); poner.call(2, "RunCharset", "kaia"); poner.call(2, "CycleCharset", "girl_bike")
File.binwrite(pbs + "/metadata.txt", "\uFEFF" + meta.gsub("\n", "\r\n"))
DATOS = { 2 => ["Outdoor = true", "MapPosition = 0,13,12", "ShowArea = true"],
          3 => ["BattleBack = indoor1", "MapPosition = 0,13,12", "HealingSpot = 2,8,8"],
          9 => ["Outdoor = true", "ShowArea = true"], 10 => ["Outdoor = true", "ShowArea = true"],
          11 => ["Outdoor = true", "ShowArea = true"], 12 => ["Outdoor = true", "ShowArea = true"] }
sal = ["# See the documentation on the wiki to learn how to edit this file."]
MAPAS.each do |m|
  sal += ["#-------------------------------", "[%03d]" % m, "Name = #{infos[m].name}"]
  sal += DATOS[m] if DATOS[m]
  sal << "SnapEdges = true"      # la camara se para en el borde del mapa, como en BES
end
File.binwrite(pbs + "/map_metadata.txt", "\uFEFF" + sal.join("\r\n") + "\r\n")
$inf << "map_metadata.txt: #{MAPAS.size} mapas"
cab = "\uFEFF# See the documentation on the wiki to learn how to edit this file.\r\n"
%w(encounters.txt map_connections.txt).each { |f| File.binwrite(pbs + "/" + f, cab) }
tt = File.read(pbs + "/trainer_types.txt", encoding: "bom|utf-8").gsub("\r\n", "\n")
nuevos = []
tipos.values.each do |p|
  next if tt =~ /^\[#{Regexp.escape(p[1])}\]/
  g = { "Male" => "Male", "Female" => "Female" }[(p[7] || "").strip] || "Unknown"
  nuevos << "#-------------------------------\n[#{p[1]}]\nName = #{p[2]}\nGender = #{g}\nBaseMoney = #{p[3].to_s.empty? ? '30' : p[3]}\n"
end
File.binwrite(pbs + "/trainer_types.txt", "\uFEFF" + (tt.rstrip + "\n" + nuevos.join).gsub("\n", "\r\n")) if !nuevos.empty?
$inf << "trainer_types.txt: #{nuevos.size} clases nuevas"
# 6. creditos
%w(CREDITOS.md Créditos.txt).each { |f| copiar(BES + "/" + f, SKY + "/" + f) if File.exist?(BES + "/" + f) }
$inf << "creditos copiados"
rescue Exception => e
  $inf << "ERROR #{e.class}: #{e.message}\n  " + e.backtrace[0, 5].join("\n  ")
end
File.binwrite("out.txt", $inf.map { |s| s.dup.force_encoding("BINARY") }.join("\n")); exit
