#===============================================================================
# Pokemon Ostinato - La eleccion y el primer combate contra Lira
#
#   Escenas 5 y 6 del Acto 0 (OSTINATO-ACTO0, p. 14 y 16), montadas las dos en
#   el laboratorio:
#
#   LA ELECCION. Kaia entra en el laboratorio con los tres iniciales detras
#   (interruptores 85, 86 y 87). Dejan de seguirla y se quedan en el suelo,
#   delante de la mesa: son los eventos "Mudkip lab", "Fennekin lab" y
#   "Sprigatito lab" del mapa 7, que salen con su "devuelto" (74, 75, 76) y
#   se quitan con su "se lo han llevado" (88, 89, 90). Arce habla, Kaia elige
#   (Var 7, "Starter elegido": 1, 2 o 3), Arce le pregunta que siente (cuatro
#   respuestas, ninguna buena: Var 65, la 0015 del guion con el +50, solo para
#   el epilogo) y Lira se queda el de la DERECHA del de Kaia (lo decidio
#   David): Mudkip -> Fennekin -> Sprigatito -> Mudkip. Var 66 = el de Lira.
#   Interruptor 77 (el 0027 del guion): Lira ya ha elegido. El tercero se
#   queda en el suelo del laboratorio todo el juego.
#
#   EL COMBATE. Al bajar Kaia por la sala para irse, a media altura (fila
#   LINEA), Lira la para. Hablan con las frases de la escena 6, sale la
#   animacion "LIRA TE DESAFIA" (estilo del "nuevo rival" del Smash: negro,
#   rayos, la silueta) y combaten: un Pokemon a nivel 5, se puede perder. Al
#   acabar, sus frases segun el resultado, se va por la puerta y se abre la
#   salida sur del pueblo (interruptor 78).
#
#   Textos: EleTxt, EleOpc y RivTxt (recursos/guion_eleccion*.txt y
#   guion_combate_lira.txt, con recursos/herramientas/textos.ps1).
#===============================================================================

#-------------------------------------------------------------------------------
# Elegir una opcion dentro del pergamino de Kaia. opciones: PNG de texto de
# una linea (sin ".png"). Devuelve el indice elegido. Va en alta resolucion,
# como el resto de dialogos (OstDlg.hd_subir).
#-------------------------------------------------------------------------------
module OstDlg
  def self.elegir(opciones, retrato = ["DlgKaia.png", 1333, 503])
    estado = {}
    hd_subir(estado)
    e = gw.to_f / ART_W
    vp = Viewport.new(0, 0, gw, gh)
    vp.z = 99999
    datos = CAJAS["der"]
    cara = Sprite.new(vp)
    cara.bitmap = bmp(DIR + retrato[0])
    cara.zoom_x = cara.zoom_y = e
    cara.x = (retrato[1] * e).to_i
    cara.y = (retrato[2] * e).to_i
    cara.z = 10
    cara.opacity = 0
    caja = Sprite.new(vp)
    caja.bitmap = bmp(DIR + datos[0])
    caja.zoom_x = caja.zoom_y = e
    caja.x = (datos[1] * e).to_i
    caja.y = (datos[2] * e).to_i
    caja.z = 20
    caja.opacity = 0
    # el papel del recuadro va de y=651 a y=813: las filas se reparten ahi
    muchas = opciones.length > 3
    paso = muchas ? 38 : 48
    esc  = muchas ? 0.86 : 1.0
    y0   = muchas ? 656 : 662
    filas = []
    opciones.each_with_index do |png, i|
      s = Sprite.new(vp)
      s.bitmap = bmp(DIR + png + ".png")
      s.src_rect = Rect.new(0, 0, s.bitmap.width, 50) if s.bitmap
      s.zoom_x = s.zoom_y = e * esc
      s.x = ((datos[3] + 34) * e).to_i
      s.y = ((y0 + i * paso) * e).to_i
      s.z = 22
      s.opacity = 0
      filas.push(s)
    end
    # la hojita del pergamino hace de flecha
    hoja = Sprite.new(vp)
    hoja.bitmap = bmp(DIR + datos[5])
    hoja.zoom_x = hoja.zoom_y = e * 0.8
    hoja.z = 23
    hoja.opacity = 0
    sel = 0
    colocar = proc do |t|
      filas.each_with_index { |s, i| s.opacity = (i == sel) ? caja.opacity : (caja.opacity * 0.45).to_i }
      hoja.x = ((datos[3] - 4 + Math.sin(t * 0.12) * 3) * e).to_i
      hoja.y = ((y0 + sel * paso + 2) * e).to_i
      hoja.opacity = caja.opacity
    end
    begin
      while caja.opacity < 255
        caja.opacity = [caja.opacity + 24, 255].min
        cara.opacity = caja.opacity
        colocar.call(0)
        tick
      end
      t = 0
      loop do
        t += 1
        tick
        if Input.trigger?(Input::UP)
          sel = (sel - 1) % filas.length
          pbPlayCursorSE rescue nil
        elsif Input.trigger?(Input::DOWN)
          sel = (sel + 1) % filas.length
          pbPlayCursorSE rescue nil
        elsif Input.trigger?(Input::C)
          pbPlayDecisionSE rescue nil
          break
        end
        colocar.call(t)
      end
      while caja.opacity > 0
        caja.opacity = [caja.opacity - 24, 0].max
        cara.opacity = caja.opacity
        colocar.call(t)
        tick
      end
    ensure
      filas.each { |s| soltar(s) }
      soltar(hoja); soltar(caja); soltar(cara)
      begin; vp.dispose; rescue; end
      hd_bajar(estado)
    end
    return sel
  end
