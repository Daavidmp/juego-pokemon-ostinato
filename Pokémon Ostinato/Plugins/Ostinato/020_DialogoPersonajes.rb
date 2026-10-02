#===============================================================================
# Pokemon Ostinato - Lo que dicen los personajes secundarios del mapa
#
#   Vecinos y entrenadores de ruta (OstinatoVecinos.hablar):
#     - el pergamino sale pegado al personaje que habla, como un bocadillo,
#       con un pico que llega hasta el: debajo de sus pies, o encima de su
#       cabeza si Kaia esta debajo (para no taparla);
#     - la frase llena el pergamino: los PNG salen de
#       recursos/herramientas/textos_ajustados.ps1 con la letra mas grande que
#       cabe (684x140, el hueco del papel menos la hojita);
#     - al acabar de hablar, el personaje vuelve a mirar a donde miraba antes
#       (aunque se le hable desde otro lado). Las escenas que lo mueven con una
#       ruta no se ven afectadas: la ruta anula la vuelta.
#
#   Medidas en la pantalla de 1920x1080, como las del cuadro (006_Prologo).
#===============================================================================
module Settings
  remove_const(:RESTORE_EVENT_DIRECTION) if const_defined?(:RESTORE_EVENT_DIRECTION)
  RESTORE_EVENT_DIRECTION = true
end

module OstDlg
  PNJ_Y       = 623
  PNJ_W       = 933
  PNJ_H       = 211
  PICO_LARGO  = 170        # el pico apunta al personaje; como mucho, tan largo
  PICO_MEDIO  = 24         # medio ancho del pico donde nace
  MARCO       = Color.new(146, 133, 115)
  FILO        = Color.new(40, 34, 28, 150)

  class << self
    alias ostpnj_bmp bmp
    def bmp(path)
      if path.to_s.end_with?("PNJ_CUADRO.png") && @pnj_bitmap && !@pnj_bitmap.disposed?
        return @pnj_bitmap.clone   # el cuadro suelta el anterior al cambiar
      end
      return ostpnj_bmp(path)
    end

    def gh_hd; return 1080; end

    # donde esta el personaje en la pantalla de 1920: [x, cabeza, pies]
    def pnj_sitio(ev)
      fx = ART_W / gw
      fy = 1080.0 / gh
      alto = 48
      begin
        b = RPG::Cache.character(ev.character_name, 0)
        alto = b.height / 4 if b && b.height > 0
      rescue
      end
      return [(ev.screen_x * fx).round, ((ev.screen_y - alto) * fy).round, (ev.screen_y * fy).round]
    end

    # Prepara el cuadro con su pico para este personaje. Devuelve false si no
    # se puede (y entonces se habla con el cuadro de siempre).
    def pnj_preparar(ev)
      return false if !ev || !ev.respond_to?(:screen_x) || ev.character_name.to_s == ""
      nx, cabeza, pies = pnj_sitio(ev)
      # El cuadro, pegado al personaje como un bocadillo: debajo de sus pies,
      # o encima de su cabeza si Kaia esta debajo (para no taparla) o si abajo
      # no cabe. "abajo" = el cuadro queda por debajo del personaje.
      encima = cabeza - 24 - PNJ_H
      debajo = pies + 16
      kaia_debajo = $game_player && $game_player.y > ev.y
      if kaia_debajo && encima >= 8
        abajo = false
      elsif debajo + PNJ_H <= gh_hd - 8
        abajo = true
      elsif encima >= 8
        abajo = false
      else
        abajo = true
        debajo = PNJ_Y
      end
      cy = abajo ? debajo : encima
      cx = [[nx - PNJ_W / 2, 10].max, ART_W - PNJ_W - 10].min
      caja = ostpnj_bmp(DIR + "DlgCuadroN.png")
      return false if !caja
      # El pico, como el del cuadro de Kaia: un triangulo liso del color del
      # marco que nace pegado a su borde (por detras, asi la linea del marco
      # sigue entera), encima o debajo del personaje sin llegar a las esquinas,
      # y llega hasta el.
      bx = abajo ? [[nx, cx + 150].max, cx + 600].min : [[nx, cx + 150].max, cx + 700].min
      borde = abajo ? cy + 22 : cy + PNJ_H - 16       # dentro de la linea del marco
      ty = abajo ? pies - 6 : cabeza + 6
      dx = nx - bx
      dy = ty - borde
      largo = Math.sqrt(dx * dx + dy * dy)
      largo = 1.0 if largo < 1
      usa = [[largo, PICO_LARGO].min, 40].max
      ux = dx / largo
      uy = dy / largo
      uy = (abajo ? -1.0 : 1.0) if (abajo && uy > -0.3) || (!abajo && uy < 0.3)
      ax = bx + ux * usa
      ay = borde + uy * usa
      # lienzo: el cuadro y el pico juntos
      x0 = [cx, ax - 4, bx - PICO_MEDIO - 4].min.floor
      y0 = [cy, ay - 4].min.floor
      x1 = [cx + PNJ_W, ax + 4, bx + PICO_MEDIO + 4].max.ceil
      y1 = [cy + PNJ_H, ay + 4].max.ceil
      lienzo = Bitmap.new(x1 - x0, y1 - y0)
      triangulo(lienzo, ax - x0, ay - y0, bx - PICO_MEDIO - x0, bx + PICO_MEDIO - x0, borde - y0, FILO, 1.5)
      triangulo(lienzo, ax - x0, ay - y0, bx - PICO_MEDIO - x0, bx + PICO_MEDIO - x0, borde - y0, MARCO, 0)
      lienzo.blt(cx - x0, cy - y0, caja, caja.rect)
      caja.dispose
      # el dibujo del cuadro lleva una sombra fina y oscura por fuera del marco:
      # donde nace el pico se tapa repintandolo por encima hasta la linea del
      # marco, asi pico y marco quedan unidos sin raya
      base2 = abajo ? cy + 19 : cy + PNJ_H - 12
      medio2 = PICO_MEDIO * (base2 - ay) / (borde - ay).to_f
      triangulo(lienzo, ax - x0, ay - y0, bx - medio2 - x0, bx + medio2 - x0, base2 - y0, MARCO, 0)
      @pnj_bitmap.dispose if @pnj_bitmap && !@pnj_bitmap.disposed?
      @pnj_bitmap = lienzo
      # el texto, en el hueco del papel; la hoja, en su esquina de siempre
      CAJAS["pnj"] = ["PNJ_CUADRO.png", x0, y0, cx + 149, cy + 40,
                      "DlgHoja.png", cx + 826, cy + 156]
      return true
    end

    def pnj_soltar
      @pnj_bitmap.dispose if @pnj_bitmap && !@pnj_bitmap.disposed?
      @pnj_bitmap = nil
    end

    # Un triangulo de vertice (ax, ay) y base horizontal de x1 a x2 en la
    # altura by, fila a fila y con los bordes suavizados. "crece" lo engorda
    # (para el filo oscuro de debajo).
    def triangulo(b, ax, ay, x1, x2, by, color, crece)
      ya = [ay, by].min.floor
      yb = [ay, by].max.ceil
      (ya..yb).each do |y|
        t = (y + 0.5 - ay) / (by - ay).to_f
        next if t < 0 || t > 1
        izq = ax + (x1 - ax) * t - crece
        der = ax + (x2 - ax) * t + crece
        next if der <= izq
        i0 = izq.ceil
        i1 = der.floor
        b.fill_rect(i0, y, i1 - i0, 1, color) if i1 > i0
        # los dos pixeles del borde, a medias segun cuanto los cubre
        [[i0 - 1, i0 - izq], [i1, der - i1]].each do |px, cubre|
          cubre = [[cubre, 0.0].max, 1.0].min
          next if cubre <= 0.02
          c = Color.new(color.red, color.green, color.blue, color.alpha * cubre)
          b.fill_rect(px, y, 1, 1, c)
        end
      end
    end
  end
