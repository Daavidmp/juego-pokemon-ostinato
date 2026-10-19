#===============================================================================
# Pokemon Ostinato - La megaevolucion
#
#   Estilo anime, en dos partes (la v21 cambia la forma entre las dos):
#
#   "MegaEvolution"
#     1. corte a negro con un destello;
#     2. si megaevoluciona Kaia, su pantalla: Kaia en pixel art (una tira de 6
#        cuadros, como los sprites del juego) coge el colgante con la piedra
#        activadora, se concentra mientras brilla (destellos alrededor de la
#        piedra) y lo alza; la piedra estalla en luz y todo se queda en blanco;
#        si es de un rival: sobre el combate tal cual, una linea fina cruza la
#        pantalla, se abre en franja con el entrenador dentro (entra por la
#        derecha y frena en el centro) y se vuelve a cerrar;
#     3. queda el combate, oscurecido y acercandose; la megapiedra (el icono del objeto) cae desde arriba, se agrieta y
#        se rompe en trozos que envuelven al Pokemon en espiral;
#     4. el Pokemon se pone blanco, un brillo lo tapa y todo se queda blanco.
#   "MegaEvolution2" (ya con la forma nueva)
#     5. sale el Pokemon megaevolucionado con anillos, chispas y temblor;
#     6. el simbolo de Pokemon Anil aparece encima de su cabeza, como alli
#        (quieto, fundiendose), y la escena se funde con el combate.
#
#   Todo va en un viewport propio encima del combate y por fotogramas (60 por
#   segundo). Con ACCION se salta. Piezas en Graphics/Animations/Mega/ (las
#   saca recursos/herramientas/mega_piezas.cs; el simbolo es el de Pokemon Anil,
#   el "icon" del Deluxe Battle Kit de Lucidious89: ver CREDITOS.md). Las piezas en pixel art se amplian sin suavizar.
#===============================================================================
module OstMega
  DIR = "Graphics/Animations/Mega/"
  ZOOM_POKE = 3
  ZOOM_PIEDRA = 6
  ZOOM_SIMBOLO = 4
  # la pantalla de Kaia: su tira (kaia_mega, 6 cuadros; la hoja de Firefly con su colgante, x2 y con el
  # recorte suave: colgante_firefly.cs y kaia_suave.cs), a tamano real con los pies abajo
  ESCALA_TIRA = 2                 # la tira es la hoja de Firefly x2
  KAIA_CUADRO = [916, 768]
  KAIA_X = 502                    # (1920 - 916) / 2
  KAIA_Y = 316                    # 1080 - 768, y 4 px mas abajo para que nunca quede hueco bajo ella
  CUADROS_KAIA = [34, 8, 10, 30, 6, 999]  # fotogramas de cada cuadro (el primero, con la entrada)
  # el centro de la gema del colgante en cada cuadro (en la hoja de Firefly ya alineada; lo dice colgante_firefly.cs)
  COLGANTE = [[201, 289], [211, 288], [198, 266], [201, 313], [346, 123], [341, 95]]
  FRANJA = 320                    # alto de la franja del rival
  TROZOS = 10

  def self.bmp(nombre)
    @bmps ||= {}
    b = @bmps[nombre]
    return b if b && !b.disposed?
    @bmps[nombre] = Bitmap.new(DIR + nombre)
  end

  def self.listo?
    return pbResolveBitmap(DIR + "simbolo") && pbResolveBitmap(DIR + "brillo")
  end

  def self.se(nombre, vol = 90)
    pbSEPlay(nombre, vol) if pbResolveAudioSE(nombre)
  rescue
  end

  # 0..1 dentro de un tramo [ini, ini + dur]
  def self.t(f, ini, dur)
    return 0.0 if f <= ini
    return 1.0 if dur <= 0 || f >= ini + dur
    return (f - ini) / dur.to_f
  end

  def self.sale(t); 1 - (1 - t)**3; end                     # rapido y frena
  def self.entra(t); t * t; end                             # despacio y acelera
  def self.rebota(t)                                        # se pasa un poco y vuelve
    s = 1.7
    t -= 1
    return t * t * ((s + 1) * t + s) + 1
  end

  # primera fila con dibujo
  def self.arriba(bm, rect)
    (rect.y...rect.y + rect.height).each do |y|
      return y - rect.y if (rect.x...rect.x + rect.width).step(2).any? { |x| bm.get_pixel(x, y).alpha > 40 }
    end
    return 0
  end

  #-----------------------------------------------------------------------------
  class Escena
    def initialize(escena, battler)
      @escena = escena
      @battle = escena.instance_variable_get(:@battle)
      @battler = battler
      @sprites = escena.instance_variable_get(:@sprites)
      @pkmn = battler.pokemon
      @propio = @battle.pbOwnedByPlayer?(battler.index) rescue false
      base = escena.instance_variable_get(:@viewport)
      r = base ? base.rect : Rect.new(0, 0, Graphics.width, Graphics.height)
      @vp = Viewport.new(r.x, r.y, r.width, r.height)
      @vp.z = (base ? base.z : 99_999) + 1000   # por encima de todo el combate
      @w = @vp.rect.width
      @h = @vp.rect.height
      @todo = []
      @propios = []                              # bitmaps hechos aqui (se liberan al acabar)
    end

    def sprite(bm, z, x = 0, y = 0, centro = true)
      s = Sprite.new(@vp)
      s.bitmap = bm
      if centro && bm
        s.ox = bm.width / 2
        s.oy = bm.height / 2
      end
      s.x = x; s.y = y; s.z = z
      @todo.push(s)
      s
    end

    def liso(color)
      b = Bitmap.new(8, 8)
      b.fill_rect(0, 0, 8, 8, color)
      @propios.push(b)
      b
    end

    def tapa(z, color)
      s = sprite(liso(color), z, -20, -20, false)
      s.zoom_x = (@w / 8.0).ceil + 6
      s.zoom_y = (@h / 8.0).ceil + 6
      s
    end

    def cargar(f)
      return nil if !f || !pbResolveBitmap(f)
      b = Bitmap.new(f)
      @propios.push(b)
      b
    end

    # el sprite de frente; si es una tira animada, el primer cuadro
    def frente(form)
      f = GameData::Species.front_sprite_filename(@pkmn.species, form, @pkmn.gender, @pkmn.shiny?, @pkmn.shadowPokemon?) rescue nil
      b = cargar(f)
      return nil if !b
      lado = (b.width > b.height) ? b.height : b.width
      return [b, Rect.new(0, 0, lado, b.height)]
    end

    def entrenador_bmp
      tr = @battle.pbGetOwnerFromBattlerIndex(@battler.index) rescue nil
      return nil if !tr
      cargar(GameData::TrainerType.front_sprite_filename(tr.trainer_type)) rescue nil
    end

    def poke_sprite(dibujo, z)
      bm, rect = dibujo
      s = sprite(bm, z, @cx, @pies, false)
      s.src_rect = rect.clone
      s.ox = rect.width / 2
      s.oy = rect.height
      s.zoom_x = s.zoom_y = ZOOM_POKE
      s
    end

    def tick
      Graphics.update
      Input.update
    end

    #===========================================================================
    # Parte 1: corte, piedra y espiral (hasta quedarse en blanco)
    #===========================================================================
    def parte1
      @cx = @w / 2
      @pies = @h / 2 + 250
      viejo = frente(@pkmn.form) || frente(0)
      @alto = viejo ? (viejo[1].height - OstMega.arriba(viejo[0], viejo[1])) : 64
      @cabeza = @pies - @alto * ZOOM_POKE
      @centro = @pies - @alto * ZOOM_POKE / 2
      # --- el combate copiado (debajo de todo): fondo y Pokemon
      negro = tapa(0, Color.new(0, 0, 0))
      bg = @sprites["battle_bg"]
      @fondo = nil
      if bg && bg.bitmap && !bg.bitmap.disposed?
        b = bg.bitmap
        @fondo = sprite(b, 1, 0, 0)
        @bgz = bg.zoom_x
        @bgc = [bg.x - bg.ox * bg.zoom_x + b.width * bg.zoom_x / 2.0, bg.y - bg.oy * bg.zoom_y + b.height * bg.zoom_y / 2.0]
        @fondo.x = @bgc[0]; @fondo.y = @bgc[1]
        @fondo.zoom_x = @fondo.zoom_y = @bgz
      end
      poke = viejo ? poke_sprite(viejo, 5) : nil
      poke.visible = false if poke
      @fondo.visible = false if @fondo
      blanco = tapa(30, Color.new(255, 255, 255))
      blanco.opacity = 0
      cine = tapa(31, Color.new(0, 0, 0))
      cine.opacity = 0
      # --- la pantalla de Kaia (solo cuando megaevoluciona ella)
      kaia = nil
      if @propio && pbResolveBitmap(DIR + "kaia_mega")
        kaia = sprite(OstMega.bmp("kaia_mega"), 12, KAIA_X, KAIA_Y, false)
        kaia.src_rect = Rect.new(0, 0, KAIA_CUADRO[0], KAIA_CUADRO[1])
        # la luz del colgante: halo grande y estrella que gira (sumando luz), brillo y destello encima
        khalo = sprite(OstMega.bmp("brillo"), 13, 0, 0)
        khalo.blend_type = 1
        kestrella = sprite(OstMega.bmp("estrella"), 13, 0, 0)
        kestrella.blend_type = 1
        kbrillo = sprite(OstMega.bmp("brillo"), 14, 0, 0)
        kdestello = sprite(OstMega.bmp("destello"), 15, 0, 0)
        kcorona = (0...6).map { sprite(OstMega.bmp("destello"), 15, 0, 0) }
        kchispas = (0...12).map do |i|
          s = sprite(OstMega.bmp("chispa"), 15, 0, 0)
          s.zoom_x = s.zoom_y = 3 + (i % 3)
          [s, 200 + (i * 137) % 1520, (i * 53) % 90]
        end
        kpantalla = [kaia, khalo, kestrella, kbrillo, kdestello] + kcorona + kchispas.map { |s, _, _| s }
        kpantalla.each { |s| s.visible = false }
      end
      # --- la franja del rival (cuando megaevoluciona el Pokemon de un entrenador rival)
      rival = nil
      if !kaia && !(@battler.wild? rescue false) && (tb = entrenador_bmp)
        @vb = Viewport.new(@vp.rect.x, @vp.rect.y + @h / 2, @w, 1)
        @vb.z = @vp.z + 1
        @vb.visible = false
        fb = Bitmap.new(@w, FRANJA)
        FRANJA.times { |y| d = (y - FRANJA / 2).abs * 2.0 / FRANJA; v = (d * 4).floor
          fb.fill_rect(0, y, @w, 1, Color.new(70 - v * 12, 14, 40 - v * 6)) }   # a bandas, mas claro en medio
        @propios.push(fb)
        rfondo = Sprite.new(@vb); rfondo.bitmap = fb
        rlineas = (0...16).map do |i|
          s = Sprite.new(@vb); s.bitmap = liso(Color.new(255, 255, 255))
          s.zoom_x = (30 + (i * 37) % 60); s.zoom_y = 0.5 + (i % 3) * 0.25
          s.opacity = 90 + (i * 29) % 110
          [s, (i * 211) % (@w + 600), 12 + (i * 83) % (FRANJA - 24), 40 + (i * 13) % 30]
        end
        # el entrenador, de cintura para arriba: lo dibujado (sin el margen vacio de la picture) se amplia para que
        # la franja se llene con el 45 % de arriba (a zoom entero si pasa de 1, como los sprites del juego)
        arriba = OstMega.arriba(tb, tb.rect)
        abajo = tb.height - 1
        abajo -= 1 while abajo > arriba && (0...tb.width).step(2).none? { |x| tb.get_pixel(x, abajo).alpha > 40 }
        zt = (FRANJA - 20) / ((abajo - arriba + 1) * 0.45)
        zt = zt.round if zt > 1
        rtr = Sprite.new(@vb); rtr.bitmap = tb
        # centrado por lo dibujado (la picture puede tener mas margen a un lado)
        cols = (0...tb.width).select { |x| (arriba..abajo).step(3).any? { |y| tb.get_pixel(x, y).alpha > 40 } }
        rtr.ox = cols.empty? ? tb.width / 2 : (cols.first + cols.last) / 2
        rtr.oy = arriba
        rtr.zoom_x = rtr.zoom_y = zt
        rtr.y = 16
        bordes = [0, 1].map do |i|
          s = sprite(liso(Color.new(255, 255, 255)), 29, 0, 0, false)
          s.zoom_x = @w / 8.0 + 1; s.zoom_y = 0.75
          s.visible = false
          s
        end
        rival = { tr: rtr, lineas: rlineas, bordes: bordes, x: @w / 2, ancho: tb.width * zt }
        @todo.push(rfondo, rtr, *rlineas.map { |s, _, _, _| s })
      end
      negro.visible = false if rival                     # la franja sale sobre el combate, sin pasar a negro
      # --- la piedra y sus trozos
      piedra = nil
      if (it = (@battler.item_id rescue nil)) && (GameData::Item.get(it).is_mega_stone? rescue false)
        piedra = preparar_piedra(cargar(GameData::Item.icon_filename(it)))
      end
      if piedra
        pz = ZOOM_PIEDRA
        pi = sprite(piedra[:bm], 20, @cx, -100)
        pi.zoom_x = pi.zoom_y = pz
        pi.visible = false
        estela = (1..3).map do |i|
          s = sprite(piedra[:bm], 19, @cx, -100)
          s.zoom_x = s.zoom_y = pz
          s.color = Color.new(255, 170, 225, 200)
          s.opacity = 150 - i * 40
          s.visible = false
          s
        end
        grietas = piedra[:grietas].map do |gb|
          s = sprite(gb, 21, @cx, -100)
          s.zoom_x = s.zoom_y = pz
          s.visible = false
          s
        end
        trozos = piedra[:trozos].each_with_index.map do |(tb, dx, dy), i|
          s = sprite(tb, 20, @cx, -100)
          s.zoom_x = s.zoom_y = pz
          s.visible = false
          colas = (1..3).map do |j|
            c = sprite(tb, 19, 0, 0)
            c.zoom_x = c.zoom_y = pz - j
            c.color = Color.new(255, 150, 215, 190)
            c.opacity = 160 - j * 45
            c.visible = false
            c
          end
          { s: s, dx: dx * pz, dy: dy * pz, fase: i * 2 * Math::PI / piedra[:trozos].length,
            incl: (i.even? ? 1 : -1) * (0.15 + 0.1 * (i % 3)), colas: colas, hist: [] }
        end
      end
      flotar = @cabeza - 110
      gran_brillo = sprite(OstMega.bmp("brillo"), 22, @cx, @centro)
      gran_brillo.zoom_x = gran_brillo.zoom_y = 0
      gran_brillo.visible = false

      # --- tiempos (fotogramas)
      corte_f = 0; izq_f = 10
      kaia_d = 128                                  # la pantalla de Kaia
      rival_d = 80                                  # la franja del rival
      rompe_f = kaia ? izq_f + kaia_d : rival ? izq_f + rival_d : 12; cae_f = rompe_f + 22; posa_f = cae_f + 20; grieta_f = posa_f + 16; parte_f = grieta_f + 22; espiral_f = parte_f + 12
      espiral_d = 72; blanco_f = espiral_f + espiral_d - 12; fin = blanco_f + 14
      f = 0
      while f <= fin
        if f > 4 && Input.trigger?(Input::ACTION)
          blanco.opacity = 255
          break
        end
        # 1. corte a negro y destello
        cine.opacity = 255 * OstMega.t(f, corte_f, 6) if f < izq_f && !rival
        if f == 6 && !rival
          OstMega.se("Anim/Flash2")
          blanco.opacity = 220
        end
        blanco.opacity = 220 * (1 - OstMega.t(f, 6, 10)) if f > 6 && f < rompe_f
        cine.opacity = 0 if f == izq_f
        # 2. Kaia y su colgante (una tira de cuadros, como los sprites del juego), sobre el fondo del combate
        if kaia && f >= izq_f && f < rompe_f
          k = f - izq_f
          if k == 0
            kaia.visible = true
            OstMega.se("Anim/PRSFX- Air Slash1")
            @fondo.visible = true if @fondo
          end
          if @fondo
            o = -110 * OstMega.t(k, 0, 10)
            @fondo.tone = Tone.new(o, o, o * 0.5)
          end
          c = 0
          acum = 0
          CUADROS_KAIA.each_with_index do |d, i|
            acum += d
            c = i
            break if k < acum
          end
          kaia.src_rect.x = c * KAIA_CUADRO[0]
          sube = 200 * (1 - OstMega.sale(OstMega.t(k, 0, 10)))
          kaia.y = KAIA_Y + sube
          gx = KAIA_X + COLGANTE[c][0] * ESCALA_TIRA
          gy = kaia.y + COLGANTE[c][1] * ESCALA_TIRA
          # al activarse (cierra los ojos): destello, y la luz crece; al alzarlo, late fuerte
          activa = 52
          if k == activa
            OstMega.se("Anim/PRSFX- Psych Up")
            blanco.opacity = 150
          end
          blanco.opacity = 150 * (1 - OstMega.t(k, activa, 10)) if k > activa && k < 108
          OstMega.se("Anim/PRSFX- Heal Bell") if k == 88
          if c >= 2
            kbrillo.visible = true
            kbrillo.x = gx; kbrillo.y = gy
            base = (c == 2) ? 1 : (c == 3) ? 2 + OstMega.t(k, activa, 30) : 3
            kbrillo.zoom_x = kbrillo.zoom_y = [(base + Math.sin(k / 3.0) * 0.5).round, 1].max
          end
          if k >= activa
            fuerza = (c >= 4) ? 1.0 : 0.55 + 0.45 * OstMega.t(k, activa, 30)
            late = Math.sin(k / 3.0)
            khalo.visible = true
            khalo.x = gx; khalo.y = gy
            khalo.zoom_x = khalo.zoom_y = (5 * fuerza + late * 0.7).round
            khalo.opacity = 120 + 30 * late
            kestrella.visible = true
            kestrella.x = gx; kestrella.y = gy
            kestrella.angle = (k * 3) % 360
            kestrella.zoom_x = kestrella.zoom_y = (6 * fuerza + late).round
            kestrella.opacity = 220
          end
          if c >= 4
            kdestello.visible = true
            kdestello.x = gx; kdestello.y = gy
            kdestello.zoom_x = kdestello.zoom_y = (7 + Math.sin(k / 2.0) * 2).round
          end
          # chispas que suben mientras se concentra
          kchispas.each do |s, x0, d0|
            s.visible = k >= activa
            s.x = x0
            s.y = @h - ((k - activa) * 9 + d0 * 12) % (@h + 60)
          end
          # destellos que rodean la piedra, girando despacio y titilando cada uno a su ritmo
          if k >= activa
            n = kcorona.length
            kcorona.each_with_index do |s, i|
              a = i * 2 * Math::PI / n + k * 0.035
              r = ((c >= 4) ? 95 : 75) + Math.sin(k / 5.0 + i) * 8
              s.visible = true
              s.x = gx + Math.cos(a) * r
              s.y = gy + Math.sin(a) * r
              s.zoom_x = s.zoom_y = [(Math.sin(k / 4.0 + i * 1.7) * 3 + 3).round, 0].max
            end
          end
          # al final la piedra estalla en luz y todo se queda en blanco
          if k >= 108
            OstMega.se("Anim/PRSFX- Charge Beam") if k == 108
            tb = OstMega.t(k, 108, 14)
            khalo.zoom_x = khalo.zoom_y = (5 + 40 * tb * tb).round
            khalo.opacity = 160 + 95 * tb
            blanco.opacity = 255 * OstMega.t(k, 114, 12)
          end
        end
        if kaia && f == rompe_f
          kpantalla.each { |s| s.visible = false }
        end
        # 2b. el rival: una linea fina que se abre en franja, con el entrenador dentro, y se vuelve a cerrar
        if rival && f >= izq_f && f < rompe_f
          k = f - izq_f
          OstMega.se("Anim/PRSFX- Air Slash1") if k == 0          # sobre el combate tal cual, con todos los Pokemon
          # alto de la franja: linea (0-8), se abre (8-20), se queda, se cierra (66-76)
          alto = if k < 8 then 2 + 4 * OstMega.t(k, 0, 8)
                 elsif k < 66 then 6 + (FRANJA - 6) * OstMega.sale(OstMega.t(k, 8, 12))
                 else (FRANJA - 6) * (1 - OstMega.entra(OstMega.t(k, 66, 10)))
                 end
          alto = alto.round
          @vb.visible = alto > 1
          @vb.rect = Rect.new(@vp.rect.x, @vp.rect.y + @h / 2 - alto / 2, @w, [alto, 1].max)
          @vb.oy = -(alto / 2 - FRANJA / 2)                              # el contenido va centrado en la franja
          rival[:bordes].each_with_index do |s, i|
            s.visible = alto > 1
            s.y = @h / 2 + (i == 0 ? -alto / 2 - 6 : alto / 2)
          end
          # el entrenador entra por la derecha y frena en el centro
          OstMega.se("Anim/PRSFX- Air Slash2") if k == 12
          te = OstMega.sale(OstMega.t(k, 12, 14))
          rival[:tr].x = rival[:x] + (@w - rival[:x] + rival[:ancho]) * (1 - te)
          if k == 34
            OstMega.se("Anim/PRSFX- Psych Up")
          end
          rival[:tr].color = Color.new(255, 255, 255, 200 * (1 - OstMega.t(k, 34, 10))) if k >= 34
          # lineas de velocidad que cruzan la franja
          rival[:lineas].each do |s, x0, y0, v|
            s.x = @w - ((x0 + k * v) % (@w + 600))
            s.y = y0
          end
          blanco.opacity = 255 * OstMega.t(k, 72, 6) if k >= 72
        end
        if rival && f == rompe_f
          @vb.visible = false
          rival[:bordes].each { |s| s.visible = false }
        end
        # 2. queda el combate (oscurecido y acercandose)
        if f == rompe_f
          blanco.opacity = 255
          negro.visible = false
          poke.visible = true if poke
          @fondo.visible = true if @fondo
        end
        if f >= rompe_f
          blanco.opacity = 255 * (1 - OstMega.t(f, rompe_f, 12)) if f < blanco_f
          tz = OstMega.sale(OstMega.t(f, rompe_f, fin - rompe_f))
          oscuro = -140 * OstMega.t(f, rompe_f, 30)
          if @fondo
            @fondo.zoom_x = @fondo.zoom_y = @bgz * (1 + 0.12 * tz)
            @fondo.y = @bgc[1] + 60 * tz
            @fondo.tone = Tone.new(oscuro, oscuro, oscuro * 0.6)
          end
        end
        # 3. la piedra cae, se posa, se agrieta y se rompe
        if piedra
          if f >= cae_f && f < parte_f
            pi.visible = true
            OstMega.se("Anim/PRSFX- Power Gem1") if f == cae_f
            tc = OstMega.rebota(OstMega.t(f, cae_f, posa_f - cae_f))
            y = -100 + (flotar + 100) * tc
            y += Math.sin((f - posa_f) / 5.0) * 6 if f >= posa_f
            sacude = (f >= grieta_f) ? ((f % 4 < 2) ? 3 : -3) * (1 + OstMega.t(f, grieta_f, parte_f - grieta_f)) : 0
            pi.x = @cx + sacude
            pi.y = y
            @hist_p = ([[pi.x, pi.y]] + (@hist_p || []))[0, 7]
            estela.each_with_index do |s, i|
              h = @hist_p[(i + 1) * 2]
              s.visible = !!(f < posa_f + 4 && h)
              s.x, s.y = h if h
            end
            if f == posa_f
              OstMega.se("Anim/PRSFX- Heal Order1")
            end
            pi.color = Color.new(255, 255, 255, 220 * (1 - OstMega.t(f, posa_f, 12))) if f >= posa_f
            grietas.each_with_index do |s, i|
              ini = grieta_f + i * 10
              OstMega.se("Anim/Ice5", 70) if f == ini
              s.visible = f >= ini
              s.x = pi.x; s.y = pi.y
            end
          end
          if f == parte_f
            OstMega.se("Anim/PRSFX- Ice Shard")
            pi.visible = false
            estela.each { |s| s.visible = false }
            grietas.each { |s| s.visible = false }
          end
          if f >= parte_f
            trozos.each_with_index do |tz2, i|
              s = tz2[:s]
              s.visible = true
              x0 = @cx + tz2[:dx]
              y0 = flotar + tz2[:dy]
              if f < espiral_f
                # saltan hacia fuera
                te = OstMega.sale(OstMega.t(f, parte_f, espiral_f - parte_f))
                a = tz2[:fase]
                s.x = x0 + (@cx + Math.cos(a) * 300 - x0) * te
                s.y = y0 + (@centro + Math.sin(a) * 300 * 0.35 - y0) * te
                s.z = 20
              else
                ts = OstMega.t(f, espiral_f, espiral_d)
                a = tz2[:fase] + 2 * Math::PI * (1.2 * ts + 2.8 * ts * ts)
                r = 300 * (1 - ts)**0.8 + 20
                s.x = @cx + Math.cos(a) * r
                s.y = @centro + Math.sin(a) * r * 0.35 + Math.cos(a) * r * tz2[:incl]
                s.z = (Math.sin(a) > 0) ? 20 : 3
                z = ZOOM_PIEDRA - 3 * ts
                s.zoom_x = s.zoom_y = z.round
                s.opacity = 255 * (1 - OstMega.t(f, espiral_f + espiral_d - 10, 10))
              end
              tz2[:hist] = ([[s.x, s.y, s.z]] + tz2[:hist])[0, 7]
              tz2[:colas].each_with_index do |c, j|
                h = tz2[:hist][(j + 1) * 2]
                c.visible = !h.nil? && f >= espiral_f
                if h
                  c.x, c.y = h[0], h[1]
                  c.z = h[2] - 1
                  c.zoom_x = c.zoom_y = [s.zoom_x - j - 1, 1].max
                  c.opacity = (160 - j * 45) * (s.opacity / 255.0)
                end
              end
            end
            OstMega.se("Anim/PRSFX- Cosmic Power") if f == espiral_f
          end
        end
        # 4. el Pokemon se pone blanco y un brillo lo tapa
        if poke && f >= espiral_f
          poke.color = Color.new(255, 255, 255, 255 * OstMega.t(f, espiral_f, espiral_d - 16))
        end
        if f >= espiral_f + espiral_d - 30
          gran_brillo.visible = true
          tb = OstMega.sale(OstMega.t(f, espiral_f + espiral_d - 30, 26))
          gran_brillo.zoom_x = gran_brillo.zoom_y = ((@alto * ZOOM_POKE * 1.3 / 48.0) * tb).round
          gran_brillo.y = @centro
        end
        blanco.opacity = 255 * OstMega.t(f, blanco_f, 12) if f >= blanco_f
        tick
        f += 1
      end
      # se queda en blanco hasta MegaEvolution2; se guarda el fondo
      blanco.opacity = 255
      @blanco = blanco
      @todo.each { |s| s.dispose if s != blanco && s != @fondo && !s.disposed? }
      @todo = [blanco, @fondo].compact
    end

    # la piedra: recortada a lo que tiene dibujo, sus grietas (2 fases) y sus trozos
    def preparar_piedra(icono)
      return nil if !icono
      x0 = icono.width; y0 = icono.height; x1 = -1; y1 = -1
      icono.height.times do |y|
        icono.width.times do |x|
          next if icono.get_pixel(x, y).alpha < 30
          x0 = x if x < x0; x1 = x if x > x1; y0 = y if y < y0; y1 = y if y > y1
        end
      end
      return nil if x1 < 0
      w = x1 - x0 + 1; h = y1 - y0 + 1
      bm = Bitmap.new(w, h)
      bm.blt(0, 0, icono, Rect.new(x0, y0, w, h))
      @propios.push(bm)
      # trozos: celdas alrededor de semillas repartidas por la piedra
      srand(7)
      sem = (0...TROZOS).map do |i|
        a = i * 2 * Math::PI / TROZOS + rand * 0.4
        r = (i == 0) ? 0 : (0.25 + rand * 0.25)
        [w / 2.0 + Math.cos(a) * w * r, h / 2.0 + Math.sin(a) * h * r]
      end
      celda = Array.new(w * h, -1)
      h.times do |y|
        w.times do |x|
          next if bm.get_pixel(x, y).alpha < 30
          celda[y * w + x] = (0...sem.length).min_by { |i| (sem[i][0] - x)**2 + (sem[i][1] - y)**2 }
        end
      end
      blanco = Color.new(255, 255, 255)
      rosa = Color.new(255, 190, 235)
      g1 = Bitmap.new(w, h); g2 = Bitmap.new(w, h)
      @propios.push(g1, g2)
      h.times do |y|
        w.times do |x|
          c = celda[y * w + x]
          next if c < 0
          vec = [[1, 0], [0, 1]].any? do |dx, dy|
            xx = x + dx; yy = y + dy
            xx < w && yy < h && celda[yy * w + xx] >= 0 && celda[yy * w + xx] != c
          end
          next if !vec
          d = Math.sqrt((x - w / 2.0)**2 + (y - h / 2.0)**2) / (w / 2.0)
          g1.set_pixel(x, y, d < 0.55 ? blanco : rosa) if d < 0.6
          g2.set_pixel(x, y, (x + y).even? ? blanco : rosa)
        end
      end
      trozos = (0...sem.length).map do |i|
        tb = Bitmap.new(w, h)
        @propios.push(tb)
        cx = 0.0; cy = 0.0; n = 0
        h.times do |y|
          w.times do |x|
            next if celda[y * w + x] != i
            tb.set_pixel(x, y, bm.get_pixel(x, y))
            cx += x; cy += y; n += 1
          end
        end
        next nil if n == 0
        [tb, cx / n - w / 2.0, cy / n - h / 2.0]
      end.compact
      return { bm: bm, grietas: [g1, g2], trozos: trozos }
    end

    #===========================================================================
    # Parte 2: el Pokemon nuevo y el simbolo
    #===========================================================================
    def parte2
      nuevo = frente(@pkmn.form) || frente(0)
      if nuevo
        @alto = nuevo[1].height - OstMega.arriba(nuevo[0], nuevo[1])
        @cabeza = @pies - @alto * ZOOM_POKE
        @centro = @pies - @alto * ZOOM_POKE / 2
      end
      mega = nuevo ? poke_sprite(nuevo, 5) : nil
      mega.color = Color.new(255, 255, 255, 255) if mega
      blanco = @blanco
      anillos = (0...3).map do
        s = sprite(OstMega.bmp("anillo"), 6, @cx, @centro)
        s.visible = false
        s
      end
      chispas = (0...14).map do |i|
        s = sprite(OstMega.bmp("chispa"), 7, @cx, @centro)
        s.zoom_x = s.zoom_y = 4 + (i % 3)
        s.visible = false
        [s, i * 2 * Math::PI / 14 + (i % 2) * 0.2, 380 + (i % 4) * 90]
      end
      # el simbolo, como en Pokemon Anil: quieto sobre la cabeza (20 px por encima, apoyado por abajo)
      sim_bm = OstMega.bmp("simbolo")
      simbolo = sprite(sim_bm, 8, @cx, @cabeza - 20, false)
      simbolo.ox = sim_bm.width / 2
      simbolo.oy = sim_bm.height
      simbolo.zoom_x = simbolo.zoom_y = ZOOM_SIMBOLO
      simbolo.opacity = 0
      funde_f = 96; fin = funde_f + 18
      oscuro0 = @fondo ? @fondo.tone.red : 0
      g = 0
      while g <= fin
        if g > 2 && g < funde_f && Input.trigger?(Input::ACTION)
          g = funde_f
        end
        if g == 0
          OstMega.se("Anim/PRSFX- Moonblast2")
        end
        if g == 2
          begin
            GameData::Species.play_cry_from_species(@pkmn.species, @pkmn.form)
          rescue
            GameData::Species.play_cry_from_pokemon(@pkmn) rescue nil
          end
        end
        blanco.opacity = 255 * (1 - OstMega.t(g, 0, 8)) if g < funde_f
        if @fondo
          o = oscuro0 + (-40 - oscuro0) * OstMega.t(g, 0, 20)
          @fondo.tone = Tone.new(o, o, o * 0.6) if g < funde_f
        end
        # 5. sale el nuevo: golpe de zoom, temblor, anillos y chispas
        if mega
          tz = OstMega.sale(OstMega.t(g, 0, 12))
          mega.zoom_x = mega.zoom_y = ZOOM_POKE * (1.15 - 0.15 * tz)
          mega.color = Color.new(255, 255, 255, 255 * (1 - OstMega.t(g, 6, 30))) if g < funde_f
        end
        if g < 20
          @vp.ox = ((g % 4 < 2) ? 1 : -1) * 10 * (1 - g / 20.0)
          @vp.oy = ((g % 6 < 3) ? 1 : -1) * 6 * (1 - g / 20.0)
        else
          @vp.ox = 0; @vp.oy = 0
        end
        anillos.each_with_index do |s, i|
          ta = OstMega.t(g, i * 5, 20)
          s.visible = g >= i * 5 && ta < 1
          s.zoom_x = s.zoom_y = (2 + 16 * OstMega.sale(ta)).round
          s.opacity = 255 * (1 - ta)
        end
        chispas.each do |s, a, r|
          tc = OstMega.t(g, 0, 26)
          s.visible = g < 26
          s.x = @cx + Math.cos(a) * r * OstMega.sale(tc)
          s.y = @centro + Math.sin(a) * r * 0.6 * OstMega.sale(tc)
          s.opacity = 255 * (1 - OstMega.t(g, 14, 12))
        end
        # 6. el simbolo aparece fundiendose, como en Anil (4 pasos del kit despues, durante 8: x3 a 60)
        simbolo.opacity = 255 * OstMega.t(g, 12, 24) if g < funde_f
        # y se funde con el combate (que ya tiene la forma nueva)
        if g >= funde_f
          op = 255 * (1 - OstMega.t(g, funde_f, fin - funde_f))
          @todo.each { |s| s.opacity = op if !s.disposed? && s != blanco }
          blanco.opacity = 0
        end
        tick
        g += 1
      end
      soltar
    end

    def soltar
      @todo.each { |s| s.dispose if !s.disposed? }
      @todo.clear
      @propios.each { |b| b.dispose if !b.disposed? }
      @propios.clear
      @vb.dispose if @vb && !@vb.disposed?
      @vp.dispose if @vp && !@vp.disposed?
    end
  end

  @actual = nil
  class << self
    attr_accessor :actual
  end
end

class Battle::Scene
  alias ostmega_pbCommonAnimation pbCommonAnimation
  def pbCommonAnimation(animName, user = nil, target = nil)
    if ["MegaEvolution", "MegaEvolution2"].include?(animName) && user && OstMega.listo?
      begin
        if animName == "MegaEvolution"
          OstMega.actual.soltar if OstMega.actual
          OstMega.actual = OstMega::Escena.new(self, user)
          OstMega.actual.parte1
        else
          a = OstMega.actual
          a.parte2 if a
          OstMega.actual = nil
        end
        return
      rescue StandardError => e
        echoln("OstMega: #{e.class}: #{e.message} #{e.backtrace[0]}") rescue nil
        (OstMega.actual.soltar rescue nil) if OstMega.actual
        OstMega.actual = nil
      end
    end
    ostmega_pbCommonAnimation(animName, user, target)
  end
end