end

#-------------------------------------------------------------------------------
module OstinatoEleccion
  MAPA = 7
  ESPECIES = [:MUDKIP, :FENNEKIN, :SPRIGATITO]
  NOMBRES  = ["Mudkip", "Fennekin", "Sprigatito"]   # el de su seguidor
  SW_SIGUE    = [85, 86, 87]
  SW_DEVUELTO = [74, 75, 76]
  SW_LLEVADO  = [88, 89, 90]
  SW_ELEGIDO  = 77     # Lira ya ha elegido (SW 0027 del guion)
  SW_COMBATE  = 78     # combate hecho: se abre la salida sur (SW 0028)
  VAR_INICIAL = 7      # "Starter elegido" de Essentials: 1, 2 o 3
  VAR_SIENTE  = 65     # que siente Kaia (Var 0015 del guion): 1..4
  VAR_LIRA    = 66     # el inicial de Lira: 1, 2 o 3
  KAIA_X = 17          # donde se planta Kaia, delante de los tres
  KAIA_Y = 10
  LINEA  = 16          # al bajar hasta esta fila para irse, Lira la para
  PUERTA_X = 13        # la puerta del laboratorio
  PUERTA_Y = 23
  NIVEL = 5

  ARTES_COMBATE = {
    "izq" => ["DlgLira.png", 174, 465, "DlgNomLira"],
    "der" => ["DlgKaia.png", 1333, 503, "DlgNomKaia"]
  }

  def self.texto(prefijo, desde, hasta, lado)
    (desde..hasta).map { |k| [sprintf("%s%02d", prefijo, k), lado.is_a?(Array) ? lado[k - desde] : lado] }
  end

  def self.lira
    return OstMapa.evento("Lira")
  end

  def self.refrescar
    $game_map.need_refresh = true
    begin
      $game_map.refresh
      OstMapa.sprites
    rescue
    end
  end

  #--- escena 5 ----------------------------------------------------------------
  def self.toca_elegir?
    return false if !$game_switches || $game_switches[SW_ELEGIDO]
    return SW_SIGUE.all? { |s| $game_switches[s] }
  end

  # Los tres dejan de seguirla y aparecen en el suelo, delante de la mesa.
  def self.dejarlos
    pbFadeOutIn do
      NOMBRES.each do |n|
        begin
          Followers.remove(n)
        rescue
        end
      end
      SW_SIGUE.each { |s| $game_switches[s] = false }
      SW_DEVUELTO.each { |s| $game_switches[s] = true }
      begin
        $game_player.moveto(KAIA_X, KAIA_Y)
        $game_player.turn_up
        $game_player.center(KAIA_X, KAIA_Y)
      rescue
      end
      refrescar
    end
  end

  def self.elegir
    dejarlos
    OstDlg.esperar(0.4)
    artes = OstinatoLaboratorio::ARTES
    OstDlg.run(texto("EleTxt", 0, 5, ["izq", "izq", "izq", "izq2", "izq", "izq2"]), artes)
    i = OstDlg.elegir(["EleOpc00", "EleOpc01", "EleOpc02"])
    $game_variables[VAR_INICIAL] = i + 1
    $game_switches[SW_LLEVADO[i]] = true
    refrescar
    begin
      pbAddPokemon(ESPECIES[i], NIVEL)
    rescue
      pbAddPokemonSilent(ESPECIES[i], NIVEL) rescue nil
    end
    OstDlg.run(texto("EleTxt", 6, 7, "izq"), artes)
    $game_variables[VAR_SIENTE] = OstDlg.elegir(["EleOpc03", "EleOpc04", "EleOpc05", "EleOpc06"]) + 1
    OstDlg.run(texto("EleTxt", 8, 8, "izq"), artes)
    # Lira coge el de la derecha del de Kaia
    j = (i + 1) % 3
    $game_variables[VAR_LIRA] = j + 1
    OstDlg.run(texto("EleTxt", 9, 11, ["izq2", "izq", "izq2"]), artes)
    $game_switches[SW_LLEVADO[j]] = true
    $game_switches[SW_ELEGIDO] = true
    refrescar
  end

  #--- escena 6 ----------------------------------------------------------------
  def self.toca_combate?
    return false if !$game_switches || !$game_switches[SW_ELEGIDO] || $game_switches[SW_COMBATE]
    return $game_player.y >= LINEA
  end

  # Lira se acerca a Kaia desde donde este y se miran.
  def self.acercarse
    l = lira
    return if !l
    destino = nil
    [[0, -1], [-1, 0], [1, 0], [0, 1]].each do |dx, dy|
      x = $game_player.x + dx
      y = $game_player.y + dy
      next if !$game_map.passable?(x, y, 0)
      destino = [x, y]
      break
    end
    if destino
      pasos = OstMapa.camino(l, destino[0], destino[1])
      OstinatoLaboratorio.mover(l, pasos) if pasos && pasos.length > 0
    end
    OstMapa.mirarse(l, $game_player)
    OstMapa.mirarse($game_player, l)
  end

  def self.combatir
    j = ($game_variables[VAR_LIRA] || 1) - 1
    j = 0 if j < 0 || j > 2
    ganado = false
    begin
      setBattleRule("canLose")
      setBattleRule("backdrop", "laboratorio")
      ganado = TrainerBattle.start(:LIRA, "Lira", j)
    rescue => e
      echoln("OstinatoEleccion: el combate no ha podido empezar: #{e.message}") rescue nil
    end
    return ganado
  end

  def self.irse
    l = lira
    return if !l
    pasos = OstMapa.camino(l, PUERTA_X, PUERTA_Y) || []
    # empieza a andar hacia la salida, se para, y le dice lo ultimo
    OstinatoLaboratorio.mover(l, pasos[0, 3]) if pasos.length > 0
    OstMapa.mirarse(l, $game_player)
    OstDlg.run(texto("RivTxt", 17, 18, "izq"), ARTES_COMBATE)
    pasos = OstMapa.camino(l, PUERTA_X, PUERTA_Y) || []
    OstinatoLaboratorio.mover(l, pasos) if pasos.length > 0
    OstDlg.esperar(0.2)
    OstMapa.quitar(l)
  end

  def self.combate
    acercarse
    OstDlg.esperar(0.3)
    OstDlg.run(texto("RivTxt", 0, 7, ["izq", "der", "izq", "der", "izq", "izq", "izq", "izq"]), ARTES_COMBATE)
    ganado = combatir
    OstDlg.esperar(0.4)
    if ganado
      OstDlg.run(texto("RivTxt", 8, 10, "izq"), ARTES_COMBATE)
    else
      OstDlg.run(texto("RivTxt", 11, 12, "izq") + [["pausa", 1.5]] + texto("RivTxt", 13, 13, "izq"), ARTES_COMBATE)
    end
    OstDlg.run(texto("RivTxt", 14, 16, ["izq", "der", "izq"]), ARTES_COMBATE)
    irse
    $game_switches[SW_COMBATE] = true
    refrescar
  end

  #-----------------------------------------------------------------------------
  def self.comprobar
    return if @corriendo
    return if !$game_map || $game_map.map_id != MAPA
    return if !$game_player || $game_player.moving?
    return if $game_temp && ($game_temp.message_window_showing ||
                             $game_temp.player_transferring || $game_temp.in_battle)
    if toca_elegir?
      @corriendo = true
      begin
        elegir
      ensure
        @corriendo = false
      end
    elsif toca_combate?
      @corriendo = true
      begin
        combate
      ensure
        @corriendo = false
      end
    end
  end
