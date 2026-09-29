#===============================================================================
# Pokemon Ostinato - El prologo: la billeta de dialogo y las escenas del pueblo
#
#   Viene del script Ostinato_Despertar de Essentials BES. Cambios para la v21:
#   - Las constantes de PBMoveRoute van en mayusculas (DOWN, TURN_UP...).
#   - Para que se vea un personaje creado en marcha se le pone su sprite a mano
#     (OstMapa.sprites): el createSingleSpriteset de la v21 espera el indice
#     de $map_factory.maps, no el numero de mapa.
#   - move_route_forcing ya no tiene escritura publica.
#   - Events.onMapSceneChange es EventHandlers(:on_map_or_spriteset_change).
#
#   Ojo: el juego va a 682x384 y el arte de estas escenas esta a 1920x1080. En
#   BES el Sprite_Resizer subia el bufer a 1918x1080 y se veia 1:1; en la v21 no
#   hay resizer, asi que los cuadros se encogen al bufer y el escalado de la
#   ventana los vuelve a agrandar. Se ven en su sitio, algo mas blandos.
#===============================================================================
module OstMapa
  # Da sprite a los eventos que se han metido en $game_map.events despues de
  # montar el mapa, y quita los de los eventos que ya no estan.
  def self.sprites
    return if !$scene.is_a?(Scene_Map) || !$game_map
    ss = $scene.spriteset($game_map.map_id)
    return if !ss
    lista = ss.instance_variable_get(:@character_sprites)
    return if !lista
    vivos = $game_map.events.values
    lista.delete_if do |sp|
      ch = sp.character
      next false if !ch.is_a?(Game_Event) || vivos.include?(ch)
      sp.dispose
      true
    end
    con_sprite = lista.map { |sp| sp.character }
    $game_map.events.keys.sort.each do |k|
      ev = $game_map.events[k]
      next if con_sprite.include?(ev)
      lista.push(Sprite_Character.new(Spriteset_Map.viewport, ev))
    end
  end
end

