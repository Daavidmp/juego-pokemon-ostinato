# Para el combate en línea (2.4.1): qué dibujo usa Pokémon Ostinato en combate para cada especie, forma, sexo y
# variocolor (los animados de Graphics/Pokemon/Animados, como el plugin 033; si no hay, el fijo), a qué velocidad va su
# tira, y las medidas de la especie (species_metrics) con las que el juego lo coloca.
#
#   ruby exportar_sprites.rb <carpeta del juego> <ids.json de especies> <salida.json>
require 'json'
require_relative 'carga'
$stdout = $stderr
cargar_ostinato
GameData.load_all
juego, ids, salida = ARGV
especies = JSON.parse(File.read(ids))     # nombres internos de las especies de la 1.ª a la 6.ª generación
resultado = {}

def archivo(dir, sp, form, genero, shiny, back)
  ret = GameData::Species.check_graphic_file(dir, sp, form, genero, shiny, false, back ? 'Back' : 'Front')
  return nil if !ret || File.basename(ret).start_with?('000')
  return nil if shiny && !ret.include?(' shiny/')
  ret
rescue StandardError
  nil
end

GameData::Species.each do |s|
  next if !especies.include?(s.species.to_s)
  m = GameData::SpeciesMetrics.get_species_form(s.species, s.form)
  formas = {}
  [0, 1].each do |genero|
    [false, true].each do |shiny|
      [false, true].each do |back|
        clave = "#{genero == 1 ? 'h' : 'm'}#{shiny ? 's' : ''}#{back ? 'b' : 'f'}"
        anim = archivo('Graphics/Pokemon/Animados/', s.species, s.form, genero, shiny, back)
        fijo = archivo('Graphics/Pokemon/', s.species, s.form, genero, shiny, back) ||
               archivo('Graphics/Pokemon/', s.species, s.form, genero, false, back)
        # la velocidad de su tira, como OstAnimados.velocidad
        sp = s.species.to_s
        claves = []
        claves << "#{sp}_#{s.form}_female" if s.form > 0 && genero == 1
        claves << "#{sp}_#{s.form}" if s.form > 0
        claves << "#{sp}_female" if genero == 1
        claves << sp
        v = nil
        claves.each { |c| break if (v = OstAnimados::VELOCIDAD[c]) }
        vel = v ? (back ? v[0] : (v[1] || v[0])) : 2
        formas[clave] = {anim: anim, fijo: fijo, vel: vel}
      end
    end
  end
  resultado["#{s.species}_#{s.form}"] = {
    back: m.back_sprite, front: m.front_sprite, altitud: m.front_sprite_altitude, sombra_x: m.shadow_x, sombra: m.shadow_size,
    mega: s.respond_to?(:mega_stone) ? !s.mega_stone.nil? : false, dibujos: formas
  }
end
File.write(salida, JSON.generate(resultado))
puts "#{resultado.size} especies y formas"
