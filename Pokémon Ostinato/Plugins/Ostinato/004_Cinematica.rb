#===============================================================================
# Pokemon Ostinato - Cinematica de apertura
#
#   Se reproduce al elegir "Nueva partida", despues de cerrar el titulo y ANTES
#   de cargar el mapa, asi que cae justo antes de que aparezca la profesora.
#
#   MKXP-Z NO reproduce video. Dentro de Game.exe la funcion esta como
#   "Graphics.playMovie(%s) not implemented" y no hay ni una libreria de codec
#   enlazada (nada de avcodec, theora, webm ni vpx). Por eso la cinematica va
#   como secuencia de JPEG + un mp3 aparte para el sonido, que es la misma via
#   que ya usa el video de marca del arranque.
#
#   El fotograma se elige por RELOJ, no contando vueltas del bucle: si el motor
#   pierde fotogramas se salta imagen pero NO se desincroniza de la voz. En una
#   pieza de cuatro minutos con narracion eso es la diferencia entre que cuadre
#   y que no.
#
#   Arriba a la derecha, un boton con el simbolo de Enter y, a su izquierda,
#   "Manten para saltar". Al mantener Enter, un aro va cerrandose alrededor del
#   icono; completa a los 5 s y entonces se salta.
#===============================================================================
module OstinatoCine
  DIR   = "Graphics/Titles/OstinatoCine/"
  COUNT = 4811                 # c0001.jpg .. c4811.jpg
  VFPS  = 20.0                 # fotogramas por segundo de la cinematica
  BGM   = "OstinatoCine"       # Audio/BGM/OstinatoCine.mp3

  HOLD_SEG  = 5.0              # cuanto hay que mantener Enter
  SOLTADO_X = 3.0              # al soltar, el aro se vacia a esta velocidad

  HOJA = "Graphics/Titles/CineSkip.png"    # boton + aro, en casillas
  TEXTO = "Graphics/Titles/CineSkipTxt.png"
  AVISO = "Graphics/Titles/CineAviso.png"  # cartela de auriculares, al acabar
  AVISO_SEG = 4.5                          # cuanto se queda si no se pulsa nada
  TILE  = 158
  COLS  = 11
  PASOS = 121                  # casilla 0 = aro vacio, 120 = aro completo

  BASE_W = 1920.0              # medida para la que estan dibujados los graficos
  MARGEN_DER = 39
  MARGEN_SUP = 34
  HUECO = -6                   # separacion entre el texto y el boton; negativa
                               # porque la casilla del icono ya trae relleno
                               # propio alrededor del aro

  def self.gw
    begin; return Graphics.width; rescue; return 682; end
  end

  def self.gh
    begin; return Graphics.height; rescue; return 384; end
  end

  def self.bmp(path)
    begin
      return Bitmap.new(path)
    rescue
      return nil
    end
  end

  def self.soltar(sprite)
    return if !sprite || sprite.disposed?
    b = sprite.bitmap
    sprite.dispose
    b.dispose if b && !b.disposed?
  end

  # Si falta el material, la cinematica se salta en silencio y el juego sigue.
  def self.disponible?
    b = bmp(sprintf("%sc%04d.jpg", DIR, 1))
    return false if !b
    b.dispose
    return true
  end

  #-----------------------------------------------------------------------------
  # Cartela de aviso con la misma tipografia que la cinematica. Sustituye al
  # mensaje de sistema que salia aqui. El dibujo esta hecho al tamano real del
  # bufer, asi que el zoom nominal es Graphics.width/ancho (el resizer del juego
  # lo vuelve a multiplicar por el factor de escala y queda 1:1 y nitido).
  def self.aviso
    ab = bmp(AVISO)
    return if !ab

    vp = Viewport.new(0, 0, gw, gh)
    vp.z = 99999
    sp = Sprite.new(vp)
    sp.z = 10
    sp.bitmap = ab
    sp.zoom_x = gw.to_f / ab.width
    sp.zoom_y = gh.to_f / ab.height
    sp.x = 0
    sp.y = 0
    sp.opacity = 0

    begin
      o = 0
      while o < 255
        o += 12
        o = 255 if o > 255
        sp.opacity = o
        Graphics.update
        Input.update
      end

      t0 = Time.now
      armado = false
      loop do
        Graphics.update
        Input.update
        pulsado = Input.press?(Input::C) || Input.press?(Input::B)
        armado = true if !pulsado
        break if pulsado && armado
        break if (Time.now - t0) >= AVISO_SEG
      end

      o = 255
      while o > 0
        o -= 12
        o = 0 if o < 0
        sp.opacity = o
        Graphics.update
        Input.update
      end
    ensure
      soltar(sp)
      begin; vp.dispose; rescue; end
    end
  end

  #-----------------------------------------------------------------------------
  # El aviso de los auriculares va DELANTE del video: puesto detras no servia de
  # nada, porque lo que hay que oir con auriculares es justo el video.
  def self.run
    aviso
    video
  end

  #-----------------------------------------------------------------------------
  def self.video
    return if !disponible?

    e  = gw.to_f / BASE_W
    vp = Viewport.new(0, 0, gw, gh)
    vp.z = 99999

    fondo = Sprite.new(vp)
    fondo.z = 0
    fondo.bitmap = Bitmap.new(gw, gh)
    fondo.bitmap.fill_rect(0, 0, gw, gh, Color.new(0, 0, 0))

    cine = Sprite.new(vp)
    cine.z = 10

    aro = Sprite.new(vp)
    aro.z = 20
    hb = bmp(HOJA)
    if hb
      aro.bitmap = hb
      aro.src_rect = Rect.new(0, 0, TILE, TILE)
      aro.zoom_x = e
      aro.zoom_y = e
      aro.x = (gw - (MARGEN_DER + TILE) * e).to_i
      aro.y = (MARGEN_SUP * e).to_i
    end

    texto = Sprite.new(vp)
    texto.z = 20
    tb = bmp(TEXTO)
    if tb && hb
      texto.bitmap = tb
      texto.zoom_x = e
      texto.zoom_y = e
      texto.x = (aro.x - (HUECO * e) - tb.width * e).to_i
      texto.y = (aro.y + (TILE * e - tb.height * e) / 2.0).to_i
    end

    begin
      pbBGMPlay(BGM)
    rescue
    end

    t0 = Time.now
    tprev = t0
    ultimo = -1
    pasoant = -1
    hold = 0.0
    # Se llega aqui con Enter pulsado (es la tecla con la que se ha elegido
    # "Nueva partida"), asi que el aro no cuenta hasta que se suelte una vez.
    armado = false

    begin
      loop do
        Graphics.update
        Input.update

        ahora = Time.now
        dt = ahora - tprev
        tprev = ahora
        dt = 0.0 if dt < 0.0
        dt = 0.25 if dt > 0.25   # si la ventana se atasca, no regalar progreso

        # --- imagen, elegida por reloj ---
        i = ((ahora - t0) * VFPS).to_i + 1
        break if i > COUNT
        if i != ultimo
          nb = bmp(sprintf("%sc%04d.jpg", DIR, i))
          if nb
            vieja = cine.bitmap
            cine.bitmap = nb
            vieja.dispose if vieja && !vieja.disposed?
            cine.zoom_x = gw.to_f / nb.width
            cine.zoom_y = gh.to_f / nb.height
            cine.x = 0
            cine.y = 0
          end
          ultimo = i
        end

        # --- mantener Enter para saltar ---
        pulsado = Input.press?(Input::C)
        armado = true if !pulsado
        if pulsado && armado
          hold += dt
        else
          hold -= dt * SOLTADO_X
          hold = 0.0 if hold < 0.0
        end
        break if hold >= HOLD_SEG

        if hb
          paso = ((PASOS - 1) * hold / HOLD_SEG).to_i
          paso = PASOS - 1 if paso > PASOS - 1
          paso = 0 if paso < 0
          if paso != pasoant
            aro.src_rect = Rect.new((paso % COLS) * TILE, (paso / COLS) * TILE, TILE, TILE)
            pasoant = paso
          end
        end
      end
    ensure
      # se apaga a negro; la musica del mapa entra despues con autoplay
      begin
        pbBGMFade(0.6)
      rescue
        begin; pbBGMStop; rescue; end
      end
      o = 255
      while o > 0
        o -= 9
        o = 0 if o < 0
        cine.opacity = o
        aro.opacity = o
        texto.opacity = o
        begin
          Graphics.update
          Input.update
        rescue
          break
        end
      end
      soltar(texto)
      soltar(aro)
      soltar(cine)
      soltar(fondo)
      begin; vp.dispose; rescue; end
    end
  end