#===============================================================================
# LA BILLETA DE DIALOGO
#
#   LA BILLETA es el cuadro de pergamino con marco de rama que dibujo el
#   usuario. Regla fija de puesta en escena, y vale para todo el juego:
#   KAIA sale SIEMPRE a la DERECHA y los demas personajes a la IZQUIERDA. El
#   rabito del cuadro apunta a quien habla, y por eso hay dos versiones del
#   mismo dibujo: DlgCuadroR.png es el espejo horizontal de DlgCuadroL.png.
#
#   El texto va como imagen, igual que en la escena del laboratorio: se genera
#   fuera con Cambria y aqui solo se muestra, revelandolo de izquierda a derecha
#   moviendo src_rect (que el Sprite_Resizer NO redefine, asi que va en pixeles
#   del bitmap).
#
#   Todas las medidas de este archivo estan en el lienzo de 1920x1080 en el que
#   estan dibujadas las piezas, y se pasan a medidas nominales multiplicando por
#   Graphics.width/1920. El resizer las vuelve a multiplicar por el factor del
#   bufer, asi que en pantalla queda 1:1.
#
#   El hueco util del pergamino se midio sobre el propio dibujo, fila a fila:
#   son 704x145 a partir de 139,38 dentro del cuadro. Importa porque las flores
#   de la esquina se meten dentro del pergamino, y al espejar el cuadro caen al
#   otro lado; por eso cada version tiene su propia x de texto.
#===============================================================================
module OstDlg
  DIR   = "Graphics/Titles/"
  ART_W = 1920.0

  # La hojita de "pulsa para seguir" es LA QUE VIENE DIBUJADA en el pergamino,
  # abajo a la derecha. Se ha recortado del cuadro a su propio PNG y el hueco
  # se ha tapado con pergamino limpio, para que no se vea la hoja dos veces:
  # la quieta del dibujo y la que se mueve. Al voltear el cuadro, la hoja se
  # voltea con el (DlgHojaR.png) y cambia de esquina.
  #
  # La hoja va SIEMPRE abajo a la derecha, tambien con el cuadro volteado: en
  # esa version el pergamino acaba antes (el marco ancho pasa a ese lado), asi
  # que su x no es la misma. Las dos estan medidas dejando los mismos 6 px de
  # margen con el borde del pergamino que tenia la hoja en el dibujo original.
  #
  # lado => [cuadro, x, y, texto_x, texto_y, hoja, hoja_x, hoja_y]
  # "cap" es el mismo cuadro sin el rabito, para las acotaciones: un ruido no
  # lo dice nadie, asi que el pico no puede estar apuntando a un personaje.
  # Como en la escena del laboratorio: dentro del pergamino va primero el
  # NOMBRE de quien habla y debajo lo que dice, los dos alineados por la
  # izquierda dentro del recuadro, como en el cuadro del laboratorio.
  CAJAS = {
    "izq" => ["DlgCuadroL.png", 402, 623, 541, 697, "DlgHoja.png", 1228, 779],
    "der" => ["DlgCuadroR.png", 585, 623, 675, 697, "DlgHoja.png", 1340, 779],
    "cap" => ["DlgCuadroN.png", 402, 623, 541, 697, "DlgHoja.png", 1228, 779],
    # Un segundo hueco por la izquierda, para las escenas de tres: el cuadro
    # es el mismo, lo que cambia es el retrato y la placa del nombre.
    "izq2" => ["DlgCuadroL.png", 402, 623, 541, 697, "DlgHoja.png", 1228, 779]
  }
  # El nombre, respecto a donde empieza el texto. Medido sobre el papel del
  # recuadro, que va de y=651 a y=813 en pantalla: el nombre entra a 24 px del
  # borde de arriba y deja 20 px de aire hasta la primera linea de texto. Con
  # el texto pegado arriba, una frase de una linea y otra de dos empiezan a la
  # misma altura y el hueco es siempre el mismo.
  NOM_DY = -31
  ESCRIBE = 20.0            # pixeles de texto que avanzan por fotograma
  VENTANA = 96.0            # ancho del tramo donde las letras estan naciendo
  TIRA    = 6               # grosor de cada tira de texto

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

  def self.tick
    Graphics.update
    Input.update
    # El mapa sigue vivo por debajo de la escena: asi los personajes pueden
    # andar mientras se habla. No hay riesgo de que el jugador se mueva solo,
    # porque miniupdate levanta $game_temp.in_mini_update mientras corre y
    # Game_Player#update no acepta mandos con esa bandera puesta.
    begin
      pbUpdateSceneMap
    rescue
    end
  end

  def self.esperar(segundos)
    t0 = Time.now
    while (Time.now - t0) < segundos
      tick
    end
  end

  # guion: lista de pasos
  #   ["DespTxt00", "der"]  una caja de texto, con el rabito a ese lado
  #   ["pausa", 3.0]        un silencio; no hay que pulsar nada
  # artes: {"izq" => [png, x, y], "der" => [png, x, y]}
  # ajustes: {"izq" => -38}, cuanto se sube o se baja el cuadro de ese lado.
  # Hace falta porque el rabito tiene que apuntar a la BOCA, y cada retrato la
  # tiene a una altura: el de Blanca en la cocina la tiene 38 pixeles por
  # encima de donde cae el rabito con la posicion de siempre.
  def self.run(guion, artes, ajustes = nil)
    e  = gw.to_f / ART_W
    vp = Viewport.new(0, 0, gw, gh)
    vp.z = 99999

    arte = {}
    artes.each_pair do |lado, datos|
      sp = Sprite.new(vp)
      sp.z = 10
      sp.bitmap = bmp(DIR + datos[0])
      sp.zoom_x = e
      sp.zoom_y = e
      sp.x = (datos[1] * e).to_i
      sp.y = (datos[2] * e).to_i
      sp.opacity = 0
      arte[lado] = sp
    end

    caja = Sprite.new(vp)
    caja.z = 20
    caja.zoom_x = e
    caja.zoom_y = e
    caja.opacity = 0

    texto = Sprite.new(vp)
    texto.z = 22
    texto.zoom_x = e
    texto.zoom_y = e

    hoja = Sprite.new(vp)
    hoja.z = 23
    hoja.zoom_x = e
    hoja.zoom_y = e
    hoja.opacity = 0

    # el nombre de quien habla, dentro del pergamino y encima de su frase
    nombre = Sprite.new(vp)
    nombre.z = 22
    nombre.zoom_x = e
    nombre.zoom_y = e
    nombre.opacity = 0

    ladoActual = nil
    datosActual = nil
    fuente = nil          # el PNG del renglon que se esta escribiendo
    begin
      guion.each do |paso|
        if paso[0] == "pausa"
          esperar(paso[1])
          next
        end
        if paso[0] == "se"
          # paso[2] es el volumen, opcional: sirve para que un sonido que viene
          # de otra habitacion suene como lo que es, de lejos
          begin
            pbSEPlay(paso[1], paso[2])
          rescue
          end
          next
        end
        if paso[0] == "haz"
          # Un trozo de escena sin hablar: alguien anda, se sienta, lo que sea.
          # Se quitan las cajas y los retratos mientras pasa, porque lo que hay
          # que mirar esta en el mapa; vuelven solos con la siguiente frase.
          o = 255
          while o > 0
            o -= 20
            o = 0 if o < 0
            caja.opacity = o
            texto.opacity = o
            hoja.opacity = o
            nombre.opacity = o
            arte.each_value { |s| s.opacity = o if s.opacity > o }
            tick
          end
          hoja.opacity = 0
          ladoActual = nil
          datosActual = nil
          paso[1].call if paso[1]
          next
        end
        if paso[0] == "tv"
          # Una frase que sale de la television. No la dice nadie que este en
          # la habitacion, asi que no puede ir en el pergamino: va en la misma
          # banda oscura del telediario, a lo ancho de la pantalla. La imagen
          # ya trae el texto escrito y ocupa el lienzo entero.
          #   ["tv", "CociTele00", 3.4]
          o = 255
          while o > 0
            o -= 20
            o = 0 if o < 0
            caja.opacity = o
            texto.opacity = o
            hoja.opacity = o
            nombre.opacity = o
            arte.each_value { |s| s.opacity = o if s.opacity > o }
            tick
          end
          hoja.opacity = 0
          ladoActual = nil
          datosActual = nil

          banda = Sprite.new(vp)
          banda.z = 12
          banda.bitmap = bmp(DIR + paso[1] + ".png")
          banda.zoom_x = e
          banda.zoom_y = e
          banda.opacity = 0
          begin
            while banda.opacity < 255
              banda.opacity = banda.opacity + 24
              banda.opacity = 255 if banda.opacity > 255
              tick
            end
            segundos = paso[2] ? paso[2] : 3.0
            t0 = Time.now
            armado = false
            while (Time.now - t0) < segundos
              tick
              armado = true if !Input.press?(Input::C)
              break if armado && Input.trigger?(Input::C)
            end
            while banda.opacity > 0
              banda.opacity = banda.opacity - 24
              banda.opacity = 0 if banda.opacity < 0
              tick
            end
          ensure
            soltar(banda)
          end
          next
        end

        lado  = paso[1]
        datos = CAJAS[lado]
        next if !datos
        # Si el paso trae un tercer dato, son segundos: es una ACOTACION (un
        # ruido, por ejemplo). Se escribe igual pero se va sola, sin hoja y sin
        # sacar a nadie, para que el jugador vea que el juego sigue vivo
        # mientras suena algo.
        espera = paso[2]

        # cuanto hay que subir o bajar el cuadro para que el rabito apunte a
        # la boca de quien habla en esta escena
        subida = 0
        subida = ajustes[lado] if ajustes && ajustes[lado]

        # El cuadro se pone del lado de quien habla, y la hoja con el. Se
        # compara el CONTENIDO y no el nombre del lado: en las escenas de tres
        # hay dos huecos por la izquierda con el mismo cuadro, y asi no se
        # recarga el dibujo cada vez que cambia el que habla.
        if datos != datosActual
          swap(caja, bmp(DIR + datos[0]))
          caja.x = (datos[1] * e).to_i
          caja.y = ((datos[2] + subida) * e).to_i
          swap(hoja, bmp(DIR + datos[5]))
          datosActual = datos
        end
        ladoActual = lado

        # El nombre sale del lado: a la derecha siempre esta Kaia y a la
        # izquierda quien sea en esa escena. Las acotaciones no llevan nombre,
        # porque no las dice nadie.
        quienEs = (artes[lado] && artes[lado][3]) ? artes[lado][3] : nil
        if quienEs
          swap(nombre, bmp(DIR + quienEs + ".png"))
          nombre.x = (datos[3] * e).to_i
          nombre.y = ((datos[4] + subida + NOM_DY) * e).to_i
          nombre.opacity = caja.opacity
        else
          nombre.opacity = 0
        end

        # El texto se pinta sobre un lienzo propio, tira a tira, en vez de
        # recortar el PNG entero con src_rect: asi cada trozo puede nacer un
        # poco mas abajo y aclarandose.
        fuente.dispose if fuente && !fuente.disposed?
        fuente = bmp(DIR + paso[0] + ".png")
        ancho = fuente ? fuente.width : 0
        alto  = fuente ? fuente.height : 1
        lienzo = Bitmap.new(ancho > 0 ? ancho : 1, alto)
        swap(texto, lienzo)
        texto.opacity = 255
        texto.x = (datos[3] * e).to_i
        texto.y = ((datos[4] + subida) * e).to_i

        # La primera vez, el cuadro entra con un fundido. El texto y el nombre
        # tienen que entrar CON el: si se dejan a 255, se ven flotando sobre el
        # mapa mientras el pergamino todavia no esta, y eso es lo que se veia
        # roto al volver del telediario.
        if caja.opacity < 255
          texto.opacity = caja.opacity
          nombre.opacity = caja.opacity
          while caja.opacity < 255
            caja.opacity = caja.opacity + 24
            caja.opacity = 255 if caja.opacity > 255
            texto.opacity = caja.opacity
            nombre.opacity = caja.opacity
            tick
          end
        end

        # En las escenas de tres hay dos retratos del mismo lado (la profesora
        # y Lira). El que entra echa al que estaba, cruzandose en un fundido
        # corto: si no, se quedarian los dos encima uno del otro.
        quien = espera ? nil : arte[lado]
        if quien
          arte.each_value do |otro|
            next if otro == quien || otro.opacity == 0
            next if (otro.x < gw / 2) != (quien.x < gw / 2)
            while otro.opacity > 0
              otro.opacity = otro.opacity - 20
              otro.opacity = 0 if otro.opacity < 0
              if quien.opacity < 255
                quien.opacity = quien.opacity + 20
                quien.opacity = 255 if quien.opacity > 255
              end
              tick
            end
          end
        end

        # y quien habla aparece la primera vez que le toca
        quien = espera ? nil : arte[lado]
        if quien && quien.opacity < 255
          while quien.opacity < 255
            quien.opacity = quien.opacity + 20
            quien.opacity = 255 if quien.opacity > 255
            tick
          end
        end

        # se escribe de izquierda a derecha; al pulsar, se completa de golpe
        hx = datos[6]
        hy = datos[7] + subida
        hoja.opacity = 0
        hoja.x = (hx * e).to_i
        hoja.y = (hy * e).to_i
        # Una cabeza recorre el renglon. Cada tira empieza a existir cuando la
        # cabeza pasa por ella y tarda toda la VENTANA en asentarse: nace seis
        # pixeles mas abajo y transparente, y sube hasta su sitio. El borde del
        # texto queda vivo en lugar de ser un corte recto.
        cabeza = 0.0
        while cabeza < ancho + VENTANA
          cabeza += ESCRIBE
          x0 = (cabeza - VENTANA).to_i
          x0 = 0 if x0 < 0
          x1 = cabeza.to_i
          x1 = ancho if x1 > ancho
          if x1 > x0
            lienzo.fill_rect(x0, 0, x1 - x0, alto, Color.new(0, 0, 0, 0))
            i = x0 - (x0 % TIRA)
            i = 0 if i < 0
            while i < x1
              crece = (cabeza - i) / VENTANA
              crece = 1.0 if crece > 1.0
              if crece > 0.0
                anchoTira = TIRA
                anchoTira = ancho - i if i + anchoTira > ancho
                if anchoTira > 0
                  op = (255 * crece).to_i
                  op = 255 if op > 255
                  dy = ((1.0 - crece) * 6.0).to_i
                  lienzo.blt(i, dy, fuente, Rect.new(i, 0, anchoTira, alto), op)
                end
              end
              i += TIRA
            end
          end
          tick
          break if Input.trigger?(Input::C)
        end
        # al pulsar, o al acabar, el renglon queda entero y en su sitio
        lienzo.clear
        lienzo.blt(0, 0, fuente, Rect.new(0, 0, ancho, alto), 255) if ancho > 0

        # una acotacion no espera a nadie: se queda lo suyo y se va
        if espera
          t0 = Time.now
          while (Time.now - t0) < espera
            tick
            break if Input.trigger?(Input::C)
          end
          next
        end

        # a esperar. Mientras tanto la hoja se balancea, que es lo que invita
        # a pulsar sin tener que poner un cartel.
        t = 0
        loop do
          t += 1
          sube   = Math.sin(t * 0.085)
          vaiven = Math.sin(t * 0.047)
          hoja.x = ((hx + vaiven * 2.5) * e).to_i
          hoja.y = ((hy - 1.0 - sube * 4.5) * e).to_i
          ent = t * 16
          ent = 255 if ent > 255
          hoja.opacity = (ent * (0.86 + 0.14 * (sube + 1.0) * 0.5)).to_i
          tick
          break if Input.trigger?(Input::C)
        end
      end

      # se va todo junto y el mapa se queda limpio
      o = 255
      while o > 0
        o -= 16
        o = 0 if o < 0
        caja.opacity  = o
        texto.opacity = o
        hoja.opacity  = o
        arte.each_value { |s| s.opacity = o }
        tick
      end
    ensure
      fuente.dispose if fuente && !fuente.disposed?
      soltar(texto); soltar(caja); soltar(hoja); soltar(nombre)
      arte.each_value { |s| soltar(s) }
      begin; vp.dispose; rescue; end
    end
  end
end

