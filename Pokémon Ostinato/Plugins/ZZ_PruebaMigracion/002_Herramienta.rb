#===============================================================================
# Herramienta de desarrollo. NO forma parte del juego.
#
# Solo hace algo si existe HERRAMIENTA.rb en la carpeta del juego: en vez del
# arranque, ejecuta ese fichero dentro del motor. Sirve para mirar un mapa,
# sacar capturas o probar una escena suelta sin pasar por el menu.
# Lo que escribe va a herramienta/ (log.txt y las capturas).
#===============================================================================
if FileTest.exist?("HERRAMIENTA.rb")

  module Settings
    remove_const(:SCREEN_SCALE)
    SCREEN_SCALE = 1.0
  end

  module H
    DIR = "herramienta/"
    @f = 0
    @tareas = []
    @pulsar = {}
    @disparo = {}

    def self.log(t)
      File.open(DIR + "log.txt", "a") { |f| f.puts(t) }
    end

    def self.foto(nombre)
      b = Graphics.snap_to_bitmap
      b.to_file(DIR + nombre + ".png")
      b.dispose
      log("foto #{nombre}")
    rescue Exception => e
      log("ERROR foto #{nombre}: #{e.message}")
    end

    def self.en(n, &blk); @tareas.push([@f + n, blk]); end
    def self.pulsa(tecla, n = 0); @disparo[tecla] = @f + n; end
    def self.mantener(tecla, frames); @pulsar[tecla] = @f + frames; end
    def self.f; @f; end
    def self.pulsada?(k); (@pulsar[k] || -1) >= @f; end
    def self.disparada?(k); @disparo[k] == @f; end

    # Pulsa Enter cada tantos fotogramas, para pasar dialogos solos.
    def self.enter_cada(n, veces)
      veces.times { |i| en(n * (i + 1)) { pulsa(Input::USE) } }
    end

    def self.tick
      @f += 1
      listas = @tareas.select { |t| t[0] <= @f }
      @tareas -= listas
      listas.each do |t|
        begin
          t[1].call
        rescue Exception => e
          log("ERROR en tarea (fotograma #{@f}): #{e.class}: #{e.message}\n  " + (e.backtrace || [])[0, 8].join("\n  "))
        end
      end
    end

    # Partida nueva sin cinematica, directamente en un mapa.
    def self.partida(mapa, x, y, dir = 8)
      Game.start_new
      pbChangePlayer(2)
      $player.name = "Kaia"
      $game_player.refresh
      $game_temp.player_new_map_id    = mapa
      $game_temp.player_new_x         = x
      $game_temp.player_new_y         = y
      $game_temp.player_new_direction = dir
      $game_temp.player_transferring  = true
    end

    def self.terminar
      log("FIN")
      $scene = nil
    end
  end

  class << Graphics
    alias_method :_herramienta_update, :update
    def update
      _herramienta_update
      H.tick
    end
  end

  class << Input
    alias_method :_herramienta_trigger, :trigger?
    alias_method :_herramienta_press, :press?
    def trigger?(k); return true if H.disparada?(k); _herramienta_trigger(k); end
    def press?(k);   return true if H.pulsada?(k) || H.disparada?(k); _herramienta_press(k); end
  end

  class Scene_Intro
    def main
      Graphics.transition(0)
      Dir.mkdir("herramienta") rescue nil
      File.delete(H::DIR + "log.txt") rescue nil
      H.log("INICIO #{Time.now}")
      begin
        eval(File.read("HERRAMIENTA.rb"), TOPLEVEL_BINDING, "HERRAMIENTA.rb")
      rescue Exception => e
        H.log("ERROR #{e.class}: #{e.message}\n  " + (e.backtrace || [])[0, 10].join("\n  "))
        $scene = nil
      end
      Graphics.freeze
    end
  end

  def pbCallTitle
    return Scene_Intro.new
  end
end
