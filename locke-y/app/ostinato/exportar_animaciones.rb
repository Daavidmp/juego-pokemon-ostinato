# Exporta las animaciones de combate de Pokémon Ostinato (Data/PkmnAnimations.rxdata) para que la app de Pokelocke
# las reproduzca en el combate en línea (2.4.0):
#
#   ruby exportar_animaciones.rb <carpeta del juego> <salida>
#
# Sale <salida>/<n>.json por animación (la misma numeración que usa el motor: los sucesos 'anim' traen el número),
# <salida>/indice.json ({nombre: número} de las comunes, «Common:StatUp»...) y <salida>/usados.json (los gráficos de
# Graphics/Animations y los sonidos de Audio/SE que hacen falta, para copiarlos).
# Cada pieza (cel) va en una lista corta: [x, y, zoom_x, ángulo, espejo, mezcla, visible, patrón, opacidad, zoom_y,
# color_r, color_g, color_b, color_a, prioridad, foco]; cada momento (timing): {f, tipo, se, vol, tono, flash, color, dura,
# bg...}.
require 'json'
require 'fileutils'
require_relative 'carga'
$stdout = $stderr
cargar_ostinato
GameData.load_all
juego, salida = ARGV
FileUtils.mkdir_p(salida)
anims = pbLoadBattleAnimations
graficos, sonidos, comunes = {}, {}, {}
C = AnimFrame
anims.each_with_index do |a, n|
  next if !a
  comunes[a.name] = n if a.name.to_s.start_with?('Common:')
  frames = (0...a.length).map do |f|
    fr = a[f] || []
    fr.map do |cel|
      next nil if !cel
      [cel[C::X], cel[C::Y], cel[C::ZOOMX], cel[C::ANGLE], cel[C::MIRROR], cel[C::BLENDTYPE], cel[C::VISIBLE], cel[C::PATTERN],
       cel[C::OPACITY], cel[C::ZOOMY], cel[C::COLORRED], cel[C::COLORGREEN], cel[C::COLORBLUE], cel[C::COLORALPHA],
       cel[C::PRIORITY], cel[C::FOCUS]].map { |v| v.is_a?(Numeric) ? v.round(2) : v }
    end
  end
  tiempos = (a.timing || []).map do |t|
    sonidos[t.name] = true if t.timingType == 0 && t.name && !t.name.empty?
    graficos[t.name] = true if [1, 3].include?(t.timingType) && t.name && !t.name.empty?
    c = t.flashColor
    {f: t.frame, tipo: t.timingType, se: t.name, vol: t.volume, tono: t.pitch, flash: t.flashScope,
     color: c ? [c.red, c.green, c.blue, c.alpha] : nil, dura: t.flashDuration,
     bgx: t.bgX, bgy: t.bgY, op: t.opacity, bgcolor: [t.colorRed, t.colorGreen, t.colorBlue, t.colorAlpha], dur: t.duration}
  end
  graficos[a.graphic] = true if a.graphic && !a.graphic.empty?
  File.write(File.join(salida, "#{n}.json"),
             JSON.generate({n: a.name, g: a.graphic, h: a.hue, p: a.position, f: frames, t: tiempos}))
end
File.write(File.join(salida, 'indice.json'), JSON.generate(comunes))
File.write(File.join(salida, 'usados.json'), JSON.generate({graficos: graficos.keys, sonidos: sonidos.keys}))
puts "#{anims.length} animaciones, #{graficos.size} gráficos, #{sonidos.size} sonidos"