#===============================================================================
# ESCENA 1 - EL DESPERTAR
#
#   Kaia abre los ojos en su cuarto. Su madre la llama desde abajo; como no se
#   la ve, sale en silueta negra al lado izquierdo: es una voz, no una persona
#   en la habitacion.
#
#   Se dispara sola la primera vez que se pisa el cuarto (mapa 43) y se apunta
#   en el interruptor 101 para no repetirse. Se engancha a Scene_Map#update, que
#   es lo unico que corre SEGURO con el mapa ya en pantalla: onMapSceneChange
#   salta antes del Graphics.transition y ahi la pantalla todavia esta congelada.
#===============================================================================
module OstinatoDespertar
  MAPA      = 43
  SWITCH    = 101    # "la escena del despertar ya se ha visto"
  NEGRO_SEG = 0.6    # respiro entre la cartela y el cuarto

  # Cartela de sitio y hora sobre negro, antes de ver nada. Abajo a la derecha
  # late una flecha: con Enter se salta y se entra ya en el cuarto.
  CARTELA     = "DespCartela.png"
  CARTELA_SEG = 4.5
  FLECHA      = "DespFlecha.png"
  FLECHA_X    = 1780
  FLECHA_Y    = 968

  # Su madre fregando los platos, desde el piso de abajo.
  RUIDO = "Ostinato fregando"

  GUION = [
    ["DespTxt00", "der"],   # Aissh...
    ["DespTxt01", "der"],   # Ya es de dia del todo.
    ["se", RUIDO, 70],          #     (abajo su madre esta fregando)
    ["DespCap00", "cap", 2.7],  #     (Ruidos de alguien fregando, abajo.)
    ["DespTxt02", "der"],   # Me levanto y lo primero que escucho es el ruido de alguien fregando.
    ["DespTxt03", "izq"],   # Kaia?
    ["DespTxt04", "izq"],   # Estas ahi?
    ["DespTxt05", "izq"],   # He escuchado el crujido de la cama. Seguro que estas despierta.
    ["DespTxt06", "der"],   # Llevo despierta un rato.
    ["DespTxt07", "izq"],   # Pues baja a desayunar, anda.
    ["DespTxt08", "izq"],   # Que te estan esperando desde hace ya tiempo.
    ["DespTxt09", "der"],   # Quien?
    ["DespTxt10", "izq"],   # Lira. Lleva abajo desde las nueve preguntando por ti.
    ["DespTxt11", "izq"]    # Ha dicho que si no bajas, sube ella y te saca a base de ostias.
  ]

  ARTES = {
    # en el despertar todavia no se le ve la cara, asi que no tiene nombre: ??
    "izq" => ["DlgMadre.png", 196, 465, "DlgNomInterrogante"],
    "der" => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }

  # Si falta el material, la escena se salta en silencio y el juego sigue.
  def self.disponible?
    b = OstDlg.bmp(OstDlg::DIR + "DespTxt00.png")
    return false if !b
    b.dispose
    return true
  end

  # El telon negro se pone ANTES de que el mapa aparezca. Si se pusiera al
  # empezar la escena, el Graphics.transition de Scene_Map ya habria pintado
  # el cuarto y se veria un parpadeo: aparece la habitacion, se apaga, y vuelve.
  # Por eso esto se engancha a onMapSceneChange, que salta con la pantalla aun
  # congelada, y la escena de despues se limita a heredar el telon.
  def self.telon
    return if @negro
    return if !$game_map || $game_map.map_id != MAPA
    return if !$game_switches || $game_switches[SWITCH]
    return if !disponible?
    @vpNegro = Viewport.new(0, 0, OstDlg.gw, OstDlg.gh)
    @vpNegro.z = 99998
    @negro = Sprite.new(@vpNegro)
    @negro.z = 5
    @negro.bitmap = Bitmap.new(OstDlg.gw, OstDlg.gh)
    @negro.bitmap.fill_rect(0, 0, OstDlg.gw, OstDlg.gh, Color.new(0, 0, 0))
  end

  def self.quitar_telon
    OstDlg.soltar(@negro) if @negro
    @negro = nil
    if @vpNegro
      begin; @vpNegro.dispose; rescue; end
      @vpNegro = nil
    end
  end

  # La cartela: el sitio y la hora en blanco sobre el negro, con la flecha
  # latiendo abajo a la derecha. Se va sola a los CARTELA_SEG o en cuanto se
  # pulsa Enter.
  def self.cartela
    return if !@negro
    vp = Viewport.new(0, 0, OstDlg.gw, OstDlg.gh)
    vp.z = 99998
    e = OstDlg.gw.to_f / OstDlg::ART_W

    letras = Sprite.new(vp)
    letras.z = 10
    letras.bitmap = OstDlg.bmp(OstDlg::DIR + CARTELA)
    letras.zoom_x = e
    letras.zoom_y = e
    letras.opacity = 0

    flecha = Sprite.new(vp)
    flecha.z = 11
    flecha.bitmap = OstDlg.bmp(OstDlg::DIR + FLECHA)
    flecha.zoom_x = e
    flecha.zoom_y = e
    flecha.opacity = 0

    begin
      return if !letras.bitmap

      o = 0
      while o < 255
        o += 12
        o = 255 if o > 255
        letras.opacity = o
        OstDlg.tick
      end

      t = 0
      t0 = Time.now
      armado = false
      loop do
        t += 1
        vaiven = Math.sin(t * 0.11)
        flecha.x = ((FLECHA_X + vaiven * 7.0) * e).to_i
        flecha.y = (FLECHA_Y * e).to_i
        ent = t * 10
        ent = 255 if ent > 255
        flecha.opacity = (ent * (0.62 + 0.38 * (vaiven + 1.0) * 0.5)).to_i
        OstDlg.tick
        # se llega aqui con Enter recien pulsado, asi que hay que soltarlo antes
        armado = true if !Input.press?(Input::C)
        break if armado && Input.trigger?(Input::C)
        break if (Time.now - t0) >= CARTELA_SEG
      end

      o = 255
      while o > 0
        o -= 14
        o = 0 if o < 0
        letras.opacity = o
        flecha.opacity = o if flecha.opacity > o
        OstDlg.tick
      end
    ensure
      OstDlg.soltar(letras)
      OstDlg.soltar(flecha)
      begin; vp.dispose; rescue; end
    end
  end

  def self.run
    return if !disponible?

    telon
    cartela
    begin
      OstDlg.esperar(NEGRO_SEG) if @negro
      if @negro
        o = 255
        while o > 0
          o -= 8
          o = 0 if o < 0
          @negro.opacity = o
          OstDlg.tick
        end
      end
    ensure
      quitar_telon
    end

    OstDlg.run(GUION, ARTES)
  end

  def self.comprobar
    return if @corriendo
    # Si se ha salido del cuarto sin ver la escena (un teletransporte de
    # depuracion, por ejemplo), el telon no puede quedarse tapando otro mapa.
    quitar_telon if @negro && $game_map && $game_map.map_id != MAPA
    return if !$game_map || $game_map.map_id != MAPA
    return if !$game_switches || $game_switches[SWITCH]
    return if !$game_player || $game_player.moving?
    return if $game_temp && ($game_temp.message_window_showing ||
                             $game_temp.player_transferring)
    @corriendo = true
    begin
      # el telon primero: su guarda mira el interruptor, asi que si se marcase
      # antes, la escena se quedaria sin negro de entrada
      telon
      $game_switches[SWITCH] = true
      run
    ensure
      @corriendo = false
    end
  end
end

