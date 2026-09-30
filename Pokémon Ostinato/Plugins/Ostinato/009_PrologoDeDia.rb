#===============================================================================
# Pokemon Ostinato - Durante el prologo siempre es de dia
#
#   Desde que empieza la partida hasta que Kaia sale del pueblo por primera vez,
#   la hora del juego es mediodia, diga lo que diga el reloj del ordenador: los
#   mapas de exterior llevan el tinte de dia y PBDayNight.isDay? es verdad.
#
#   El prologo se acaba al llegar a la ruta 1 con la salida ya abierta (SW 78).
#   En ese momento se enciende el SW 84, "fuera del pueblo" (el SW 0034 del
#   guion, +50), y a partir de ahi manda el reloj de verdad. El tinte cacheado
#   se renueva solo en unos segundos.
#===============================================================================
module OstinatoDia
  SW_FUERA   = 84    # "fuera del pueblo": se acaba el prologo
  SW_SALIDA  = 78    # la salida sur ya esta abierta
  MAPA_RUTA1 = 9
  HORA       = 12

  def self.prologo?
    return false if !$game_switches
    return !$game_switches[SW_FUERA]
  end
end

alias ostinato_dia_pbGetTimeNow pbGetTimeNow

def pbGetTimeNow
  t = ostinato_dia_pbGetTimeNow
  return t if !OstinatoDia.prologo?
  return Time.local(t.year, t.month, t.day, OstinatoDia::HORA, 0, 0)
end

EventHandlers.add(:on_enter_map, :ostinato_fuera_del_pueblo,
  proc { |_old_map_id|
    next if !$game_map || !$game_switches
    next if $game_map.map_id != OstinatoDia::MAPA_RUTA1
    next if !$game_switches[OstinatoDia::SW_SALIDA]
    $game_switches[OstinatoDia::SW_FUERA] = true
  }
)
