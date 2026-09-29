#===============================================================================
# Diagnostico de pantalla. NO forma parte del juego.
# Solo hace algo si existe DIAGNOSTICO.txt: apunta cada segundo en
# diag_registro.txt la escena, la resolucion y el modo de pantalla.
#===============================================================================
if FileTest.exist?("DIAGNOSTICO.txt")
  module Diag
    @f = 0
    def self.tick
      @f += 1
      return if @f % 40 != 0
      linea = "f#{@f} t=#{(System.uptime rescue 0).round(1)} escena=#{$scene.class} " \
              "graphics=#{Graphics.width}x#{Graphics.height} " \
              "fullscreen=#{(Graphics.fullscreen rescue '?')} scale=#{(Graphics.scale rescue '?')} " \
              "brillo=#{Graphics.brightness} debug=#{$DEBUG.inspect}"
      File.open("diag_registro.txt", "a") { |f| f.puts(linea) }
    rescue
    end
  end
  class << Graphics
    alias_method :_diag_update, :update
    def update
      _diag_update
      Diag.tick
    end
  end
end