#===============================================================================
# ESCENA 2 - LA COCINA
#
#   Kaia baja la escalera. Su madre esta de espaldas en la encimera, se gira y
#   le dice que se siente; Kaia rodea la mesa y se sienta; entonces su madre se
#   acerca y hablan. Acaba con "vamos a ver las noticias un poco", que es lo que
#   enlaza con la escena del telediario.
#
#   Blanca NO esta puesta como evento en el mapa: se crea en marcha, igual que
#   hace Essentials con los personajes que te siguen (PField_DependentEvents
#   monta sus Game_Event con RPG::Event.new). Asi la escena no depende de que
#   el mapa traiga nada preparado. Al recargar el mapa desaparece; cuando haya
#   que dejarla ahi fija, se pone un evento normal con el charset "blanca".
#
#   Los sitios estan medidos sobre la rejilla de paso del mapa 3: la mesa ocupa
#   x 5-9 en las filas 7 y 8, y las sillas son las casillas andables de al lado.
#===============================================================================
module OstinatoCocina
  MAPA   = 3
  SWITCH = 102     # "la escena de la cocina ya se ha visto"

  MADRE_X  = 3; MADRE_Y  = 5    # junto a la encimera, de espaldas
  CERCA_X  = 7; CERCA_Y  = 9    # se acerca y se queda de pie al lado de Kaia
  SIENTA_X = 8; SIENTA_Y = 9    # y luego se sienta en la silla de al lado
  SILLA_X  = 6; SILLA_Y  = 9    # la silla de abajo a la izquierda, la de Kaia
  ID_MADRE = 901

  # El desayuno puesto: la mesa ocupa las filas 7 y 8, asi que los cacharros
  # van en la fila 8, justo delante de cada silla. Son eventos con dibujo de
  # casilla (tile_id), no personajes.
  CACHARROS = [
    [6, 7, 475],    # la taza de Kaia
    [7, 7, 2198],   # algo de comer, en medio
    [8, 7, 475]     # la taza de su madre
  ]
  ID_CACHARRO = 910
  # El vaporcito de las tazas: un charset de cuatro fotogramas que se mueve
  # solo (step_anime). Va en la misma casilla que la taza y, como el dibujo se
  # ancla por abajo y la casilla es de 32x48, el humo cae justo encima.
  VAPORES  = [[6, 7], [8, 7]]
  ID_VAPOR = 920

  ARTES = {
    "izq" => ["DlgBlanca.png", 174, 465, "DlgNomBlanca"],
    "der" => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }

  # El rabito del cuadro tiene que apuntar a la boca. Medido sobre el montaje:
  # la boca de Blanca cae en y=710 y el rabito, con el cuadro en su sitio de
  # siempre, en y=746..750. Se sube el cuadro 38 pixeles y coinciden.
  AJUSTES = { "izq" => -38 }

  def self.guion
    [
      ["CociTxt00", "izq"],   # Ya era hora, muchacha.
      ["CociTxt01", "izq"],   # Sientate, anda. Te he guardado lo tuyo.
      ["haz", proc { sentarse }],      # Kaia rodea la mesa y se sienta
      ["CociTxt02", "der"],   # Gracias, mama.
      ["haz", proc { acercarse }],     # su madre se acerca
      ["CociTxt03", "izq"],   # Esta recien hecho. Cometelo caliente, que asi esta mas rico.
      ["haz", proc { sentarse_madre }],# y se sienta con ella
      ["CociTxt04", "izq"],   # Tienes ganas de ir al laboratorio?
      ["CociTxt05", "der"],   # Si.
      ["CociTxt06", "der"],   # Y un poco de miedo.
      ["CociTxt07", "izq"],   # Normal. Todavia me acuerdo yo de aquella epoca.
      ["CociTxt08", "izq"],   # Que tiempos mas bonitos pase junto a mis companeros.
      ["CociTxt09", "izq"],   # Pero bueno, come, anda, que te estan esperando.
      ["CociTxt10", "izq"],   # Y vamos a ver las noticias un poco.
      ["CociTxt11", "izq"],   # Que ultimamente pasan muchas cosas y no me entero de nada.
      ["CociTxt12", "der"],   # Pues enciendo la tele y nos enteramos de algo.
      # La voz sale de la tele, no de nadie de la cocina: va en el cuadro sin
      # rabito y se quita sola, sin que el jugador tenga que pulsar.
      ["tv", "CociTele00", 3.6],       # ...y con esto cerramos la jornada de liga.
      ["haz", proc { OstinatoTele.run }],
      ["CociTxt13", "der"],   # Que es lo que acabamos de ver? Como que dejo de hablar?
      ["CociTxt14", "der"],   # Mama, tu tienes idea de que ha pasado?
      ["CociTxt15", "izq"],   # Ni idea, hija.
      ["CociTxt16", "izq"],   # Pero he escuchado que cada vez mas personas acaban en estado vegetal.
      ["CociTxt17", "der"],   # Ostras, que extrano.
      ["CociTxt18", "izq"],   # Son cosas que le pasan a gente mayor, supongo.
      ["CociTxt19", "der"],   # Mama, tenia treinta y cuatro anos, si consideras eso mayor.
      ["pausa", 3.0],                  # el silencio incomodo, y que se note
      ["CociTxt20", "izq"]    # Bueno, anda, come, que te estan esperando.
    ]
  end

  def self.disponible?
    b = OstDlg.bmp(OstDlg::DIR + "CociTxt00.png")
    return false if !b
    b.dispose
    return true
  end

  def self.madre
    return nil if !$game_map || !$game_map.events
    return $game_map.events[ID_MADRE]
  end

  def self.crear_madre
    return if madre
    ev = RPG::Event.new(MADRE_X, MADRE_Y)
    ev.id = ID_MADRE
    ev.name = "Blanca"
    g = Game_Event.new($game_map.map_id, ev, $game_map)
    g.character_name = "blanca"
    g.turn_up
    $game_map.events[ID_MADRE] = g
    begin
      OstMapa.sprites
    rescue
    end
  end

  # Lanza una ruta y espera a que termine, sin colgarse si algo va mal.
  def self.mover(quien, pasos)
    return if !quien
    begin
      pbMoveRoute(quien, pasos)
    rescue
      return
    end
    vueltas = 0
    quietas = 0
    ultimo = [quien.x, quien.y]
    while quien.move_route_forcing && vueltas < 1200
      vueltas += 1
      OstDlg.tick
      # si se queda clavado porque algo se le ha puesto delante, se sale
      if quien.x == ultimo[0] && quien.y == ultimo[1]
        quietas += 1
      else
        quietas = 0
        ultimo = [quien.x, quien.y]
      end
      break if quietas > 90
    end
    # sin quitar la marca de ruta forzada el jugador no vuelve a andar
    # y ademas deja de refrescarse su dibujo
    begin
      quien.instance_variable_set(:@move_route_forcing, false)
    rescue
    end
  end

  # Kaia baja por la derecha de la mesa y se sienta mirando a la mesa.
  def self.sentarse
    pasos = []
    5.times { pasos.push(PBMoveRoute::DOWN) }
    5.times { pasos.push(PBMoveRoute::LEFT) }
    pasos.push(PBMoveRoute::TURN_UP)
    mover($game_player, pasos)
    # por si el jugador no estaba donde se supone al empezar la escena
    begin
      $game_player.moveto(SILLA_X, SILLA_Y)
      $game_player.turn_up
    rescue
    end
    OstDlg.esperar(0.35)
  end

  # Su madre deja la encimera y se planta al lado de Kaia, mirandola.
  #
  # Va RODEANDO la mesa por abajo: baja hasta la fila 10, cruza por delante de
  # las sillas y sube a la casilla de al lado de Kaia. Antes iba por la fila 9
  # y le pasaba a Kaia por encima, porque su silla (6,9) esta justo en medio.
  #
  # Y anda con la cara quieta: direction_fix hace que no se gire en cada
  # esquina, que era lo que la hacia cambiar de cara mientras cruzaba.
  def self.acercarse
    m = madre
    return if !m
    # Anda mirando a donde va: si baja, de espaldas; si va a la derecha, de
    # perfil a la derecha. Nada de cara fija, que la dejaba cruzando la cocina
    # de frente y andando de lado.
    pasos = []
    5.times { pasos.push(PBMoveRoute::DOWN) }    # (3,5) -> (3,10), por debajo de las sillas
    4.times { pasos.push(PBMoveRoute::RIGHT) }   # (3,10) -> (7,10)
    pasos.push(PBMoveRoute::UP)                  # y sube al hueco de al lado de Kaia
    pasos.push(PBMoveRoute::TURN_LEFT)            # ya al lado, se vuelve hacia Kaia
    mover(m, pasos)
    begin
      m.moveto(CERCA_X, CERCA_Y)
      m.turn_left
    rescue
    end
    OstDlg.esperar(0.35)
  end

  # Y al rato se sienta en la silla de al lado.
  def self.sentarse_madre
    m = madre
    return if !m
    # el paso a la silla de al lado, mirando a donde va
    mover(m, [PBMoveRoute::RIGHT, PBMoveRoute::TURN_UP])
    begin
      m.moveto(SIENTA_X, SIENTA_Y)
      m.turn_up
    rescue
    end
    OstDlg.esperar(0.4)
  end

  # Pone el desayuno en la mesa: eventos con dibujo de casilla, sin paginas ni
  # nada, solo para que se vea algo encima de la mesa mientras hablan.
  def self.poner_mesa
    return if !$game_map || !$game_map.events
    puesto = false
    for i in 0...CACHARROS.length
      id = ID_CACHARRO + i
      next if $game_map.events[id]
      c = CACHARROS[i]
      ev = RPG::Event.new(c[0], c[1])
      ev.id = id
      ev.name = "Desayuno"
      ev.pages[0].graphic.tile_id = c[2]
      $game_map.events[id] = Game_Event.new($game_map.map_id, ev, $game_map)
      puesto = true
    end
    for i in 0...VAPORES.length
      id = ID_VAPOR + i
      next if $game_map.events[id]
      v = VAPORES[i]
      ev = RPG::Event.new(v[0], v[1])
      ev.id = id
      ev.name = "Vapor"
      ev.pages[0].graphic.character_name = "vaporcito"
      ev.pages[0].graphic.direction = 2
      ev.pages[0].step_anime = true      # se mueve aunque nadie ande
      ev.pages[0].direction_fix = true
      ev.pages[0].through = true
      ev.pages[0].always_on_top = true   # por encima de la taza
      $game_map.events[id] = Game_Event.new($game_map.map_id, ev, $game_map)
      puesto = true
    end
    if puesto
      begin
        OstMapa.sprites
      rescue
      end
    end
  end

  def self.run
    return if !disponible?
    crear_madre
    poner_mesa
    OstDlg.esperar(0.5)
    mover(madre, [PBMoveRoute::TURN_DOWN])   # se gira: primera vez que se le ve la cara
    OstDlg.esperar(0.3)
    OstDlg.run(guion, ARTES, AJUSTES)
  end

  def self.comprobar
    return if @corriendo
    return if !$game_map || $game_map.map_id != MAPA
    return if !$game_switches || $game_switches[SWITCH]
    return if !$game_player || $game_player.moving?
    return if $game_temp && ($game_temp.message_window_showing ||
                             $game_temp.player_transferring)
    @corriendo = true
    begin
      $game_switches[SWITCH] = true
      run
    ensure
      @corriendo = false
    end
  end
end

