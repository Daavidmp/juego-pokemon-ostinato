#===============================================================================
# Prueba automática de la migración a La Base de Sky. NO forma parte del juego.
#
# Solo hace algo si existe el fichero PRUEBA_MIGRACION.txt en la carpeta del juego.
# Recorre el arranque, el menú, la cinemática, el laboratorio y los mapas
# pulsando las teclas él solo, guarda capturas y un registro en
# prueba_migracion/, y cierra el juego. Se borra al terminar la migración.
#===============================================================================
if FileTest.exist?("PRUEBA_MIGRACION.txt")

  module Settings
    remove_const(:SCREEN_SCALE)
    SCREEN_SCALE = 1.0           # en ventana, para no tapar la pantalla entera
  end

  module PruebaMigracion
    DIR = "prueba_migracion/"
    @f = 0
    @tareas = []
    @pulsar = {}                 # tecla => fotograma hasta el que se considera pulsada
    @disparo = {}                # tecla => fotograma en que se "dispara" (trigger)

    def self.log(t)
      File.open(DIR + "log.txt", "a") { |f| f.puts(t) }
    end

    def self.foto(nombre)
      b = Graphics.snap_to_bitmap
      b.to_file(DIR + nombre + ".png")
      b.dispose
      extra = ""
      extra = " · mapa #{$game_map.map_id} (#{$game_player.x},#{$game_player.y})" if $game_map && $game_player && $scene.is_a?(Scene_Map)
      log("foto #{nombre} · búfer #{Graphics.width}x#{Graphics.height}#{extra}")
    rescue Exception => e
      log("ERROR foto #{nombre}: #{e.message}")
    end

    def self.en(n, &blk);  @tareas.push([@f + n, blk]); end
    def self.pulsa(tecla, n = 0); @disparo[tecla] = @f + n; end
    def self.mantener(tecla, desde, frames); en(desde) { @pulsar[tecla] = @f + frames }; end
    def self.f; @f; end
    def self.pulsada?(k); (@pulsar[k] || -1) >= @f; end
    def self.disparada?(k); @disparo[k] == @f; end

    def self.tick
      @f += 1
      listas = @tareas.select { |t| t[0] <= @f }
      @tareas -= listas
      listas.each do |t|
        begin
          t[1].call
        rescue Exception => e
          log("ERROR en tarea (fotograma #{@f}): #{e.class}: #{e.message}\n  " + (e.backtrace || [])[0, 6].join("\n  "))
        end
      end
    end

    def self.paso(nombre)
      yield
      log("OK #{nombre}")
    rescue Exception => e
      log("ERROR #{nombre}: #{e.class}: #{e.message}\n  " + (e.backtrace || [])[0, 10].join("\n  "))
    end

    def self.transferir(mapa, x, y)
      $game_temp.player_new_map_id    = mapa
      $game_temp.player_new_x         = x
      $game_temp.player_new_y         = y
      $game_temp.player_new_direction = 2
      $game_temp.player_transferring  = true
    end
  end
  P_ = PruebaMigracion

  class << Graphics
    alias_method :_prueba_update, :update
    def update
      _prueba_update
      PruebaMigracion.tick
    end
  end

  class << Input
    alias_method :_prueba_trigger, :trigger?
    alias_method :_prueba_press, :press?
    def trigger?(k); return true if PruebaMigracion.disparada?(k); _prueba_trigger(k); end
    def press?(k);   return true if PruebaMigracion.pulsada?(k) || PruebaMigracion.disparada?(k); _prueba_press(k); end
  end

  # --- cinemática: foto y "mantener Enter" 5 s para saltarla; laboratorio: pasa todas las frases ---
  module OstinatoCine
    class << self
      alias_method :_prueba_aviso, :aviso
      def aviso
        P_.en(90) { P_.foto("04_auriculares") }
        _prueba_aviso
      end
      alias_method :_prueba_video, :video
      def video
        P_.en(120) { P_.foto("05_cinematica") }
        P_.mantener(Input::C, 130, 420)
        _prueba_video
        P_.log("cinemática saltada con Enter mantenido (fotograma #{P_.f})")
      end
    end
  end

  module OstinatoLab
    class << self
      alias_method :_prueba_run, :run
      def run
        P_.en(150) { P_.foto("06_laboratorio_arce") }
        P_.en(760) { P_.foto("07_laboratorio_mudkip") }
        40.times { |i| P_.en(170 + i * 60) { P_.pulsa(Input::C) } }
        _prueba_run
        P_.log("escena del laboratorio terminada (fotograma #{P_.f})")
      end
    end
  end

  module Game
    class << self
      alias_method :_prueba_start_new, :start_new
      def start_new
        _prueba_start_new
        P_.log("partida nueva · jugador #{$player.name} · personaje #{$player.character_ID} · " \
               "gráfico #{$game_player.character_name rescue '?'}")
        P_.en(60)  { P_.foto("08_casa_kaia") }
        P_.en(80)  { P_.transferir(43, 7, 7) }
        P_.en(140) { P_.foto("09_habitacion_kaia") }
        P_.en(160) { P_.transferir(2, 20, 17) }
        P_.en(230) { P_.foto("10_pueblo_preludio") }
        P_.en(250) { P_.transferir(7, 13, 19) }
        P_.en(310) { P_.foto("11_laboratorio_antes"); $game_switches[72] = true; $game_map.need_refresh = true }
        P_.en(400) { P_.foto("12_laboratorio_fuga") }
        P_.en(520) { P_.foto("13_laboratorio_fuga_2") }
        P_.en(900) do
          P_.foto("14_laboratorio_despues")
          P_.log("SW 72 = #{$game_switches[72]} · SW 73 (los tres se han escapado) = #{$game_switches[73]}")
          P_.log("FIN")
          $scene = nil
        end
      end
    end
  end

  class Scene_Intro
    def main
      Graphics.transition(0)
      Dir.mkdir("prueba_migracion") rescue nil
      File.delete(PruebaMigracion::DIR + "log.txt") rescue nil
      P_.log("INICIO · #{Time.now} · búfer #{Graphics.width}x#{Graphics.height} · plugins: #{(PluginManager.plugins rescue []).inspect}")
      salida = :ok
      P_.paso("arranque (vídeo de marca y portada)") do
        OstinatoHD.con do
          vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
          vp.z = 99999
          P_.en(120) { P_.foto("01_video_marca") }
          OstinatoArranque.intro(vp)
          OstinatoArranque.musica_menu
          P_.en(150) { P_.foto("02_portada") }
          P_.en(170) { P_.pulsa(Input::C) }
          salida = OstinatoArranque.portada(vp)
          vp.dispose
        end
      end
      P_.en(120) { P_.foto("03_menu_titulo") }
      P_.en(140) { P_.pulsa(Input::DOWN) }
      P_.en(170) { P_.foto("03b_menu_titulo_bajado") }
      P_.en(190) { P_.pulsa(Input::UP) }
      P_.en(220) { P_.pulsa(Input::C) }      # la primera placa: Nueva partida
      P_.paso("menú de título y partida nueva") do
        sscene = PokemonLoad_Scene.new
        sscreen = PokemonLoadScreen.new(sscene)
        sscreen.pbStartLoadScreen
      end
      Graphics.freeze
    end
  end

  # en debug la v21 arranca por Scene_DebugIntro: que la prueba pase igual por el arranque
  def pbCallTitle
    return Scene_Intro.new
  end
end
