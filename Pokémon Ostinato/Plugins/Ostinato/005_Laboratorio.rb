#===============================================================================
# Pokemon Ostinato - Escena del laboratorio
#
#   Va justo despues de la cinematica y del aviso de auriculares, en el hueco
#   donde los juegos de Pokemon ponen al profesor Oak. Aqui sale la Profesora
#   Arce, con el cuadro de dialogo que ha disenado el usuario.
#
#   Sobre las medidas: los graficos de la escena estan hechos a 1920x1080. El
#   Sprite_Resizer redefine x=, y= y zoom_x= para multiplicarlos por el factor
#   del bufer, asi que aqui todo se pasa a medidas NOMINALES dividiendo por
#   1920 y multiplicando por Graphics.width. Resultado: 1:1 en pantalla.
#   src_rect NO lo toca el resizer, asi que va en pixeles del bitmap.
#===============================================================================
module OstinatoLab
  DIR   = "Graphics/Titles/"
  ART_W = 1920.0            # medida real para la que estan hechos los graficos
  ART_H = 1080.0
  BGM   = "Cozy Laboratory" # Audio/BGM/Cozy Laboratory.mp3

  # Que acompana a cada EscTxtNN.png: [retrato de la derecha, sale Mudkip]
  K = "EscKaia.png"
  L = "EscLira.png"
  # Arce lleva la misma cara toda la escena, la de los dos ojos abiertos, que va
  # dentro de EscFondo.png. Los gestos (guino, rie, seria, parpadeo) estan
  # dibujados y guardados en CREDITOS\caras, pero no se usan.
  # Las frases largas se reparten solas en varias pantallas al generar los
  # graficos, asi que aqui hay mas entradas que frases hay en el guion.
  # El orden sale de _datos.txt del generador; si cambia el guion, hay que
  # copiarlo de alli otra vez.
  BEATS = [
    [nil, false], [nil, false], [nil, false], [nil, false],
    [nil, true],  [nil, true],  [nil, true],
    [nil, true],  [nil, true],  [nil, true],
    [nil, false],
    [K, false], [K, false], [K, false],
    [L, false], [L, false],
    [nil, false], [nil, false]
  ]

  # coordenadas en pixeles REALES (luego se pasan a nominales)
  # Contenedor de pergamino: el texto va alineado a la IZQUIERDA dentro del
  # hueco, como en el dibujo del usuario, no centrado.
  TXT_X   = 731             # misma vertical que el titulo, no sangrado
  TXT_Y   = 625
  TXT_W   = 692
  NOM_X   = 731             # el nombre lo dibujo el usuario dentro del cuadro
  NOM_Y   = 588             # bajado para que titulo + texto queden centrados
  # La hoja de la esquina de abajo a la derecha. Va suelta para poder moverla:
  # es la senal de "pulsa para seguir".
  HOJA_X  = 1397
  HOJA_Y  = 696
  # Mudkip: EscMudkip.png es una rejilla de fotogramas ya ampliados (el motor
  # tiene smoothScaling, asi que ampliarlos aqui los dejaria borrosos).
  # src_rect NO lo toca el Sprite_Resizer, asi que va en pixeles del bitmap.
  MUD_FW   = 176
  MUD_FH   = 196
  MUD_COLS = 10
  MUD_N    = 76             # fotogramas distintos de la animacion
  MUD_CADA = 2              # ticks de juego por fotograma
  MUD_X    = 877
  MUD_Y    = 832
  BASE_X   = 837            # la plataforma, centrada bajo el
  BASE_Y   = 988

  ESCRIBE = 37.0            # pixeles de texto revelados por fotograma

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

  def self.soltar(s)
    return if !s || s.disposed?
    b = s.bitmap
    s.dispose
    b.dispose if b && !b.disposed?
  end

  def self.swap(s, nb)
    return if !nb
    v = s.bitmap
    s.bitmap = nb
    v.dispose if v && !v.disposed?
  end

  def self.disponible?
    b = bmp(DIR + "EscFondo.png")
    return false if !b
    b.dispose
    return true
  end

  # Un fotograma de juego. Mudkip se anima aqui dentro para que siga moviendose
  # en todas las esperas: mientras se escribe el texto, mientras se espera a que
  # pulses y durante los fundidos.
  def self.tick
    if @mud && !@mud.disposed? && @mud.opacity > 0
      @mudT += 1
      f = (@mudT / MUD_CADA) % MUD_N
      @mud.src_rect = Rect.new((f % MUD_COLS) * MUD_FW, (f / MUD_COLS) * MUD_FH,
                               MUD_FW, MUD_FH)
    end
    Graphics.update
    Input.update
  end

  #-----------------------------------------------------------------------------
  def self.run
    return if !disponible?

    e = gw.to_f / ART_W            # real -> nominal
    vp = Viewport.new(0, 0, gw, gh)
    vp.z = 99999

    fondo = Sprite.new(vp)
    fondo.z = 10
    fondo.bitmap = bmp(DIR + "EscFondo.png")
    fondo.zoom_x = e
    fondo.zoom_y = e

    retrato = Sprite.new(vp)
    retrato.z = 12
    retrato.zoom_x = e
    retrato.zoom_y = e
    retrato.opacity = 0
    retActual = nil

    caja = Sprite.new(vp)
    caja.z = 20
    caja.zoom_x = e
    caja.zoom_y = e
    caja.opacity = 0
    caja.bitmap = bmp(DIR + "EscCuadroL.png")

    nombre = Sprite.new(vp)
    nombre.z = 21
    nombre.zoom_x = e
    nombre.zoom_y = e
    nombre.opacity = 0
    nombre.bitmap = bmp(DIR + "EscNomArce.png")
    nombre.x = (NOM_X * e).to_i
    nombre.y = (NOM_Y * e).to_i

    texto = Sprite.new(vp)
    texto.z = 22
    texto.zoom_x = e
    texto.zoom_y = e

    base = Sprite.new(vp)
    base.z = 13
    base.zoom_x = e
    base.zoom_y = e
    base.opacity = 0
    base.bitmap = bmp(DIR + "EscBase.png")
    base.x = (BASE_X * e).to_i
    base.y = (BASE_Y * e).to_i

    @mudT = 0
    @mud = Sprite.new(vp)
    @mud.z = 14
    @mud.zoom_x = e
    @mud.zoom_y = e
    @mud.opacity = 0
    @mud.bitmap = bmp(DIR + "EscMudkip.png")
    @mud.x = (MUD_X * e).to_i
    @mud.y = (MUD_Y * e).to_i
    @mud.src_rect = Rect.new(0, 0, MUD_FW, MUD_FH)
    mudActual = false

    hoja = Sprite.new(vp)
    hoja.z = 23
    hoja.zoom_x = e
    hoja.zoom_y = e
    hoja.opacity = 0
    hoja.bitmap = bmp(DIR + "EscHoja.png")
    hoja.x = (HOJA_X * e).to_i
    hoja.y = (HOJA_Y * e).to_i

    negro = Sprite.new(vp)
    negro.z = 900
    negro.bitmap = Bitmap.new(gw, gh)
    negro.bitmap.fill_rect(0, 0, gw, gh, Color.new(0, 0, 0))

    begin
      # la musica entra con la imagen; el mapa la sustituye despues con autoplay
      begin
        pbBGMPlay(BGM)
      rescue
      end

      # entra desde negro
      o = 255
      while o > 0
        o -= 10
        o = 0 if o < 0
        negro.opacity = o
        tick
      end

      i = 0
      while i < BEATS.length
        ret = BEATS[i][0]
        mud = BEATS[i][1]

        # --- retrato de la derecha, con fundido si cambia ---
        if ret != retActual
          if retrato.opacity > 0
            while retrato.opacity > 0
              retrato.opacity = retrato.opacity - 24
              retrato.opacity = 0 if retrato.opacity < 0
              tick
            end
          end
          if ret
            swap(retrato, bmp(DIR + ret))
            retrato.x = 0
            retrato.y = 0
          end
          retActual = ret
        end

        # --- si Mudkip ya no toca, se va antes de cambiar de tema ---
        if !mud && mudActual
          while @mud.opacity > 0
            @mud.opacity = @mud.opacity - 18
            @mud.opacity = 0 if @mud.opacity < 0
            base.opacity = @mud.opacity
            tick
          end
          mudActual = false
        end

        # --- texto de este momento ---
        nb = bmp(sprintf("%sEscTxt%02d.png", DIR, i))
        swap(texto, nb)
        texto.x = (TXT_X * e).to_i
        texto.y = (TXT_Y * e).to_i
        ancho = nb ? nb.width : TXT_W
        alto  = nb ? nb.height : 1
        texto.src_rect = Rect.new(0, 0, 0, alto)

        # el cuadro entra la primera vez
        if caja.opacity < 255
          while caja.opacity < 255
            caja.opacity = caja.opacity + 24
            caja.opacity = 255 if caja.opacity > 255
            nombre.opacity = caja.opacity
            tick
          end
        end
        # y el retrato aparece ahora, ya con el cuadro puesto
        if ret && retrato.opacity < 255
          while retrato.opacity < 255
            retrato.opacity = retrato.opacity + 20
            retrato.opacity = 255 if retrato.opacity > 255
            tick
          end
        end

        # --- Mudkip entra con su plataforma, dejandose caer un poco ---
        if mud && !mudActual
          a = 0
          @mud.opacity = 1
          while a < 255
            a += 15
            a = 255 if a > 255
            @mud.opacity = a
            base.opacity = a
            @mud.y = ((MUD_Y - 18 + 18 * a / 255) * e).to_i
            tick
          end
          @mud.y = (MUD_Y * e).to_i
          mudActual = true
        end

        # --- se escribe de izquierda a derecha, con la hoja quieta ---
        hoja.opacity = 0
        hoja.x = (HOJA_X * e).to_i
        hoja.y = (HOJA_Y * e).to_i
        w = 0.0
        while w < ancho
          w += ESCRIBE
          w = ancho if w > ancho
          texto.src_rect = Rect.new(0, 0, w.to_i, alto)
          tick
          if Input.trigger?(Input::C)      # al pulsar, se completa de golpe
            w = ancho
            texto.src_rect = Rect.new(0, 0, ancho, alto)
            break
          end
        end
        texto.src_rect = Rect.new(0, 0, ancho, alto)

        # --- esperar a que pase de linea ---
        # Mientras espera, la hoja de la esquina se balancea despacio, como si
        # la moviera el aire: es lo que invita a pulsar.
        t = 0
        loop do
          t += 1
          sube = Math.sin(t * 0.085)
          vaiven = Math.sin(t * 0.047)
          hoja.x = ((HOJA_X + vaiven * 2.5) * e).to_i
          hoja.y = ((HOJA_Y - 1.0 - sube * 4.5) * e).to_i
          ent = t * 16
          ent = 255 if ent > 255
          hoja.opacity = (ent * (0.86 + 0.14 * (sube + 1.0) * 0.5)).to_i
          tick
          break if Input.trigger?(Input::C)
        end

        i += 1
      end

      # sale a negro, y la musica se va con ella
      begin
        pbBGMFade(0.8)
      rescue
      end
      o = 0
      while o < 255
        o += 6
        o = 255 if o > 255
        negro.opacity = o
        tick
      end
    ensure
      soltar(texto); soltar(nombre); soltar(caja); soltar(hoja)
      soltar(retrato); soltar(fondo); soltar(negro)
      soltar(base); soltar(@mud)
      @mud = nil
      begin; vp.dispose; rescue; end
    end
  end
end