#===============================================================================
# EL TELEDIARIO
#
#   No es un video. Son treinta pantallas dibujadas, una por frase, que pasan
#   con Enter: cada una trae ya puesto su subtitulo y la foto que le toca en el
#   panel del plato, asi que aqui solo hay que ensenarlas en orden.
#
#   Estan hechas a 1364x768, la pantalla del juego, y se escalan por
#   Graphics.width igual que el resto del arte para que el resizer las deje
#   a 1:1. Se carga una cada vez y se suelta la anterior: son cuatro megas de
#   bitmap cada una y no hay ninguna razon para tener treinta a la vez.
#===============================================================================
module OstinatoTele
  ANCHO   = 1364.0
  CUANTAS = 31
  # La sintonia del telediario. No es musica de la escena: sale de la tele,
  # como el zumbido del aparato, y por eso no cambia cuando llega la noticia
  # de Ciudad Muda. El OGG lleva marcado el bucle (LOOPSTART/LOOPLENGTH), asi
  # que suena la cabecera una vez y luego repite solo la cama de fondo.
  MUSICA = "Ostinato Noticias"

  # Las treinta imagenes traen ya dibujado el cartel de EN DIRECTO, el recuadro
  # morado con su titulo y su descripcion, y lo que dice ella encima.
  #
  # Lo unico que NO viene dibujado es el punto blanco del cartel, porque
  # parpadea: va aqui como un sprite suelto, colocado en el hueco que le deja
  # la caja roja. Sus medidas son las del lienzo de 1364x768 de las imagenes.
  PUNTO      = "NoticiasPunto.png"
  PUNTO_CX   = 1108    # centro del hueco dentro de la caja roja
  PUNTO_CY   = 61
  # el ciclo del parpadeo, en fotogramas: encendido, se apaga, apagado, vuelve
  PUNTO_ON   = 40
  PUNTO_BAJA = 8
  PUNTO_OFF  = 12
  PUNTO_SUBE = 8

  # Al pasar de frase suena lo mismo que al pasar cualquier texto del juego:
  # pbPlayDecisionSE, que es lo que toca la ventana de mensajes de Essentials
  # cuando esta esperando a que pulses. Asi el telediario no suena a otra cosa.

  def self.disponible?
    b = OstDlg.bmp(OstDlg::DIR + "Noticias01.png")
    return false if !b
    b.dispose
    return true
  end

  def self.telon(vp)
    s = Sprite.new(vp)
    s.z = 20
    s.bitmap = Bitmap.new(OstDlg.gw, OstDlg.gh)
    s.bitmap.fill_rect(0, 0, OstDlg.gw, OstDlg.gh, Color.new(0, 0, 0))
    s.opacity = 0
    return s
  end

  # Un fotograma de la escena, con el punto del cartel puesto al dia. Todo lo
  # que espera dentro del telediario llama a esto y no a OstDlg.tick.
  def self.latido
    if @punto && !@punto.disposed?
      @paso = 0 if !@paso
      ciclo = PUNTO_ON + PUNTO_BAJA + PUNTO_OFF + PUNTO_SUBE
      t = @paso % ciclo
      if t < PUNTO_ON
        @punto.opacity = 255
      elsif t < PUNTO_ON + PUNTO_BAJA
        @punto.opacity = (255 * (1.0 - (t - PUNTO_ON) / PUNTO_BAJA.to_f)).to_i
      elsif t < PUNTO_ON + PUNTO_BAJA + PUNTO_OFF
        @punto.opacity = 0
      else
        n = t - (PUNTO_ON + PUNTO_BAJA + PUNTO_OFF)
        @punto.opacity = (255 * (n / PUNTO_SUBE.to_f)).to_i
      end
      @paso += 1
    end
    OstDlg.tick
  end

  def self.poner_punto(vp, e)
    b = OstDlg.bmp(OstDlg::DIR + PUNTO)
    return if !b
    @punto = Sprite.new(vp)
    @punto.z = 15                 # por encima de la imagen, por debajo del telon
    @punto.bitmap = b
    @punto.zoom_x = e
    @punto.zoom_y = e
    @punto.x = ((PUNTO_CX - b.width / 2.0) * e).to_i
    @punto.y = ((PUNTO_CY - b.height / 2.0) * e).to_i
    @paso = 0
  end

  def self.quitar_punto
    OstDlg.soltar(@punto) if @punto
    @punto = nil
  end

  def self.fundir(s, hasta, paso)
    o = s.opacity
    while (paso > 0 && o < hasta) || (paso < 0 && o > hasta)
      o += paso
      o = hasta if (paso > 0 && o > hasta) || (paso < 0 && o < hasta)
      s.opacity = o
      latido
    end
  end

  # espera a Enter, pero antes a que lo suelte: se llega aqui con la tecla
  # todavia pulsada de la frase anterior y si no, pasa dos pantallas de golpe
  def self.esperar_enter
    armado = false
    loop do
      latido
      armado = true if !Input.press?(Input::C)
      if armado && Input.trigger?(Input::C)
        begin
          pbPlayDecisionSE
        rescue
        end
        break
      end
    end
  end

  def self.run
    return if !disponible?
    vp = Viewport.new(0, 0, OstDlg.gw, OstDlg.gh)
    vp.z = 99997
    e = OstDlg.gw.to_f / ANCHO

    tele = Sprite.new(vp)
    tele.z = 10
    tele.zoom_x = e
    tele.zoom_y = e
    negro = telon(vp)
    poner_punto(vp, e)

    # la musica de la casa se guarda para devolverla al apagar la tele
    antes = nil
    begin
      antes = $game_system.playing_bgm if $game_system
    rescue
    end

    begin
      fundir(negro, 255, 16)
      begin
        pbBGMPlay(MUSICA)
      rescue
      end
      i = 1
      while i <= CUANTAS
        nb = OstDlg.bmp(OstDlg::DIR + sprintf("Noticias%02d.png", i))
        break if !nb
        OstDlg.swap(tele, nb)
        fundir(negro, 0, -16) if i == 1
        esperar_enter
        i += 1
      end
      # Su madre apaga la tele: la sintonia se va de golpe, sin desvanecer.
      # Ese silencio seco es el que hace el trabajo despues de lo de Ciudad Muda.
      begin
        pbBGMStop
      rescue
      end
      fundir(negro, 255, 16)
      OstDlg.soltar(tele)
      tele = nil
      begin
        $game_system.bgm_play(antes) if antes && antes.name && antes.name != ""
      rescue
      end
      fundir(negro, 0, -16)
    ensure
      quitar_punto
      OstDlg.soltar(tele) if tele
      OstDlg.soltar(negro)
      begin; vp.dispose; rescue; end
    end
  end
end


#===============================================================================
# ESCENA 4 - LA PUERTA DE CASA
#
#   Kaia sale a Pueblo Preludio y se encuentra a Lira, que lleva esperandola
#   desde las nueve. Hablan, y al acabar Lira no se la lleva: se va ella sola
#   al laboratorio subiendo por el camino de tierra, y Kaia se queda en la
#   puerta. A partir de ahi manda el jugador.
#
#   Lira no esta puesta en el mapa: se crea en marcha, igual que Blanca en la
#   cocina, y se borra en cuanto se va. Asi la escena no depende de que el
#   mapa traiga nada preparado.
#===============================================================================
module OstinatoPuerta
  MAPA   = 2         # Pueblo Preludio
  SWITCH = 103       # "la escena de la puerta ya se ha visto"
  ANTES  = 102       # y no salta si antes no se ha visto la cocina

  ID_LIRA = 921      # un hueco alto, para no pisar los eventos del mapa
  LIRA_X  = 33       # dos casillas por debajo de la puerta: asi Kaia puede
  LIRA_Y  = 22       # salir del portal y se quedan de cara, sin pisarse
  PUERTA_Y = 20      # la casilla de la puerta, donde aparece Kaia al salir
  CHARSET = "sora"
  DEPRISA = 5        # velocidad al irse; la de andar normal es 4

  ARTES = {
    "izq" => ["DlgLira.png", 174, 465, "DlgNomLira"],
    "der" => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }

  # El camino hasta la puerta del laboratorio, en (25,7), en pares de
  # [cuantos pasos, hacia donde]. Sacado de la rejilla de paso del mapa:
  # cruza por delante de casa esquivando el buzon de (30,21) y sube pegada al
  # camino de tierra. No atraviesa nada.
  CAMINO = [
    [4, PBMoveRoute::LEFT], [1, PBMoveRoute::UP],   [3, PBMoveRoute::LEFT],
    [13, PBMoveRoute::UP],  [1, PBMoveRoute::LEFT], [1, PBMoveRoute::UP]
  ]

  def self.guion
    [
      ["PuerTxt00", "izq"],   # Vaya, te has dormido, como siempre...
      ["PuerTxt01", "der"],   # Buenos dias.
      ["PuerTxt02", "izq"],   # Llevo aqui desde las nueve.
      ["PuerTxt03", "der"],   # Ya. Me lo ha dicho mi madre.
      ["PuerTxt04", "izq"],   # Te lo ha dicho y has tardado otros veinte minutos.
      ["PuerTxt05", "der"],   # Estaba desayunando.
      ["PuerTxt06", "izq"],   # Y viendo las noticias.
      ["PuerTxt07", "der"],   # ...
      ["PuerTxt08", "izq"],   # Se te oia la tele desde el portal.
      ["PuerTxt09", "izq"],   # Lo del hombre ese que dejo de hablar, no?
      ["PuerTxt10", "der"],   # Si.
      ["PuerTxt11", "izq"],   # Mi padre dice que es cosa del agua.
      ["PuerTxt12", "izq"],   # Que ultimamente esta muy sucia y la gente se la bebe.
      ["PuerTxt13", "izq"],   # Aunque mi padre dice muchas cosas.
      ["PuerTxt14", "izq"],   # Que despues no son.
      ["PuerTxt15", "der"],   # Ya.
      ["PuerTxt16", "izq"],   # Bueno. Da igual. Ya estas aqui.
      ["PuerTxt17", "izq"],   # Sabes que dia es hoy?
      ["PuerTxt18", "der"],   # Jueves.
      ["PuerTxt19", "izq"],   # Es nuestro dia, Kaia.
      ["PuerTxt20", "izq"],   # Hoy conoceremos a nuestro companero de aventura.
      ["PuerTxt21", "der"],   # Lo se.
      ["PuerTxt22", "izq"],   # Pues no lo parece.
      ["PuerTxt23", "der"],   # Es que no me lo creo todavia.
      ["PuerTxt24", "izq"],   # Pues te lo vas creyendo por el camino.
      ["PuerTxt25", "izq"],   # Venga, que nos estan esperando.
      ["PuerTxt26", "der"],   # Por donde era?
      ["PuerTxt27", "izq"],   # Al norte del pueblo. Por si no te acordabas.
      ["PuerTxt28", "izq"],   # Todo recto, no tiene perdida.
      ["PuerTxt29", "der"],   # Me acordaba.
      ["PuerTxt30", "izq"]    # Claro.
    ]
  end

  def self.disponible?
    b = OstDlg.bmp(OstDlg::DIR + "PuerTxt00.png")
    return false if !b
    b.dispose
    return true
  end

  def self.lira
    return nil if !$game_map || !$game_map.events
    return $game_map.events[ID_LIRA]
  end

  def self.crear_lira
    return if lira
    ev = RPG::Event.new(LIRA_X, LIRA_Y)
    ev.id = ID_LIRA
    ev.name = "Lira"
    g = Game_Event.new($game_map.map_id, ev, $game_map)
    g.character_name = CHARSET
    g.turn_up
    $game_map.events[ID_LIRA] = g
    begin
      OstMapa.sprites
    rescue
    end
  end

  def self.quitar_lira
    return if !lira
    $game_map.events.delete(ID_LIRA)
    begin
      OstMapa.sprites
    rescue
    end
  end

  # Lanza una ruta y espera a que termine, sin colgarse si algo va mal.
  def self.mover(quien, pasos)
    return if !quien
    begin
      pbMoveRoute(quien, pasos)
    rescue
      return
    end
    vueltas = 0
    quietas = 0
    ultimo = [quien.x, quien.y]
    while quien.move_route_forcing && vueltas < 1200
      vueltas += 1
      OstDlg.tick
      # si se queda clavado porque algo se le ha puesto delante, se sale
      if quien.x == ultimo[0] && quien.y == ultimo[1]
        quietas += 1
      else
        quietas = 0
        ultimo = [quien.x, quien.y]
      end
      break if quietas > 90
    end
    # sin quitar la marca de ruta forzada el jugador no vuelve a andar
    # y ademas deja de refrescarse su dibujo
    begin
      quien.instance_variable_set(:@move_route_forcing, false)
    rescue
    end
  end

  def self.irse
    pasos = []
    CAMINO.each { |tramo| tramo[0].times { pasos.push(tramo[1]) } }
    begin
      lira.move_speed = DEPRISA
    rescue
    end
    mover(lira, pasos)
    OstDlg.esperar(0.25)
    quitar_lira
  end

  # Antes de nada, dejar a Kaia a la vista. Si la escena anterior la dejo
  # transparente o sin dibujo (pasa si se entra al mapa sin haber hecho el
  # arranque), no se veria nada y pareceria que Lira habla con una pared.
  def self.ver_a_kaia
    return if !$game_player
    begin
      $game_player.transparent = false
      $game_player.opacity = 255
    rescue
    end
    begin
      $game_player.refresh_charset if $game_player.character_name.to_s == ""
    rescue
    end
  end

  # Kaia sale del portal: da un paso hacia abajo para quedar fuera de la
  # puerta, donde se la ve entera, y se queda de cara a Lira. Si el paso no
  # sale (algo en medio), se la planta a la fuerza en su sitio.
  def self.salir_de_casa
    return if !$game_player
    ver_a_kaia
    begin
      if $game_player.x == LIRA_X && $game_player.y == PUERTA_Y
        mover($game_player, [PBMoveRoute::DOWN])
        $game_player.moveto(LIRA_X, PUERTA_Y + 1) if $game_player.y == PUERTA_Y
      end
      $game_player.turn_down
    rescue
    end
  end

  def self.run
    crear_lira
    salir_de_casa
    OstDlg.esperar(0.4)
    OstDlg.run(guion, ARTES)
    irse
  end

  def self.comprobar
    return if @corriendo
    return if !$game_map || $game_map.map_id != MAPA
    return if !$game_switches || $game_switches[SWITCH]
    return if !$game_switches[ANTES]
    return if !$game_player || $game_player.moving?
    return if $game_temp && ($game_temp.message_window_showing ||
                             $game_temp.player_transferring)
    return if !disponible?
    @corriendo = true
    begin
      $game_switches[SWITCH] = true
      run
    ensure
      @corriendo = false
    end
  end
