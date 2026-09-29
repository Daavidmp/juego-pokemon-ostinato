#===============================================================================
# Pokemon Ostinato - Lo que Essentials BES hacia y La Base de Sky (v21.1) no
#
#   Los scripts de Ostinato se escribieron sobre BES. Aqui estan las piezas de
#   BES de las que dependen, para que el resto funcione igual que antes.
#===============================================================================

#-------------------------------------------------------------------------------
# Pantalla. En BES el juego iba a 682x384 (16:9, cambiado a mano en Settings) y
# a pantalla completa (mkxp.json). La v21 viene a 512x384 y en ventana.
# Y en debug BES iba directo al menu, sin el video de marca.
#-------------------------------------------------------------------------------
module Settings
  remove_const(:SCREEN_WIDTH)
  SCREEN_WIDTH = 682
  remove_const(:SCREEN_SCALE)
  SCREEN_SCALE = 2.5                      # indice 4 de "Tamano de pantalla" = pantalla completa
  remove_const(:SHOW_TITLE_SCREEN_ON_DEBUG)
  SHOW_TITLE_SCREEN_ON_DEBUG = false
end

#-------------------------------------------------------------------------------
# Musica en mp3. La v21 trae ".mp3" comentado en la lista de extensiones de
# audio, asi que Game_System#bgm_play daba por inexistente cualquier pista mp3
# y los mapas se quedaban en silencio (Pueblo Preludio, Casa Kaia, Casa
# Generica, Laboratorio). El motor si las reproduce: lleva libmpg123.
#-------------------------------------------------------------------------------
module FileTest
  if !AUDIO_EXTENSIONS.include?(".mp3")
    exts = AUDIO_EXTENSIONS + [".mp3"]
    remove_const(:AUDIO_EXTENSIONS)
    AUDIO_EXTENSIONS = exts
  end
end

#-------------------------------------------------------------------------------
# Escenas dibujadas a 1920x1080 (arranque, titulo, cinematica, laboratorio).
# En BES se veian nitidas porque su Sprite_Resizer subia el bufer a 1918x1080.
# La v21 no tiene resizer: mientras dura la escena se sube el bufer a 1920x1080
# y al acabar se vuelve a 682x384. Los scripts calculan todo con Graphics.width,
# asi que con el bufer grande el arte queda a escala 1:1, como en BES.
# En ventana se compensa la escala para que la ventana no cambie de tamano.
#-------------------------------------------------------------------------------
module OstinatoHD
  ANCHO = 1920
  ALTO  = 1080

  # Si mkxp.json ya pinta en alta resolucion (enableHires con
  # framebufferScalingFactor de 2 o mas), el arte de 1920 se ve nitido sin
  # tocar el bufer, y subirlo lo multiplicaria otra vez (5760x3240 a 3x).
  def self.alta_resolucion?
    return @alta if !@alta.nil?
    @alta = false
    begin
      cfg = File.read("mkxp.json")
      if cfg =~ /^\s*"enableHires"\s*:\s*true/ &&
         cfg =~ /^\s*"framebufferScalingFactor"\s*:\s*([\d.]+)/
        @alta = ($1.to_f >= 2.0)
      end
    rescue
    end
    return @alta
  end

  def self.subir
    return nil if alta_resolucion?
    w = Graphics.width
    h = Graphics.height
    return nil if w >= ANCHO
    escala = (Graphics.scale rescue 1.0)
    Graphics.resize_screen(ANCHO, ALTO)
    begin
      if !Graphics.fullscreen
        Graphics.scale = escala * w.to_f / ANCHO
        Graphics.center
      end
    rescue
    end
    return [w, h, escala]
  end

  def self.bajar(antes)
    return if !antes
    w, h, escala = antes
    Graphics.resize_screen(w, h) if Graphics.width != w || Graphics.height != h
    begin
      if !Graphics.fullscreen
        Graphics.scale = escala
        Graphics.center
      end
    rescue
    end
  end

  def self.con
    antes = subir
    begin
      return yield
    ensure
      bajar(antes)
    end
  end
end

#-------------------------------------------------------------------------------
# Pantalla de carga con MenuHandlers(:load_screen), como en BES. La de la v21
# tiene los botones fijos; el menu de Ostinato registra los suyos (nueva
# partida, continuar, logros, configuracion, creditos, salir).
#-------------------------------------------------------------------------------
class PokemonLoadScreen
  attr_reader :scene, :save_data

  def showContinue
    return !@save_data.empty?
  end

  def pbStartLoadScreen
    commands = []
    hashes = []
    MenuHandlers.each_available(:load_screen, self) do |option, hash, name|
      commands.push(name)
      hashes.push(hash)
    end
    show_continue = showContinue
    map_id = show_continue ? @save_data[:map_factory].map.map_id : 0
    @scene.pbStartScene(commands, show_continue, @save_data[:player], @save_data[:stats], map_id)
    @scene.pbSetParty(@save_data[:player]) if show_continue
    @scene.pbStartScene2
    loop do
      command = @scene.pbChoose(commands)
      break if command < 0
      result = hashes[command]["effect"].call(self)
      return if result == :exit
    end
    @scene.pbEndScene
  end
end
