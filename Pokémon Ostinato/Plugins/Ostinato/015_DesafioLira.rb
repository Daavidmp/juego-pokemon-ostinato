#===============================================================================
# Pokemon Ostinato - "LIRA TE DESAFIA": la entrada al primer combate contra Lira
#
#   Como la del nuevo rival del Smash, en el estilo dibujado de los dialogos
#   (en el combate Lira sigue en pixel art):
#     1. la pantalla del mapa se raja y salta en pedazos;
#     2. cruza la franja roja con rayos: "UN RIVAL SE ACERCA";
#     3. corte a los ojos de Lira;
#     4. fondo de energia, estalla la tinta y entra su silueta a toda prisa;
#     5. destello: es Lira a color; cae el letrero "LIRA TE DESAFIA".
#   Va a 1920x1080 (OstinatoHD) y acaba en negro, que es como tiene que acabar
#   una animacion de entrada a combate. Usa OstMini (curvas, efectos, temblor).
#
#   Arte en Graphics/Titles/Desafio/ (sacado de Firefly con
#   Downloads/desafio_lira/proceso/procesar.py) y el letrero de siempre,
#   Graphics/Titles/DesafioTexto.png. Sonidos "Desafio ..." con repuesto.
#===============================================================================
module OstDesafio
  DIR = "Graphics/Titles/Desafio/"
  W = 1920
  H = 1080

  def self.animar(viewport)
    foto = nil
    begin
      foto = Graphics.snap_to_bitmap
    rescue
    end
    antes = OstinatoHD.subir
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 999_999
    sprites = []
    nuevo = proc do |bitmap, z|
      s = Sprite.new(vp)
      s.bitmap = bitmap
      s.z = z
      sprites.push(s)
      s
    end
    arte = proc do |nombre, z|
      s = nuevo.call(OstMini.bmp(DIR + nombre + ".png"), z)
      s.ox = s.bitmap.width / 2
      s.oy = s.bitmap.height / 2
      s.x = W / 2
      s.y = H / 2
      s.opacity = 0
      s
    end
    lleno = proc do |color, z|
      b = Bitmap.new(W, H)
      b.fill_rect(0, 0, W, H, color)
      nuevo.call(b, z)
    end
    begin
      OstMini.temblar(0)
      negro  = lleno.call(Color.new(0, 0, 0), 0)
      fondo  = arte.call("fondo", 1)
      tinta  = arte.call("tinta", 2)
      lineas = arte.call("lineas", 3)
      lineas.ox = 0                     # va repetida dos veces a lo ancho: se desplaza en bucle
      silueta = arte.call("silueta", 4)
      lira   = arte.call("lira", 4)
      [silueta, lira].each { |s| s.oy = s.bitmap.height; s.y = H + 20 }
      ojos   = arte.call("ojos", 6)
      franja = arte.call("franja", 7)
      rival  = arte.call("rival", 8)
      letrero = nuevo.call(OstMini.bmp("Graphics/Titles/DesafioTexto.png"), 9)
      letrero.ox = letrero.bitmap.width / 2
      letrero.oy = letrero.bitmap.height / 2
      letrero.x = W / 2
      letrero.y = H - 150
      letrero.opacity = 0
      grietas = arte.call("grietas", 11)
      grietas.blend_type = 1
      blanco = lleno.call(Color.new(255, 255, 255), 12)
      blanco.opacity = 0

      # la foto del mapa en 4x3 trozos, que luego salen volando
      trozos = []
      if foto
        e = W.to_f / foto.width
        tw = foto.width / 4
        th = foto.height / 3
        3.times do |j|
          4.times do |i|
            s = nuevo.call(foto, 10)
            s.src_rect = Rect.new(i * tw, j * th, tw, th)
            s.ox = tw / 2
            s.oy = th / 2
            s.zoom_x = s.zoom_y = e
            cx = (i + 0.5) * tw * e
            cy = (j + 0.5) * th * e
            s.x = cx.round
            s.y = cy.round
            dx = (cx - W / 2) / W
            dy = (cy - H / 2) / H
            trozos.push([s, cx, cy, dx * 70 + (rand - 0.5) * 10, dy * 70 - 8 - rand * 6, (rand - 0.5) * 14, e])
          end
        end
      end

      t = 0
      paso = proc do
        t += 1
        # lo que se mueve siempre: el fondo se acerca despacio y la tinta gira
        z = 1.0 + 0.03 * [t / 400.0, 1.0].min
        fondo.zoom_x = fondo.zoom_y = z
        tinta.angle = (tinta.angle + 0.08) % 360
        OstMini.temblor(vp)
        Graphics.update
        Input.update
      end

      # --- 1. el mapa se raja ----------------------------------------------------
      OstMini.se("Desafio cristal", "Vs flash", 100, 100)
      grietas.opacity = 255
      blanco.opacity = 200
      OstMini.temblar(16)
      14.times do |f|
        blanco.opacity = [blanco.opacity - 40, 0].max
        trozos.each { |q| q[0].x = (q[1] + (rand - 0.5) * 4).round }
        paso.call
      end
      # y salta en pedazos hacia la camara
      26.times do |f|
        u = (f + 1) / 26.0
        grietas.opacity = (255 * (1 - u * 2)).to_i
        trozos.each do |q|
          s, cx, cy, vx, vy, giro, e = q
          q[1] = cx + vx
          q[2] = cy + vy
          q[4] = vy + 1.6          # caen un poco
          s.x = q[1].round
          s.y = q[2].round
          s.angle += giro
          s.zoom_x = s.zoom_y = e * (1.0 + 0.6 * u)
          s.opacity = (255 * (1 - OstMini.entra(u))).to_i
        end
        paso.call
      end
      trozos.each { |q| q[0].visible = false }
      grietas.visible = false

      # --- 2. "UN RIVAL SE ACERCA" ------------------------------------------------
      OstMini.se("Desafio alarma", "Vs flash", 90, 130)
      lineas.opacity = 150
      64.times do |f|
        if f < 9
          x = W * 1.5 - W * OstMini.sale((f + 1) / 9.0)
        elsif f >= 56
          x = W / 2 - W * OstMini.entra((f - 55) / 8.0)
        else
          x = W / 2 - (f - 9) * 0.6           # casi quieta, un poco a la deriva
        end
        franja.x = x.round
        rival.x = (x + (f < 9 ? 160 * (1 - f / 9.0) : 0)).round
        franja.opacity = rival.opacity = 255
        franja.tone = ((f / 4) % 2 == 0) ? Tone.new(0, 0, 0) : Tone.new(70, 40, 30)   # los rayos chisporrotean
        lineas.x = -((t * 60) % W)
        paso.call
      end
      franja.visible = rival.visible = false
      lineas.opacity = 0

      # --- 3. los ojos -----------------------------------------------------------
      OstMini.se("Desafio golpe", "Vs sword", 90, 120)
      blanco.opacity = 150
      36.times do |f|
        ojos.opacity = (f < 30) ? 255 : (255 * (36 - f) / 6.0).to_i
        ojos.x = (W / 2 + 50 - f * 3).round
        blanco.opacity = [blanco.opacity - 30, 0].max
        paso.call
      end
      ojos.visible = false

      # --- 4. fondo, tinta y la silueta que entra deprisa ---------------------------
      OstMini.se("Desafio whoosh", nil, 90, 100)
      blanco.opacity = 160
      lineas.opacity = 220
      silueta.opacity = 255
      26.times do |f|
        u = (f + 1).to_f
        fondo.opacity = [fondo.opacity + 45, 255].min
        tinta.opacity = 255
        tz = 0.15 + 0.85 * OstMini.rebote(u / 14.0)
        tinta.zoom_x = tinta.zoom_y = tz
        tinta.y = H / 2 - 40
        e = OstMini.sale(u / 14.0)
        silueta.x = (W + 500 - (W / 2 + 500) * e).round
        silueta.zoom_x = 1.0 + 0.18 * (1 - e)          # estirada por la velocidad
        silueta.zoom_y = 1.0 - 0.05 * (1 - e)
        lineas.x = -((t * 90) % W)
        lineas.opacity = (f < 14) ? 220 : [lineas.opacity - 30, 0].max
        blanco.opacity = [blanco.opacity - 35, 0].max
        paso.call
      end

      # --- 5. destello: es Lira -------------------------------------------------------
      OstMini.se("Desafio destello", "Vs flash", 100, 90)
      blanco.opacity = 255
      silueta.visible = false
      lira.opacity = 255
      lira.x = silueta.x
      cayendo = -1
      100.times do |f|
        blanco.opacity = [blanco.opacity - 20, 0].max
        r = 1.0 - OstMini.sale((f + 1) / 16.0)
        lira.zoom_x = lira.zoom_y = 1.0 + 0.05 * r
        # el letrero cae de golpe
        if f >= 8 && f < 16
          cayendo = f - 8
          u = (cayendo + 1) / 8.0
          letrero.opacity = (255 * u).to_i
          letrero.zoom_x = letrero.zoom_y = 2.4 - 1.4 * OstMini.entra(u)
        end
        if f == 16
          OstMini.se("Desafio letrero", "Vs sword", 100, 100)
          OstMini.temblar(18)
          blanco.opacity = 110
          letrero.zoom_x = letrero.zoom_y = 1.0
        end
        letrero.tone = (f > 30 && (f / 8) % 2 == 1) ? Tone.new(60, 40, 40) : Tone.new(0, 0, 0)
        paso.call
      end

      # y todo a negro
      negro.z = 20
      negro.opacity = 0
      16.times { |f| negro.opacity = [(f + 1) * 16, 255].min; paso.call }
      viewport.color = Color.new(0, 0, 0, 255) if viewport
    ensure
      vp.ox = 0
      vp.oy = 0
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