end



#===============================================================================
# ESCENA 6 - EL LABORATORIO
#
#   Kaia entra por la puerta de abajo y sube por la alfombra. Al pasar de la
#   fila 15 arranca la escena: se la lleva sola hasta (14,9), al lado de Lira,
#   y la profesora Arce les habla desde (13,7), con la mesa de las tres
#   pokeballs a su derecha.
#
#   Es la primera escena de tres. El cuadro de dialogo tiene dos huecos por la
#   izquierda ("izq" y "izq2"): Arce en uno y Lira en el otro, y cuando cambia
#   el que habla los retratos se cruzan en un fundido.
#
#   Arce y Lira no estan puestas en el mapa: se crean al entrar, como Blanca
#   en la cocina. La charla acaba con "Venga. Acercaos." y sigue sin corte con
#   la fuga de los tres iniciales (OstinatoFuga, mas abajo). Al acabar se abre
#   la salida del pueblo.
#===============================================================================
module OstinatoLaboratorio
  MAPA   = 7
  SWITCH = 104       # "la escena del laboratorio ya se ha visto"
  ANTES  = 103       # y no salta si antes no se ha visto lo de la puerta
  LINEA  = 15        # al pasar de esta fila hacia arriba, arranca

  ID_LIRA = 921
  ID_ARCE = 922
  LIRA_X  = 12       # Lira esperando al lado de la alfombra
  LIRA_Y  = 9
  ARCE_X  = 13       # la profesora, delante de la mesa de las pokeballs
  ARCE_Y  = 7
  KAIA_X  = 14       # donde se planta Kaia para hablar
  KAIA_Y  = 9

  ARTES = {
    # Arce es mucho mas ancha que Blanca o Lira (636 px frente a 373 y 403),
    # asi que con la x de las otras la cara se le iba justo detras del cuadro.
    # Con x=40 su cabeza cae en el mismo sitio que la de ellas, en el 362.
    "izq"  => ["DlgProfesora.png", 40, 465, "DlgNomArce"],
    "izq2" => ["DlgLira.png", 174, 465, "DlgNomLira"],
    "der"  => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }

  def self.guion
    [
      ["LabTxt00", "izq"],   # Vaya. Ya estamos todas.
      ["LabTxt01", "izq2"],   # Le decia yo que no tardabas.
      ["LabTxt02", "der"],   # Has tardado tu menos, nada mas.
      ["LabTxt03", "izq2"],   # Yo sali de casa. Tu saliste de la cama.
      ["LabTxt04", "izq"],   # Dejadlo, que llevo aqui desde las ocho y ese chiste ya me lo se.
      ["LabTxt05", "izq"],   # Kaia. Como esta tu madre?
      ["LabTxt06", "der"],   # Fregando.
      ["LabTxt07", "izq"],   # Entonces esta bien. Dale recuerdos.
      ["LabTxt08", "izq"],   # Bueno.
      ["LabTxt09", "izq"],   # Sabeis por que estais aqui, no?
      ["LabTxt10", "izq2"],   # Si.
      ["LabTxt11", "der"],   # Mas o menos.
      ["LabTxt12", "izq"],   # Mas o menos me vale.
      ["LabTxt13", "izq2"],   # Profesora, usted ha visto lo de Ciudad Muda?
      ["LabTxt14", "izq"],   # Lo he visto.
      ["LabTxt15", "der"],   # Y que es?
      ["LabTxt16", "izq"],   # No lo se.
      ["LabTxt17", "izq"],   # Y el que te diga que lo sabe, tampoco.
      ["LabTxt18", "izq"],   # Hoy no toca eso. Hoy toca lo vuestro.
      ["LabTxt19", "izq"],   # Mirad la mesa.
      ["LabTxt20", "der"],   # Son tres.
      ["LabTxt21", "izq"],   # Una para cada una.
      ["LabTxt22", "izq"],   # La tercera se queda esperando.
      ["LabTxt23", "der"],   # Esperando a quien?
      ["LabTxt24", "izq"],   # A quien venga. Siempre viene alguien.
      ["LabTxt25", "izq"],   # No os lo penseis mucho, que luego se hace tarde y se me enfria el cafe.
      ["LabTxt26", "izq2"],   # Yo lo tengo decidido desde los seis anos.
      ["LabTxt27", "der"],   # Yo no.
      ["LabTxt28", "izq"],   # Pues mejor.
      ["LabTxt29", "izq"],   # Los que lo traen decidido de casa son los que se llevan la sorpresa.
      ["LabTxt30", "izq"]    # Venga. Acercaos.
    ] + OstinatoFuga.guion   # y sin soltar el cuadro, la fuga
  end

  def self.disponible?
    b = OstDlg.bmp(OstDlg::DIR + "LabTxt00.png")
    return false if !b
    b.dispose
    return true
  end

  def self.crear(id, x, y, nombre, charset, mirando)
    return if !$game_map || !$game_map.events
    return if $game_map.events[id]
    ev = RPG::Event.new(x, y)
    ev.id = id
    ev.name = nombre
    g = Game_Event.new($game_map.map_id, ev, $game_map)
    g.character_name = charset
    case mirando
    when 2 then g.turn_down
    when 4 then g.turn_left
    when 6 then g.turn_right
    else g.turn_up
    end
    $game_map.events[id] = g
    return g
  end

  # La profesora esta en el laboratorio siempre, no solo durante la escena: si
  # el jugador sale y vuelve a entrar, se la encuentra igual. Lira tambien,
  # hasta la fuga: despues se ha ido a buscarlos y la mesa se queda vacia.
  def self.poblar
    return if !$game_map || !$game_map.events
    escapados = OstinatoFuga.escapados?
    OstinatoFuga.vaciar_mesa if escapados
    falta = false
    if !$game_map.events[ID_ARCE]
      crear(ID_ARCE, ARCE_X, ARCE_Y, "Profesora Arce", "profesora", 2)
      falta = true
    end
    if !escapados && !$game_map.events[ID_LIRA]
      crear(ID_LIRA, LIRA_X, LIRA_Y, "Lira", "sora", 8)
      falta = true
    end
    return if !falta
    begin
      OstMapa.sprites
    rescue
    end
  end

  # Lanza una ruta y espera, sin quedarse colgado si algo se cruza.
  def self.mover(quien, pasos)
    return if !quien
    begin
      pbMoveRoute(quien, pasos)
    rescue
      return
    end
    vueltas = 0
    quietas = 0
    ultimo = [quien.x, quien.y]
    while quien.move_route_forcing && vueltas < 1200
      vueltas += 1
      OstDlg.tick
      if quien.x == ultimo[0] && quien.y == ultimo[1]
        quietas += 1
      else
        quietas = 0
        ultimo = [quien.x, quien.y]
      end
      break if quietas > 90
    end
    begin
      quien.instance_variable_set(:@move_route_forcing, false)
    rescue
    end
  end

  # Kaia se planta sola en su sitio: primero se pone en la columna y despues
  # sube. En ese orden, porque subiendo primero se le pondria Lira delante.
  def self.colocar_a_kaia
    return if !$game_player
    pasos = []
    x = $game_player.x
    y = $game_player.y
    while x < KAIA_X
      pasos.push(PBMoveRoute::RIGHT); x += 1
    end
    while x > KAIA_X
      pasos.push(PBMoveRoute::LEFT); x -= 1
    end
    while y > KAIA_Y
      pasos.push(PBMoveRoute::UP); y -= 1
    end
    mover($game_player, pasos) if pasos.length > 0
    begin
      $game_player.moveto(KAIA_X, KAIA_Y)
      $game_player.turn_up
    rescue
    end
  end

  def self.run
    poblar
    colocar_a_kaia
    OstDlg.esperar(0.4)
    OstDlg.run(guion, ARTES)
    OstinatoFuga.terminar
    # a partir de aqui ya puede salir del pueblo
    begin
      $game_switches[OstinatoSalida::SWITCH_LAB] = true
    rescue
    end
  end

  def self.comprobar
    return if @corriendo
    return if !$game_map || $game_map.map_id != MAPA
    return if !$game_player || $game_player.moving?
    return if $game_temp && ($game_temp.message_window_showing ||
                             $game_temp.player_transferring)
    poblar
    return if !$game_switches || $game_switches[SWITCH]
    return if !$game_switches[ANTES]
    return if $game_player.y > LINEA
    return if !disponible?
    @corriendo = true
    begin
      $game_switches[SWITCH] = true
      run
    ensure
      @corriendo = false
    end
  end
