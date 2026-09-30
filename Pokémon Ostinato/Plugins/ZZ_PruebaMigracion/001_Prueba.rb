#===============================================================================
# Prueba automática de la migración a La Base de Sky. NO forma parte del juego.
#
# Solo hace algo si existe el fichero PRUEBA_MIGRACION.txt en la carpeta del juego.
# Recorre el arranque, el menú, la cinemática, la escena de Arce y el prólogo entero
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
        P_.recorrer_prologo
      end
    end
  end

  # --- el prologo entero, usando las mismas puertas que el jugador ---
  #   cuarto (despertar) -> escalera -> cocina y telediario -> puerta de casa
  #   (Lira) -> puerta del laboratorio -> sube por la alfombra (charla y fuga)
  #   -> sale y vuelve a entrar, para ver que la mesa sigue vacia y Lira no esta.
  # Mientras corre una escena se pulsa Enter cada poco y se saca una foto de
  # vez en cuando; entre escena y escena se cruza la puerta que toca.
  module PruebaMigracion
    ESCENAS = [:OstinatoDespertar, :OstinatoCocina, :OstinatoPuerta, :OstinatoLaboratorio]

    def self.ocupado?
      ESCENAS.any? { |n| Object.const_defined?(n) && Object.const_get(n).instance_variable_get(:@corriendo) }
    end

    def self.estado
      ev = $game_map.events.values.select { |e| e.character_name.to_s != "" }.map { |e| "#{e.name}(#{e.x},#{e.y})" }.join(" ")
      "mapa #{$game_map.map_id} kaia(#{$game_player.x},#{$game_player.y}) " \
      "sw101-104=#{(101..104).map { |i| $game_switches[i] ? 1 : 0 }.join} sw72=#{$game_switches[72]} " \
      "sw73=#{$game_switches[73]} sw78=#{$game_switches[78]} #{ev}"
    end

    def self.recorrer_prologo
      log("partida nueva · jugador #{$player.name} · personaje #{$player.character_ID}")
      @hecho = {}
      @fotos = 0
      @ultima_foto = 0
      @ultimo_enter = 0
      @inicio = @f
      vigilar
    end

    def self.vigilar
      en(1) do
        begin
          paso_prologo
        rescue Exception => e
          log("ERROR prologo: #{e.class}: #{e.message}\n  " + (e.backtrace || [])[0, 6].join("\n  "))
        end
        vigilar if !@hecho[:fin]
      end
    end

    def self.foto_escena
      @fotos += 1
      foto("p%03d_mapa%d" % [@fotos, $game_map.map_id])
    end

    def self.paso_prologo
      return if !$scene.is_a?(Scene_Map) || !$game_map
      if @f - @inicio > 60 * 60 * 12
        log("ERROR: el prologo no ha acabado en 12 minutos · #{estado}")
        @hecho[:fin] = true
        $scene = nil
        return
      end
      if ocupado?
        if @f - @ultimo_enter >= 36
          @ultimo_enter = @f
          pulsa(Input::USE)
        end
        if @f - @ultima_foto >= 150
          @ultima_foto = @f
          foto_escena
        end
        return
      end
      return if $game_temp.player_transferring || $game_player.moving?
      mapa = $game_map.map_id
      if mapa == 43 && $game_switches[101] && !@hecho[:cuarto]
        @hecho[:cuarto] = true
        log("despertar visto · #{estado}")
        en(20) { transferir(3, 11, 4) }            # la escalera
      elsif mapa == 3 && $game_switches[102] && !@hecho[:cocina]
        @hecho[:cocina] = true
        log("cocina y telediario vistos · #{estado}")
        en(20) { transferir(2, 33, 20) }           # la puerta de casa
      elsif mapa == 2 && $game_switches[103] && !@hecho[:pueblo]
        @hecho[:pueblo] = true
        log("puerta vista · #{estado}")
        en(20) { transferir(7, 13, 22) }           # la puerta del laboratorio
      elsif mapa == 7 && !$game_switches[104] && !@hecho[:subir]
        @hecho[:subir] = true
        log("en el laboratorio · #{estado}")
        foto("30_laboratorio_entrada")
        pbMoveRoute($game_player, [PBMoveRoute::UP] * 7)   # por la alfombra hasta la fila 15
      elsif mapa == 7 && $game_switches[73] && !@hecho[:fuga]
        @hecho[:fuga] = true
        log("fuga vista · #{estado}")
        log("mesa, capa de arriba: " + (16..18).map { |x| "#{$game_map.data[x, 7, 2]}/#{$game_map.data[x, 8, 2]}" }.join(" "))
        foto("40_laboratorio_despues")
        en(20) { transferir(2, 25, 8) }            # sale a la calle
      elsif mapa == 2 && @hecho[:fuga] && !@hecho[:fuera]
        @hecho[:fuera] = true
        foto("41_pueblo_despues")
        en(40) { transferir(7, 13, 22) }           # y vuelve a entrar
      elsif mapa == 7 && @hecho[:fuera] && !@hecho[:vuelta]
        @hecho[:vuelta] = true
        en(60) do
          $game_player.moveto(13, 12)
          $game_player.center(13, 12) rescue nil
        end
        en(90) do
          foto("42_laboratorio_vuelta")
          log("vuelta al laboratorio · #{estado}")
          log("mesa, capa de arriba: " + (16..18).map { |x| "#{$game_map.data[x, 7, 2]}/#{$game_map.data[x, 8, 2]}" }.join(" "))
          log("FIN")
          @hecho[:fin] = true
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
