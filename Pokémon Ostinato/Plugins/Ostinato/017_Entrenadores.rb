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

#-------------------------------------------------------------------------------
# OkarPalace y Damian, en el campo de futbol de la ruta 4 (mapa 14): combate
# doble. Fuera de guion, hablan con Kaia con sus dibujos (los dos a la
# izquierda, Kaia a la derecha). Antes, ColTxt00-07: hablan entre ellos del
# festival de verano, mirandose; ColTxt08-12: Kaia les corta y se giran hacia
# ella. Al ganarles, ColTxt13-17.
# Se le puede hablar a cualquiera de los dos; al ganarles, los dos pasan a su
# segunda pagina (interruptor local A de los dos eventos).
#   Pagina 1 de los dos: OstEntrenador.colegas(get_self)
#   Pagina 2 (A):        OstVecinos.hablar("CamTxt", 2, 3)   (bocadillos)
#-------------------------------------------------------------------------------
module OstEntrenador
  COLEGAS = ["OkarPalace", "Damian"]     # nombres de los eventos
  COLEGAS_ARTES = {
    "izq"  => ["DlgOkarPalace.png", 40, 465, "DlgNomOkarPalace"],
    "izq2" => ["DlgDamian.png", 174, 465, "DlgNomDamian"],
    "der"  => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }
  # quien dice cada frase: o = OkarPalace, d = Damian, k = Kaia
  COLEGAS_FESTIVAL = "odododod"
  COLEGAS_ANTES    = "kdodk"
  COLEGAS_DESPUES  = "dokod"

  def self.colegas_charla(desde, quien)
    lados = { "o" => "izq", "d" => "izq2", "k" => "der" }
    guion = quien.chars.each_with_index.map { |c, i| [format("ColTxt%02d", desde + i), lados[c]] }
    OstDlg.run(guion, COLEGAS_ARTES)
  end

  def self.colegas(ev)
    return if !ev
    los_dos = $game_map.events.values.select { |e| COLEGAS.include?(e.name) }
    # estan a lo suyo: se miran y hablan del festival
    a, b = los_dos.sort_by(&:x)
    if a && b
      a.turn_right
      b.turn_left
    end
    colegas_charla(0, COLEGAS_FESTIVAL)
    los_dos.each { |e| e.turn_toward_player rescue nil }
    begin
      pbPlayTrainerIntroBGM(:COLEGAS)
    rescue
    end
    colegas_charla(8, COLEGAS_ANTES)
    setBattleRule(pbCanDoubleBattle? ? "double" : "1v2") rescue nil
    ganado = false
    begin
      ganado = TrainerBattle.start(:COLEGAS, "OkarPalace y Damian")
    rescue => e
      echoln("OstEntrenador.colegas: #{e.message}") rescue nil
    end
    return if !ganado
    los_dos.each { |e| e.turn_toward_player rescue nil }
    colegas_charla(13, COLEGAS_DESPUES)
    los_dos.each { |e| $game_self_switches[[$game_map.map_id, e.id, "A"]] = true }
    $game_map.need_refresh = true
  end
end