end


#===============================================================================
# ESCENA 6 (sigue) - LA FUGA DE LOS TRES INICIALES
#
#   Escena 3 del guion del Acto 0, adaptada a este laboratorio. Sigue sin corte
#   a "Venga. Acercaos.": Kaia y Lira se ponen delante de la mesa, Lira elige
#   sin mirar, y la primera Poke Ball se abre sola. Sale Mudkip y se las queda
#   mirando dos segundos; se abren las otras dos, y los tres saltan de la mesa
#   y se van en fila por la alfombra hasta la puerta de la calle.
#
#   Sin villano, sin combate y sin culpable: una Poke Ball se abre desde
#   dentro y la puerta esta abierta desde las ocho. Las frases de Bemol y
#   Tulio del guion las dice Arce, que es la que esta en este laboratorio.
#
#   Las tres bolas estan pintadas en el mapa, en la capa de arriba, encima de
#   la mesa de (16..18, 8). Al abrirse cada una se borra su casilla en marcha,
#   y con la fuga hecha (interruptor 73) la mesa se vacia cada vez que se
#   entra, sin tocar el dibujo del mapa en el editor.
#
#   Los tres iniciales, y Lira cuando se va, se crean y se borran en marcha,
#   como el resto de personajes del prologo. Interruptores del guion, con el
#   +50: 72 = la fuga ya ha pasado, 73 = los tres se han escapado (SW 0023).
#===============================================================================
module OstinatoFuga
  SW_FUGA   = 72
  SW_ESCAPE = 73

  MESA_Y  = 8
  CAPA    = 2                 # las bolas van en la capa de arriba
  # x de cada bola, su charset y la especie para el grito
  BOLAS = [
    [16, "MUDKIP",     :MUDKIP],
    [17, "FENNEKIN",   :FENNEKIN],
    [18, "SPRIGATITO", :SPRIGATITO]
  ]
  ID_POKE = 930
  DEPRISA = 5

  # Donde se ponen delante de la mesa: Lira delante de la primera bola, que es
  # la que ha elegido, y Kaia a su lado.
  LIRA_X = 16
  KAIA_X = 17
  DELANTE_Y = 9

  SONIDO_BOLA = "Battle recall"

  def self.guion
    [
      ["haz", proc { acercarse }],     # Kaia y Lira se ponen delante de la mesa
      ["FugaTxt00", "izq2"],  # Esa.
      ["FugaTxt01", "der"],   # Aun no las has visto.
      ["FugaTxt02", "izq2"],  # Ya. Pero esa.
      ["haz", proc { abrir_primera }], # clic: sale Mudkip y se las queda mirando
      ["haz", proc { escapar }],       # clic, clic: y los tres se van
      ["pausa", 1.2],
      ["FugaTxt03", "izq2"],  # ...
      ["FugaTxt04", "der"],   # Se han ido.
      ["FugaTxt05", "izq"],   # Ya lo veo.
      ["FugaTxt06", "izq2"],  # Eso lo pueden hacer?
      ["FugaTxt07", "izq"],   # Una Poke Ball se abre desde dentro.
      ["FugaTxt08", "izq"],   # Desde fuera hace falta el boton. Desde dentro, no.
      ["FugaTxt09", "izq"],   # Llevaban ahi desde ayer. Eso es mucho tiempo.
      ["FugaTxt10", "izq"],   # Y la puerta esta abierta desde las ocho, como todos los dias.
      ["FugaTxt11", "izq"],   # No han ido lejos. No pueden. Es un pueblo.
      ["FugaTxt12", "izq"],   # Traedmelos y hablamos.
      ["FugaTxt13", "izq2"],  # Los tres?
      ["FugaTxt14", "izq"],   # Los tres.
      ["FugaTxt15", "izq2"],  # Y la que traiga mas...?
      ["FugaTxt16", "izq"],   # No. Los tres, y luego hablais vosotras.
      ["FugaTxt17", "izq"],   # Yo no reparto nada.
      ["FugaTxt18", "izq2"],  # Vale. Pues a buscar.
      ["haz", proc { lira_se_va }]
    ]
  end

  def self.escapados?
    return $game_switches && $game_switches[SW_ESCAPE]
  end

  def self.evento(id)
    return nil if !$game_map || !$game_map.events
    return $game_map.events[id]
  end

  # Quita la bola de una columna de la mesa. La bola cae entre dos filas del
  # tileset, asi que se borra la casilla de la mesa y la de encima.
  def self.quitar_bola(x)
    cambiado = false
    [MESA_Y - 1, MESA_Y].each do |y|
      next if $game_map.data[x, y, CAPA] == 0
      $game_map.data[x, y, CAPA] = 0
      cambiado = true
    end
    return cambiado
  end

  def self.refrescar_casillas
    begin
      $scene.map_renderer.refresh
    rescue
    end
  end

  def self.vaciar_mesa
    return if !$game_map
    cambiado = false
    BOLAS.each { |b| cambiado = true if quitar_bola(b[0]) }
    refrescar_casillas if cambiado
  end

  # Varias rutas a la vez; se espera a que acaben todas. Cada una es
  # [personaje, pasos, fotogramas de retraso antes de arrancar].
  def self.mover_juntos(rutas)
    pendientes = rutas.map { |r| [r[0], r[1], r[2] || 0, false] }
    vueltas = 0
    loop do
      pendientes.each do |r|
        next if !r[0] || r[3]
        r[2] -= 1
        next if r[2] > 0
        begin
          pbMoveRoute(r[0], r[1])
        rescue
        end
        r[3] = true
      end
      OstDlg.tick
      vueltas += 1
      break if vueltas > 2400
      break if pendientes.all? { |r| !r[0] || (r[3] && !r[0].move_route_forcing) }
    end
    pendientes.each do |r|
      next if !r[0]
      begin
        r[0].instance_variable_set(:@move_route_forcing, false)
      rescue
      end
    end
  end

  def self.crear_poke(i)
    b = BOLAS[i]
    ev = RPG::Event.new(b[0], MESA_Y)
    ev.id = ID_POKE + i
    ev.name = b[1]
    ev.pages[0].graphic.character_name = b[1]
    ev.pages[0].graphic.direction = 2
    ev.pages[0].through = true
    g = Game_Event.new($game_map.map_id, ev, $game_map)
    g.opacity = 0
    $game_map.events[ev.id] = g
    OstMapa.sprites
    return g
  end

  def self.borrar(id)
    return if !evento(id)
    $game_map.events.delete(id)
    OstMapa.sprites
  end

  # Clic: la bola desaparece de la mesa y en su sitio aparece el Pokemon, con
  # un destello corto y su grito.
  def self.abrir(i)
    b = BOLAS[i]
    g = crear_poke(i)
    begin
      pbSEPlay(SONIDO_BOLA, 80)
    rescue
    end
    begin
      $game_screen.start_flash(Color.new(255, 255, 255, 110), 8)
    rescue
    end
    refrescar_casillas if quitar_bola(b[0])
    o = 0
    while o < 255
      o += 32
      o = 255 if o > 255
      g.opacity = o
      OstDlg.tick
    end
    OstDlg.esperar(0.15)
    begin
      Pokemon.play_cry(b[2])
    rescue
    end
    return g
  end

  # Kaia y Lira se ponen delante de la mesa, mirandola. Lira baja una fila
  # para no pasar por encima de Kaia, que esta entre ella y la mesa.
  def self.acercarse
    lira = evento(OstinatoLaboratorio::ID_LIRA)
    arce = evento(OstinatoLaboratorio::ID_ARCE)
    kaia = []
    x = $game_player.x
    while x < KAIA_X
      kaia.push(PBMoveRoute::RIGHT)
      x += 1
    end
    kaia.push(PBMoveRoute::TURN_UP)
    pasosLira = []
    if lira
      pasosLira.push(PBMoveRoute::DOWN)
      (LIRA_X - lira.x).times { pasosLira.push(PBMoveRoute::RIGHT) }
      pasosLira.push(PBMoveRoute::UP)
      pasosLira.push(PBMoveRoute::TURN_UP)
    end
    mover_juntos([[$game_player, kaia, 0], [lira, pasosLira, 6]])
    begin
      $game_player.moveto(KAIA_X, DELANTE_Y)
      $game_player.turn_up
      if lira
        lira.moveto(LIRA_X, DELANTE_Y)
        lira.turn_up
      end
      arce.turn_right if arce     # Arce se vuelve hacia la mesa
    rescue
    end
    OstDlg.esperar(0.4)
  end

  # La primera se abre sola. Mudkip se queda quieto mirandolas dos segundos.
  def self.abrir_primera
    OstDlg.esperar(0.6)
    abrir(0)
    OstDlg.esperar(2.0)
  end

  # Clic, clic. Y los tres se van: saltan de la mesa por la izquierda, bajan
  # por la columna 15 hasta la alfombra y siguen por ella hasta la puerta. En
  # fila, cada uno arrancando cuando el de delante ya ha dejado hueco.
  def self.escapar
    abrir(1)
    OstDlg.esperar(0.25)
    abrir(2)
    OstDlg.esperar(0.7)
    rutas = []
    BOLAS.each_with_index do |b, i|
      g = evento(ID_POKE + i)
      next if !g
      g.move_speed = DEPRISA
      pasos = [PBMoveRoute::TURN_LEFT]
      (b[0] - 16).times { pasos.push(PBMoveRoute::LEFT) }   # por encima de la mesa
      pasos += [PBMoveRoute::JUMP, -1, 0]                     # abajo, a (15,8)
      3.times { pasos.push(PBMoveRoute::DOWN) }               # (15,11)
      pasos.push(PBMoveRoute::LEFT)                           # (14,11)
      11.times { pasos.push(PBMoveRoute::DOWN) }              # por la alfombra, (14,22)
      pasos.push(PBMoveRoute::LEFT)                           # (13,22)
      pasos.push(PBMoveRoute::DOWN)                           # la puerta, (13,23)
      rutas.push([g, pasos, 1 + i * 14])
    end
    # Kaia y Lira los siguen con la mirada: se giran hacia la puerta
    lira = evento(OstinatoLaboratorio::ID_LIRA)
    mover_juntos(rutas + [[$game_player, [PBMoveRoute::TURN_DOWN], 60],
                          [lira, [PBMoveRoute::TURN_DOWN], 50]])
    # ya en la calle: se van del mapa
    BOLAS.each_index do |i|
      g = evento(ID_POKE + i)
      next if !g
      while g.opacity > 0
        g.opacity = [g.opacity - 40, 0].max
        OstDlg.tick
      end
      borrar(ID_POKE + i)
    end
    $game_switches[SW_FUGA] = true
  end

  # Lira se va a buscarlos, deprisa, por el mismo camino.
  def self.lira_se_va
    lira = evento(OstinatoLaboratorio::ID_LIRA)
    return if !lira
    lira.move_speed = DEPRISA
    pasos = [PBMoveRoute::DOWN]
    (lira.x - 14).times { pasos.push(PBMoveRoute::LEFT) }
    12.times { pasos.push(PBMoveRoute::DOWN) }
    pasos += [PBMoveRoute::LEFT, PBMoveRoute::DOWN]
    mover_juntos([[lira, pasos, 0], [$game_player, [PBMoveRoute::TURN_DOWN], 0]])
    borrar(OstinatoLaboratorio::ID_LIRA)
  end

  # Al acabar la escena, pase lo que pase por el camino, queda todo en su
  # estado final: la mesa vacia, sin los tres y sin Lira.
  def self.terminar
    $game_switches[SW_FUGA] = true
    $game_switches[SW_ESCAPE] = true
    BOLAS.each_index { |i| borrar(ID_POKE + i) }
    borrar(OstinatoLaboratorio::ID_LIRA)
    vaciar_mesa
    begin
      $game_player.instance_variable_set(:@move_route_forcing, false)
      $game_player.through = false
    rescue
    end
  end
