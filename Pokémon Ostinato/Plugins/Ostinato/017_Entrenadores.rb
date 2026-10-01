#===============================================================================
# Pokemon Ostinato - Los entrenadores de las rutas
#
#   Son eventos normales de los mapas, llamados "Trainer(N)" (N = casillas a
#   las que te ven), colocados con RPG Maker. Pagina 1 (te ven al pasar, o al
#   hablarles) con una orden de Script:
#       OstEntrenador.pelear(get_self, :CHAVAL, "Tallo", "EntTxt", 0, 0)
#   (tipo, nombre, prefijo de los textos, primera y ultima frase de antes).
#   Pagina 2 (interruptor local A): lo que dice despues, con
#       OstVecinos.hablar("EntTxt", 1, 1)
#
#   Equipos en PBS/trainers.txt; frases en recursos/guion_entrenadores_rutas.txt
#   (textos.ps1 EntTxt). Te ve, se le pone la exclamacion, se acerca, dice su
#   frase, combate y, si le ganas, ya no vuelve a pelear.
#===============================================================================
# los textos sin retrato son los de los vecinos
OstVecinos = OstinatoVecinos if !defined?(OstVecinos)

module OstEntrenador
  # despues (opcional): un proc que se hace al ganarle (Bemol da Pociones)
  def self.pelear(ev, tipo, nombre, prefijo, desde, hasta, version = 0, &despues)
    return if !ev
    begin
      pbNoticePlayer(ev)
    rescue
    end
    begin
      pbPlayTrainerIntroBGM(tipo)
    rescue
    end
    OstVecinos.hablar(prefijo, desde, hasta)
    ganado = false
    begin
      ganado = TrainerBattle.start(tipo, nombre, version)
    rescue => e
      echoln("OstEntrenador: #{e.message}") rescue nil
    end
    return if !ganado
    $game_self_switches[[$game_map.map_id, ev.id, "A"]] = true
    $game_map.need_refresh = true
    despues.call if despues
  end

  # El recadero: despues de perder, "Toma, que era esto", las Pociones, y "Ya esta".
  def self.bemol(ev)
    pelear(ev, :RECADERO, "Bemol", "EntTxt", 6, 7) do
      OstVecinos.hablar("EntTxt", 8, 8)
      begin
        pbReceiveItem(:POTION, 3)
      rescue
      end
      OstVecinos.hablar("EntTxt", 9, 9)
    end
  end
end