end

class Scene_Map
  alias ostinato_eleccion_update update
  def update
    ostinato_eleccion_update
    OstinatoEleccion.comprobar
  end
end

#-------------------------------------------------------------------------------
# "LIRA TE DESAFIA": la animacion antes del combate contra Lira, como la del
# nuevo rival del Smash. La pantalla se va a negro, giran unos rayos de luz,
# entra la silueta de Lira con el filo blanco y cae el letrero. Va a 1920x1080
# (OstinatoHD), sobre una foto del mapa, y acaba en negro, que es como tiene
# que acabar una animacion de entrada a combate.
# Arte en Graphics/Titles: DesafioRayos, DesafioSilueta, DesafioTexto.
#-------------------------------------------------------------------------------
module OstDesafio
  DIR = "Graphics/Titles/"

  def self.bmp(n)
    begin
      return Bitmap.new(DIR + n)
    rescue
      return nil
    end
  end

  def self.suave(u)
    u = 0.0 if u < 0
    u = 1.0 if u > 1
    return 1 - (1 - u) * (1 - u) * (1 - u)
  end

  def self.animar(viewport)
    foto = nil
    begin
      foto = Graphics.snap_to_bitmap
    rescue
    end
    antes = OstinatoHD.subir
    w = Graphics.width
    h = Graphics.height
    vp = Viewport.new(0, 0, w, h)
    vp.z = 999_999
    sprites = []
    nuevo = proc do |bitmap, z|
      s = Sprite.new(vp)
      s.bitmap = bitmap
      s.z = z
      sprites.push(s)
      s
    end
    begin
      mapa = nuevo.call(foto, 0)
      if foto
        mapa.zoom_x = w.to_f / foto.width
        mapa.zoom_y = h.to_f / foto.height
      end
      negro_b = Bitmap.new(w, h)
      negro_b.fill_rect(0, 0, w, h, Color.new(0, 0, 0))
      negro = nuevo.call(negro_b, 1)
      negro.opacity = 0
      rayos = nuevo.call(bmp("DesafioRayos.png"), 2)
      if rayos.bitmap
        rayos.ox = rayos.bitmap.width / 2
        rayos.oy = rayos.bitmap.height / 2
      end
      rayos.x = w / 2
      rayos.y = h / 2 - 60
      rayos.opacity = 0
      rayos.tone = Tone.new(40, -60, -80)
      barra_b = Bitmap.new(w, 18)
      barra_b.fill_rect(0, 0, w, 18, Color.new(255, 255, 255))
      barras = [nuevo.call(barra_b, 3), nuevo.call(barra_b, 3)]
      barras[0].y = 330
      barras[1].y = 720
      barras.each { |b| b.x = -w; b.opacity = 230 }
      silueta = nuevo.call(bmp("DesafioSilueta.png"), 4)
      if silueta.bitmap
        silueta.ox = silueta.bitmap.width / 2
        silueta.oy = silueta.bitmap.height
      end
      silueta.x = w / 2
      silueta.y = h - 185
      silueta.opacity = 0
      letrero = nuevo.call(bmp("DesafioTexto.png"), 5)
      if letrero.bitmap
        letrero.ox = letrero.bitmap.width / 2
        letrero.oy = letrero.bitmap.height / 2
      end
      letrero.x = w / 2
      letrero.y = h - 140
      letrero.opacity = 0
      blanco_b = Bitmap.new(w, h)
      blanco_b.fill_rect(0, 0, w, h, Color.new(255, 255, 255))
      blanco = nuevo.call(blanco_b, 6)
      blanco.opacity = 0

      paso = proc do
        rayos.angle = (rayos.angle + 0.35) % 360 if rayos.bitmap
        Graphics.update
        Input.update
      end

      # un destello y a negro
      pbSEPlay("Vs flash") rescue nil
      6.times { |f| blanco.opacity = 255 - f * 20; paso.call }
      negro.opacity = 255
      mapa.visible = false
      8.times { |f| blanco.opacity = [blanco.opacity - 40, 0].max; paso.call }
      # las dos rayas cruzan la pantalla y se encienden los rayos
      12.times do |f|
        u = suave((f + 1) / 12.0)
        barras[0].x = (-w + 2 * w * u).to_i
        barras[1].x = (w - 2 * w * u).to_i
        rayos.opacity = (255 * u).to_i
        rayos.zoom_x = rayos.zoom_y = 0.6 + 0.4 * u
        paso.call
      end
      barras.each { |b| b.visible = false }
      # entra la silueta, de mas grande a su sitio
      16.times do |f|
        u = suave((f + 1) / 16.0)
        silueta.opacity = (255 * u).to_i
        silueta.zoom_x = silueta.zoom_y = 1.05 - 0.25 * u
        paso.call
      end
      # cae el letrero de golpe, con un temblor
      pbSEPlay("Vs sword") rescue nil
      8.times do |f|
        u = suave((f + 1) / 8.0)
        letrero.opacity = (255 * u).to_i
        letrero.zoom_x = letrero.zoom_y = 2.2 - 1.2 * u
        paso.call
      end
      blanco.opacity = 120
      12.times do |f|
        d = (12 - f) * 2
        vp.ox = (f.even? ? d : -d)
        vp.oy = (f.even? ? -d / 2 : d / 2)
        blanco.opacity = [blanco.opacity - 12, 0].max
        paso.call
      end
      vp.ox = 0
      vp.oy = 0
      # se queda un poco, con el letrero latiendo
      70.times do |f|
        letrero.tone = (f / 6).even? ? Tone.new(0, 0, 0) : Tone.new(60, 40, 40)
        paso.call
      end
      # y todo a negro
      negro.z = 10
      negro.opacity = 0
      16.times { |f| negro.opacity = ((f + 1) * 16).clamp(0, 255); paso.call }
      viewport.color = Color.new(0, 0, 0, 255) if viewport
    ensure
      sprites.each do |s|
        next if s.disposed?
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
        s.dispose
      end
      begin; vp.dispose; rescue; end
      OstinatoHD.bajar(antes) if antes
      viewport.color = Color.new(0, 0, 0, 255) if viewport
    end
  end
end

SpecialBattleIntroAnimations.register("ostinato_lira_desafia", 100,
  proc { |battle_type, foe, location|
    next false if battle_type.even? || !foe || foe.length != 1
    next foe[0].trainer_type == :LIRA
  },
  proc { |viewport, battle_type, foe, location|
    OstDesafio.animar(viewport)
  }
)