end


#===============================================================================
# LOS VECINOS DE PUEBLO PRELUDIO
#
#   Gente del pueblo con la que se puede hablar. No llevan retrato ni placa de
#   nombre: salen en el cuadro neutro, el mismo de las acotaciones. Los que
#   tienen cara son los del reparto; el pueblo habla desde el cuadro pelado.
#
#   No estan puestos como eventos en el mapa: se crean al entrar, igual que
#   Blanca o Arce. Cada uno lleva su pagina con una sola orden, una llamada a
#   OstinatoVecinos.hablar, asi que se disparan con el boton de siempre y el
#   motor se encarga de girarlos hacia Kaia y de no pisarse con otra cosa.
#===============================================================================
module OstinatoVecinos
  MAPA = 2
  BASE = 940         # ids de evento a partir de aqui, lejos de los del mapa

  # x, y, hacia donde mira, charset, primera frase, ultima frase
  GENTE = [
    [ 6, 19, 2, "anciano1",  0,  2],   # el del banco, junto a la fuente
    [13, 16, 2, "mujer1",    3,  4],   # la de la colada
    [10, 16, 2, "anciana1",  5,  6],   # la que mira desde la puerta
    [18,  7, 8, "criadora",  7,  8],   # la de las plantas, junto al parterre
    [15, 30, 2, "pescador",  9, 10],   # el de la pesca, abajo junto al agua
    [34, 26, 2, "anciano2", 11, 12],   # el del pokemon viejo
    [ 8, 18, 2, "anciana2", 13, 14],   # la de las gafas
    [25, 24, 2, "hombre1",  15, 16],   # el que no se acuerda
    [28, 17, 2, "veterana", 17, 18]    # la que no sale del pueblo
  ]

  # Sin retratos y sin placa: el cuadro neutro y punto.
  ARTES = {}

  def self.disponible?
    b = OstDlg.bmp(OstDlg::DIR + "VecTxt00.png")
    return false if !b
    b.dispose
    return true
  end

  def self.hablar(i)
    g = GENTE[i]
    return if !g
    guion = []
    k = g[4]
    while k <= g[5]
      guion.push([sprintf("VecTxt%02d", k), "cap"])
      k += 1
    end
    OstDlg.run(guion, ARTES)
  end

  def self.crear(i)
    g = GENTE[i]
    id = BASE + i
    return if $game_map.events[id]
    ev = RPG::Event.new(g[0], g[1])
    ev.id = id
    ev.name = "Vecino" + i.to_s
    # el dibujo va en la pagina, no en el evento: asi aguanta un refresco
    ev.pages[0].graphic.character_name = g[3]
    ev.pages[0].graphic.direction = g[2]
    ev.pages[0].trigger = 0           # hablarle con el boton
    ev.pages[0].list = [
      RPG::EventCommand.new(355, 0, ["OstinatoVecinos.hablar(" + i.to_s + ")"]),
      RPG::EventCommand.new(0, 0, [])
    ]
    $game_map.events[id] = Game_Event.new($game_map.map_id, ev, $game_map)
  end

  def self.poblar
    return if !$game_map || !$game_map.events
    return if $game_map.map_id != MAPA
    return if !disponible?
    faltaba = false
    i = 0
    while i < GENTE.length
      if !$game_map.events[BASE + i]
        crear(i)
        faltaba = true
      end
      i += 1
    end
    return if !faltaba
    begin
      OstMapa.sprites
    rescue
    end
  end

  def self.comprobar
    return if !$game_map || $game_map.map_id != MAPA
    return if !$game_player || $game_player.moving?
    return if $game_temp && ($game_temp.message_window_showing ||
                             $game_temp.player_transferring)
    poblar
  end
end


#===============================================================================
# LA SALIDA DEL PUEBLO, CERRADA HASTA PASAR POR EL LABORATORIO
#
#   Los cuatro eventos de la fila de abajo del mapa 2 llevan a la ruta 1, y
#   antes de teletransportar oscurecen la pantalla. Por eso no vale con comerse
#   el teletransporte: para entonces ya se ha ido el mapa a negro y el aviso
#   sale sobre la nada.
#
#   Asi que se le corta el paso al jugador ANTES: las cuatro casillas de la
#   salida dejan de ser andables mientras el pueblo este cerrado, y al chocar
#   con ellas salta el aviso. El evento no llega a dispararse.
#
#   El interruptor 78 (el SW 0028 del guion, +50) lo enciende el laboratorio
#   cuando se escapan los tres iniciales; hasta entonces el pueblo esta cerrado.
#   Los interruptores de la v21 van del 39 al 50 reservados: por eso el
#   prologo usa del 101 al 104 y la numeracion del guion va con +50.
#===============================================================================
module OstinatoSalida
  MAPA_PUEBLO = 2
  MAPA_RUTA   = 9
  SWITCH_LAB  = 78   # "ya ha estado en el laboratorio"
  ESPERA      = 40   # fotogramas hasta poder repetir el aviso

  # las cuatro casillas de la fila de abajo que llevan a la ruta 1
  SALIDAS = [[20, 34], [21, 34], [22, 34], [23, 34]]

  ARTES = {
    "der" => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }

  AVISO = [
    ["PuerAvi00", "der"],   # Todavia no. Primero el laboratorio.
    ["PuerAvi01", "der"]    # Esta al norte del pueblo, y la profesora me espera.
  ]

  def self.cerrado?
    return false if !$game_map || $game_map.map_id != MAPA_PUEBLO
    return false if !$game_switches
    return false if $game_switches[SWITCH_LAB]
    b = OstDlg.bmp(OstDlg::DIR + "PuerAvi00.png")
    return false if !b
    b.dispose
    return true
  end

  def self.es_salida?(x, y)
    SALIDAS.each { |s| return true if s[0] == x && s[1] == y }
    return false
  end

  # El choque solo deja una nota: el aviso se saca desde Scene_Map, que es
  # donde se puede parar el juego sin romper nada.
  def self.pedir_aviso
    @pedido = true
  end

  def self.avisar
    OstDlg.run(AVISO, ARTES)
  end

  def self.comprobar
    return if !@pedido
    @pedido = false
    return if @corriendo
    @ultimo = 0 if !@ultimo
    ahora = (Graphics.frame_count rescue 0)
    return if ahora - @ultimo < ESPERA && ahora >= @ultimo
    @corriendo = true
    begin
      avisar
      @ultimo = (Graphics.frame_count rescue 0)
    ensure
      @corriendo = false
    end
  end
end

class Game_Player
  alias ostinato_salida_passable? passable?

  def passable?(x, y, d, *resto)
    begin
      nx = x + (d == 6 ? 1 : (d == 4 ? -1 : 0))
      ny = y + (d == 2 ? 1 : (d == 8 ? -1 : 0))
      if OstinatoSalida.es_salida?(nx, ny) && OstinatoSalida.cerrado?
        OstinatoSalida.pedir_aviso
        return false
      end
    rescue
    end
    return ostinato_salida_passable?(x, y, d, *resto)
  end
end


class Scene_Map
  alias ostinato_despertar_update update

  def update
    ostinato_despertar_update
    OstinatoDespertar.comprobar
    OstinatoCocina.comprobar
    OstinatoPuerta.comprobar
    OstinatoLaboratorio.comprobar
    OstinatoVecinos.comprobar
    OstinatoSalida.comprobar
  end
end

# El telon, con la pantalla todavia congelada.
EventHandlers.add(:on_map_or_spriteset_change, :ostinato_telon,
  proc { |_scene, _map_changed|
    OstinatoDespertar.telon
  }
)



