require "json"
module GameData; class Trainer; end; class TrainerType; end; end
J = ARGV[0]; d = JSON.parse(File.read(ARGV[1]))
GEN = { "Male" => 0, "Female" => 1, "Mixed" => 2 }
tt = Marshal.load(File.binread(J + "/Data/trainer_types.dat"))
base = tt[:APICULTOR]
d["tipos"].each do |id, nombre, gen, dinero|
  o = Marshal.load(Marshal.dump(base))
  o.instance_variable_set(:@id, id.to_sym); o.instance_variable_set(:@real_name, nombre)
  o.instance_variable_set(:@gender, GEN[gen]); o.instance_variable_set(:@base_money, dinero); o.instance_variable_set(:@skill_level, dinero)
  tt[id.to_sym] = o
end
t = Marshal.load(File.binread(J + "/Data/trainers.dat"))
bt = t[[:APICULTOR, "Panal", 0]]
d["equipos"].each do |tipo, nombre, lose, eq|
  o = Marshal.load(Marshal.dump(bt))
  key = [tipo.to_sym, nombre, 0]
  o.instance_variable_set(:@id, key); o.instance_variable_set(:@trainer_type, tipo.to_sym); o.instance_variable_set(:@real_name, nombre)
  o.instance_variable_set(:@real_lose_text, lose); o.instance_variable_set(:@real_lose_text_f, lose)
  o.instance_variable_set(:@pokemon, eq.map { |sp, lv| { :species => sp.to_sym, :level => lv } })
  t[key] = o
end
File.binwrite(J + "/Data/trainer_types.dat", Marshal.dump(tt))
File.binwrite(J + "/Data/trainers.dat", Marshal.dump(t))
tt2 = Marshal.load(File.binread(J + "/Data/trainer_types.dat")); t2 = Marshal.load(File.binread(J + "/Data/trainers.dat"))
puts "tipos #{tt2.size} (#{d['tipos'].map { |x| tt2.key?(x[0].to_sym) }.all?}), entrenadores #{t2.size}"
x = t2[[:HERMANOS_CAMPISTAS, "Lía y Nico", 0]]; puts x.instance_variable_get(:@pokemon).inspect, x.instance_variable_get(:@real_name).encoding