end

module OstinatoVecinos
  class << self
    alias ostpnj_hablar hablar
    def hablar(prefijo, desde, hasta = nil)
      ev = nil
      begin
        ev = pbMapInterpreter.get_self
      rescue
        ev = nil
      end
      ok = false
      begin
        ok = OstDlg.pnj_preparar(ev)
      rescue StandardError => e
        echoln("OstDlg.pnj: #{e.class}: #{e.message}")
        ok = false
      end
      return ostpnj_hablar(prefijo, desde, hasta) if !ok
      hasta ||= desde
      guion = []
      (desde..hasta).each do |k|
        nombre = sprintf("%s%02d", prefijo, k)
        b = OstDlg.bmp(OstDlg::DIR + nombre + ".png")
        next if !b
        b.dispose
        guion.push([nombre, "pnj"])
      end
      begin
        OstDlg.run(guion, {}) if guion.length > 0
      ensure
        OstDlg.pnj_soltar
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Frases en dos pantallas: si una frase no cabia en el cuadro, el generador
# (recursos/herramientas/textos_guion.ps1) la parte en CODIGO.png y
# CODIGOb.png (y c, d...). Aqui se meten las continuaciones en el guion, justo
# detras y con el mismo lado, para que se lean seguidas.
#-------------------------------------------------------------------------------
module OstDlg
  class << self
    alias ostcont_run run
    def run(guion, artes, ajustes = nil)
      lista = []
      guion.each do |paso|
        lista.push(paso)
        next if !paso.is_a?(Array) || !paso[0].is_a?(String)
        next if ["pausa", "se", "haz", "tv"].include?(paso[0])
        ["b", "c", "d"].each do |s|
          break if !pbResolveBitmap(DIR + paso[0] + s)
          lista.push([paso[0] + s] + paso[1..-1])
        end
      end
      return ostcont_run(lista, artes, ajustes)
    end
  end
end
