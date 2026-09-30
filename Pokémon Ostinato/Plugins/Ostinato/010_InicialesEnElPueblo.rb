#===============================================================================
# Pokemon Ostinato - Los tres iniciales, escondidos por Pueblo Preludio
#
#   Despues de la fuga (SW 73, "los tres se han escapado") salen repartidos por
#   el pueblo, cada uno en un sitio que le pega: Mudkip en la fuente, Fennekin
#   en la hierba alta de debajo del laboratorio y Sprigatito en el columpio.
#
#   Son eventos del mapa 2 llamados "Mudkip", "Fennekin" y "Sprigatito",
#   colocados con RPG Maker. Sus paginas:
#     1 sin condicion: vacia (antes de la fuga no estan)
#     2 interruptor 73: su dibujo, y al hablarle OstinatoIniciales.hablar(i)
#     3 su interruptor de "te sigue" (85, 86, 87): vacia
#     4 su interruptor de "devuelto" (74, 75, 76): vacia
#   (el 74-76 son los SW 0024-0026 del guion, +50).
#
#   Al hablarles sale su acotacion (IniTxt, recursos/guion_iniciales_pueblo.txt)
#   y empieza su minijuego. Al ganarlo "se encarina contigo" y te sigue con
#   los Followers de la v21, hasta que lo devuelvas al laboratorio.
#   Minijuegos: Mudkip (013_MiniMudkip.rb), Fennekin (012_MiniFennekin.rb) y
#   Sprigatito (011_MiniSprigatito.rb).
#===============================================================================
module OstinatoIniciales
  # texto, interruptor de "devuelto", interruptor de "te sigue", texto de
  # "se ha encarinado", nombre (el del evento y el del seguidor), minijuego
  TRES = [
    ["IniTxt00", 74, 85, "IniTxt03", "Mudkip",     "OstinatoMiniMudkip"],
    ["IniTxt01", 75, 86, "IniTxt04", "Fennekin",   "OstinatoMiniFennekin"],
    ["IniTxt02", 76, 87, "IniTxt05", "Sprigatito", "OstinatoMiniSprigatito"]
  ]

  def self.hablar(i)
    g = TRES[i]
    return if !g
    OstDlg.run([[g[0], "cap"]], {})
    return if !g[5] || !Object.const_defined?(g[5])
    ganado = Object.const_get(g[5]).jugar
    return if !ganado
    begin
      pbMEPlay("Pkmn get")
    rescue
    end
    OstDlg.run([[g[3], "cap"]], {})
    seguir(i)
  end

  # Pasa a ser un seguidor de Kaia (el sistema Followers de la v21). Primero
  # el seguidor, que copia el dibujo del evento, y despues el interruptor, que
  # deja vacia la pagina del evento del mapa.
  def self.seguir(i)
    g = TRES[i]
    ev = OstMapa.evento(g[4])
    begin
      Followers.add(ev.id, g[4], nil) if ev
    rescue
    end
    $game_switches[g[2]] = true
    $game_map.need_refresh = true
  end
end
