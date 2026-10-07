#===============================================================================
# Pokemon Ostinato - Arranque del juego
#
#   1. El video de marca. MKXP no reproduce video, asi que va como secuencia de
#      fotogramas, igual que el fondo del menu.
#   2. La portada dibujada a mano, quieta, con el boton "pulsa para continuar"
#      latiendo. Si el jugador no toca nada en 15 s, asoma el Diglett; cuando
#      termina de meterse, vuelve a contar.
#   3. Enter lleva al menu de siempre.
#
# El arte esta hecho a 1920x1080 y lo encoge el propio sprite, igual que hace el
# fondo del menu. Cambiar la resolucion del motor con resize_screen NO vale: la
# ventana no se reajusta y el dibujo se queda en una esquina.
#
# Sustituye a Scene_Intro (el splash del Dragonite) sin tocar nada mas.
#===============================================================================
module OstinatoArranque
  ANCHO = 1920             # el arte esta hecho a esta medida
  ALTO  = 1080

  INTRO_DIR   = "Graphics/Titles/OstinatoIntro/"
  INTRO_COUNT = 160
  INTRO_FPS   = 20

  PORTADA = "Graphics/Titles/OstinatoPortada.jpg"

  STING   = "OstinatoLogo"          # el golpe de logo, justo los 8 s del video

  BOTON   = "Graphics/Titles/OstinatoPulsa.png"
  BOTON_X = 1380
  BOTON_Y = 766

  DIG_DIR    = "Graphics/Titles/OstinatoDiglett/"
  DIG_COUNT  = 425
  DIG_FPS    = 24
  DIG_X      = 309
  DIG_Y      = 898
  DIG_ESPERA = 15          # segundos de quietud antes de que asome el Diglett

  def self.gw
    begin; return Graphics.width; rescue; return 682; end
  end

  def self.gh
    begin; return Graphics.height; rescue; return 384; end
  end

  # cuanto hay que encoger el arte de 1920 para la pantalla real del motor
  def self.esc
    return gw.to_f / ANCHO.to_f
  end

  def self.fps
    r = 40
    begin; r = Graphics.frame_rate; rescue; r = 40; end
    r = 40 if !r || r <= 0
    return r
  end

  def self.bmp(path)
    begin
      return Bitmap.new(path)
    rescue
      return nil
    end
  end

  def self.swap(sprite, nueva)
    return if !nueva
    vieja = sprite.bitmap
    sprite.bitmap = nueva
    vieja.dispose if vieja && !vieja.disposed?
  end

  def self.soltar(sprite)
    return if !sprite || sprite.disposed?
    b = sprite.bitmap
    sprite.dispose
    b.dispose if b && !b.disposed?
  end

  #-----------------------------------------------------------------------------
  # Durante el video suena el golpe de logo. El tema del menu no arranca hasta
  # que se acaban los 8 s y aparece la portada.
  def self.sting
    begin
      pbBGMPlay(STING)
    rescue
    end
  end

  def self.musica_menu
    begin
      d = pbLoadRxData("Data/System")
      pbBGMPlay(d.title_bgm) if d && d.title_bgm
    rescue
    end
  end

  #-----------------------------------------------------------------------------
  def self.intro(viewport)
    sp = Sprite.new(viewport)
    sp.z = 10
    f = fps
    total = (INTRO_COUNT * f) / INTRO_FPS
    total = 1 if total < 1
    ultimo = -1
    k = 0
    while k < total
      i = (k * INTRO_FPS) / f
      i = INTRO_COUNT - 1 if i >= INTRO_COUNT
      if i != ultimo
        nb = bmp(sprintf("%st%03d.jpg", INTRO_DIR, i))
        if nb
          swap(sp, nb)
          sp.zoom_x = gw.to_f / nb.width
          sp.zoom_y = gh.to_f / nb.height
          sp.x = 0
          sp.y = 0
        end
        ultimo = i
      end
      Graphics.update
      Input.update
      break if Input.trigger?(Input::C) || Input.trigger?(Input::B)
      k += 1
    end
    # se funde a negro para entrar en la portada
    o = 255
    while o > 0
      o -= 32
      o = 0 if o < 0
      sp.opacity = o
      Graphics.update
      Input.update
    end
    soltar(sp)
  end

  #-----------------------------------------------------------------------------
  # Devuelve :borrar si se pide la pantalla de borrado, :ok en cualquier otro caso
  def self.portada(viewport)
    e = esc

    fondo = Sprite.new(viewport)
    fondo.z = 10
    fondo.opacity = 0
    fb = bmp(PORTADA)
    if fb
      fondo.bitmap = fb
      fondo.zoom_x = gw.to_f / fb.width
      fondo.zoom_y = gh.to_f / fb.height
    end

    dig = Sprite.new(viewport)
    dig.z = 11
    dig.x = (DIG_X * e).to_i
    dig.y = (DIG_Y * e).to_i
    dig.zoom_x = e
    dig.zoom_y = e
    dig.visible = false

    boton = Sprite.new(viewport)
    boton.z = 12
    boton.opacity = 0
    bb = bmp(BOTON)
    if bb
      boton.bitmap = bb
      boton.ox = bb.width / 2
      boton.oy = bb.height / 2
      boton.x = ((BOTON_X + bb.width / 2) * e).to_i
      boton.y = ((BOTON_Y + bb.height / 2) * e).to_i
    end

    f = fps
    o = 0
    while o < 255
      o += 17
      o = 255 if o > 255
      fondo.opacity = o
      Graphics.update
      Input.update
    end

    espera = DIG_ESPERA * f
    t = 0
    digt = -1
    diglast = -1
    salida = :ok
    loop do
      Graphics.update
      Input.update

      if Input.trigger?(Input::C)
        salida = :ok
        break
      end
      if Input.press?(Input::DOWN) && Input.press?(Input::B) && Input.press?(Input::CTRL)
        salida = :borrar
        break
      end

      # el boton respira, con un latido mas marcado encima
      if bb
        ph = (t % (f * 2)).to_f / (f * 2).to_f
        v = (Math.sin(ph * 2.0 * Math::PI * 2.0) + 1.0) / 2.0
        boton.opacity = (140 + 115 * v).to_i
        boton.zoom_x = e * (1.0 + 0.035 * v)
        boton.zoom_y = boton.zoom_x
      end

      # a los 15 s de quietud asoma el Diglett; al acabar, vuelta a contar
      if digt < 0
        digt = 0 if t >= espera
      else
        i = (digt * DIG_FPS) / f
        if i >= DIG_COUNT
          digt = -1
          diglast = -1
          t = 0
          dig.visible = false
          vieja = dig.bitmap
          dig.bitmap = nil
          vieja.dispose if vieja && !vieja.disposed?
        else
          if i != diglast
            nb = bmp(sprintf("%sd%03d.png", DIG_DIR, i))
            if nb
              swap(dig, nb)
              dig.visible = true
            end
            diglast = i
          end
          digt += 1
        end
      end

      t += 1
    end

    begin
      cry = pbCryFile(1 + rand(PBSpecies.maxValue))
      pbSEPlay(cry, 80, 100) if cry
    rescue
    end

    o = 255
    while o > 0
      o -= 17
      o = 0 if o < 0
      fondo.opacity = o
      boton.opacity = o if bb
      dig.opacity = o
      Graphics.update
      Input.update
    end

    soltar(boton)
    soltar(dig)
    soltar(fondo)
    return salida
  end

  #-----------------------------------------------------------------------------
  def self.run
    viewport = Viewport.new(0, 0, gw, gh)
    viewport.z = 99999
    salida = :ok
    begin
      sting
      intro(viewport)
      musica_menu
      salida = portada(viewport)
    ensure
      viewport.dispose
    end
    return salida
  end
end

#===============================================================================
class Scene_Intro
  def initialize(pics, splash = nil)
    @pics = pics
    @splash = splash
    begin
      $pkmn_animations = load_data("Data/PkmnAnimations.rxdata") if !$pkmn_animations
    rescue
    end
  end

  def main
    Graphics.transition(0)
    salida = OstinatoArranque.run
    sscene = PokemonLoadScene.new
    sscreen = PokemonLoad.new(sscene)
    if salida == :borrar
      sscreen.pbStartDeleteScreen
    else
      sscreen.pbStartLoadScreen
    end
    Graphics.freeze
  end
end