end

#===============================================================================
# Se vuelve a registrar "Nueva partida" con la cinematica metida en medio.
# MenuHandlers.add guarda en un hash por clave, asi que esto SUSTITUYE al
# manejador de Ostinato_TitleScreen en vez de anadir un boton repetido.
# Se mantiene "order" => 10 para que el boton siga en su sitio.
#===============================================================================
# Donde empieza la partida de verdad, saltandose Map001 (la intro de la demo).
# Sale de "Home=3,7,5,8" en PBS/metadata.txt: mapa 3, casa de Kaia.
INICIO_MAPA = 3
INICIO_X    = 7
INICIO_Y    = 5

MenuHandlers.add(:load_screen, :new_game, {
  "name"  => _INTL("Nueva partida"),
  "order" => 10,
  "effect" => proc { |screen|
    screen.scene.pbEndScene
    OstinatoHD.con do
      OstinatoCine.run
      # y donde los juegos de Pokemon ponen al profesor Oak, va la Profesora Arce
      begin
        OstinatoLab.run if defined?(OstinatoLab)
      rescue
      end
    end
    # NO se arranca en el mapa de inicio del proyecto (Map001), que es la intro
    # de la demo tecnica de Essentials BES: se entra directamente en casa de Kaia,
    # el "Home = 3,7,5,8" de PBS/metadata.txt. Game.start_new (v21) empieza donde
    # dice $data_system, asi que se le da ese sitio antes de llamarlo.
    $data_system.start_map_id = INICIO_MAPA
    $data_system.start_x      = INICIO_X
    $data_system.start_y      = INICIO_Y
    Game.start_new
    # Como la intro de la demo era tambien la que inicializaba al jugador, hay
    # que hacer aqui lo suyo: tipo de entrenador y nombre. En el guion Arce le
    # dice "Tu eres Kaia", asi que no se pregunta nada.
    begin
      pbChangePlayer(2)                      # 2 = la entrenadora (en BES era PlayerB, el 1)
      $player.name = "Kaia" if $player
      $game_player.refresh
    rescue
    end
    next :exit
  }
})
