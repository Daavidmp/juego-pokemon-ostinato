#===============================================================================
# Pokemon Ostinato - Ruta 4: los dos secuaces del Silenciador
#
#   Con el Wooloo calmado (SW 93) ya se puede salir de Villa Bambalina por el
#   este (eventos "SalidaEste" del mapa 12: antes de eso Kaia se da la vuelta).
#   En la ruta 4 (mapa 14), un poco mas adelante en el camino, estan los dos
#   secuaces que se escaparon de la plaza ("SecuazChico" y "SecuazChica"),
#   rabiosos porque pensaban que Kaia no podria con el Wooloo. Al acercarse,
#   hablan y pelean: primero el chico y, al ganarle, la chica. Los dos combates
#   entran con el "SECUAZ TE DESAFIA" (015). Si Kaia pierde, se cura el equipo
#   y puede volver a intentarlo (contra el que le falte).
#
#   Interruptores: 94 = secuaz chico vencido, 95 = los dos vencidos (se han ido).
#   Textos: recursos/guion_secuaces_wooloo.txt (SecTxt19 a SecTxt33).
#   Musica del combate: Audio/BGM "Combate secuaces" (si no esta, Combate Lira).
#   Fondo del combate: Graphics/Battlebacks/ruta4_bg (si no esta, el del mapa).
#===============================================================================
module OstRuta4
  MAPA        = 14
  SW_CALMADO  = OstSecuaces::SW_CALMADO
  SW_ESCENA   = OstSecuaces::SW_ESCENA
  SW_CHICO    = 94
  SW_LOS_DOS  = 95
  CERCA       = 3                      # a cuantas casillas del secuaz salta la escena
  HUIDA       = [24, 44]               # por donde se van: escaleras arriba
  BAJAR       = 110                    # en su combate, rival y Pokemon mas abajo: pisan el camino, no el terraplen
  MUSICA      = "Combate secuaces"
  MUSICA_SI_NO = "Combate Lira"
  ARTES       = OstSecuaces::ARTES

  def self.t(i, lado); return ["SecTxt%02d" % i, lado]; end
  def self.chico; return OstMapa.evento("SecuazChico"); end
  def self.chica; return OstMapa.evento("SecuazChica"); end

  #--- la salida del este de Villa Bambalina, antes de tiempo -------------------
  # (pagina 1 de los eventos "SalidaEste"; la pagina 2, con SW 93, es el paso)
  def self.no_puedo
    OstDlg.run([t($game_switches[SW_ESCENA] ? 20 : 19, "der")], ARTES)
    $game_player.turn_left
    OstinatoLaboratorio.mover($game_player, [PBMoveRoute::LEFT])
  end

  #--- cuando toca -------------------------------------------------------------
  def self.toca?
    return false if !$game_map || $game_map.map_id != MAPA
    return false if !$game_switches[SW_CALMADO] || $game_switches[SW_LOS_DOS]
    a = chico
    return false if !a
    dx = a.x - $game_player.x
    return dx >= 0 && dx <= CERCA && ($game_player.y - a.y).abs <= 1
  end

  def self.comprobar
    return if @corriendo || !$game_player || $game_player.moving?
    return if $game_temp && ($game_temp.message_window_showing || $game_temp.player_transferring || $game_temp.in_battle)
    return if !toca?
    @corriendo = true
    begin
      escena
    rescue StandardError => e
      echoln("OstRuta4: #{e.class}: #{e.message}\n#{e.backtrace[0, 5].join("\n")}") rescue nil
    ensure
      @corriendo = false
    end
  end

  #--- la escena -----------------------------------------------------------------
  def self.escena
    a = chico; b = chica
    $game_player.turn_right
    [a, b].each { |e| e.turn_left if e }
    sonaba = false
    begin
      $game_system.bgm_memorize
      pbBGMPlay("Secuaces", 80)
      sonaba = true
    rescue
    end
    begin; pbExclaim(a); rescue; end
    OstDlg.esperar(0.3)
    if !$game_switches[SW_CHICO]
      OstDlg.run([t(21, "izq"), t(22, "izq2"), t(23, "izq"), t(24, "izq2"), t(25, "der"), t(26, "izq")], ARTES)
      return perdido(sonaba, "izq") if !combate(:SECUAZ_CHICO)
      $game_switches[SW_CHICO] = true
      OstDlg.esperar(0.3)
      OstDlg.run([t(27, "izq"), t(28, "izq2")], ARTES)
    else
      # ya le gano al chico y perdio con la chica: vuelve a por ella
      OstDlg.run([t(28, "izq2")], ARTES)
    end
    return perdido(sonaba, "izq2") if !combate(:SECUAZ_CHICA)
    OstDlg.esperar(0.3)
    OstDlg.run([t(29, "izq2"), t(30, "izq"), t(31, "izq2")], ARTES)
    irse(a, b)
    $game_switches[SW_LOS_DOS] = true
    $game_map.need_refresh = true
    begin; $game_system.bgm_restore; rescue; end if sonaba
    OstDlg.esperar(0.4)
    OstDlg.run([t(32, "der")], ARTES)
  end

  def self.activo?; return @activo; end

  def self.combate(tipo)
    ganado = false
    begin
      @activo = true
      setBattleRule("canLose")
      setBattleRule("backdrop", "ruta4") if !Dir["Graphics/Battlebacks/ruta4_bg.*"].empty?
      musica = Dir["Audio/BGM/#{MUSICA}.*"].empty? ? MUSICA_SI_NO : MUSICA
      $PokemonGlobal.nextBattleBGM = musica
      ganado = TrainerBattle.start(tipo, "Secuaz")
    rescue StandardError => e
      echoln("OstRuta4: el combate no ha podido empezar: #{e.message}") rescue nil
    ensure
      @activo = false
    end
    return ganado
  end

  # pierde Kaia: se rien de ella, se cura el equipo y se aparta un poco
  def self.perdido(sonaba, quien)
    begin; $player.heal_party; rescue; end
    OstDlg.esperar(0.3)
    OstDlg.run([t(33, quien)], ARTES)
    begin; $game_system.bgm_restore; rescue; end if sonaba
    $game_player.turn_left
    OstinatoLaboratorio.mover($game_player, [PBMoveRoute::LEFT, PBMoveRoute::LEFT])
    $game_player.turn_right
  end

  # se van corriendo camino arriba
  def self.irse(a, b)
    [a, b].each_with_index do |e, i|
      next if !e
      pasos = OstMapa.camino(e, HUIDA[0], HUIDA[1] + i) || []
      e.through = true
      e.move_speed = 5 rescue nil
      begin; pbMoveRoute(e, pasos); rescue; end
    end
    n = 0
    while [a, b].any? { |e| e && e.move_route_forcing } && n < 600
      OstDlg.tick; n += 1
    end
    [a, b].each { |e| OstMapa.quitar(e) if e }
  end
end

class Scene_Map
  alias ostruta4_update update
  def update
    ostruta4_update
    OstRuta4.comprobar
  end
end

# los secuaces no tienen nombre: "Secuaz saca a...", no "Secuaz Secuaz saca a..."
class Trainer
  alias ostruta4_full_name full_name
  def full_name
    return @name if [:SECUAZ_CHICO, :SECUAZ_CHICA].include?(@trainer_type)
    return ostruta4_full_name
  end
end

# en el fondo de la ruta 4 el terraplen queda detras: el secuaz y su Pokemon
# bajan para pisar el camino de tierra
class Battle::Scene
  class << self
    alias ostruta4_pbBattlerPosition pbBattlerPosition
    def pbBattlerPosition(index, sideSize = 1)
      ret = ostruta4_pbBattlerPosition(index, sideSize)
      return ret if !OstRuta4.activo? || index.even?
      return [ret[0], ret[1] + OstRuta4::BAJAR]
    end

    alias ostruta4_pbTrainerPosition pbTrainerPosition
    def pbTrainerPosition(side, index = 0, sideSize = 1)
      ret = ostruta4_pbTrainerPosition(side, index, sideSize)
      return ret if !OstRuta4.activo? || side == 0
      return [ret[0], ret[1] + OstRuta4::BAJAR]
    end
  end
end
