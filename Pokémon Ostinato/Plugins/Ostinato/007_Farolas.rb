#===============================================================================
# Pokemon Ostinato - Las farolas de Villa Bambalina se encienden solas.
#
# No hace falta poner un evento encima de cada una: al montar el mapa se
# recorren las tres capas buscando la casilla de arriba a la izquierda de cada
# farola del tileset, y por cada una que aparece se cuelga un halo de luz.
# De dia apenas se nota; segun cae la tarde va subiendo, y de noche queda
# encendida del todo.
#===============================================================================
module OstFarolas
  IMAGEN = "Graphics/Pictures/FarolaLuz.png"

  LUZ_DIA   = 55    # opacidad con el sol alto: se intuye y poco mas
  LUZ_NOCHE = 245   # opacidad de madrugada

  # Los modelos de farola del tileset "Villa Bambalina". De cada uno:
  #   fila y columna de su casilla de arriba a la izquierda,
  #   donde cae el farol en pixeles contados desde esa esquina,
  #   de que color tira su luz,
  #   y cuanto abulta el halo.
  MODELOS = [
    [801, 0, 48, 75, [255, 226, 150], 1.25],   # farola_marioneta
    [801, 2, 16, 75, [255, 226, 150], 1.25],   # la misma, del reves
    [801, 4, 48, 50, [255, 214, 138], 1.25],   # farola_teatrito
    [801, 6, 16, 50, [255, 214, 138], 1.25],
    [805, 0, 16, 46, [255, 236, 150], 1.05],   # farola verde
    [805, 1, 16, 46, [255, 236, 150], 1.05],
    [805, 2, 16, 38, [206, 230, 255], 1.05],   # farola azul
    [805, 3, 16, 38, [206, 230, 255], 1.05],
    [806, 4, 16, 46, [225, 248, 255], 1.05],   # farola blanca
    [806, 5, 16, 46, [225, 248, 255], 1.05],
    [805, 6, 16, 38, [255, 240, 205], 1.05],   # farola marron
    [805, 7, 16, 38, [255, 240, 205], 1.05]
  ]

  # Game_Map no tiene tileset_id, pero si tileset_name: es el nombre del png.
  TILESET = "Villa Bambalina"

  # Cuanta noche hay ahora mismo: 0.0 a pleno sol, 1.0 de madrugada. Se usa la
  # misma franja de atardecer que el tinte del juego para que la luz suba a la
  # vez que oscurece la pantalla.
  def self.fuerza
    marca = (Graphics.frame_count rescue 0)
    return @guardada if @guardada && @marca == marca
    @marca = marca
    sombra = 0
    begin
      sombra = PBDayNight.getShade
    rescue
      @guardada = 1.0
      return @guardada
    end
    if sombra <= 64
      @guardada = 1.0
    elsif sombra >= 144
      @guardada = 0.0
    else
      @guardada = (144 - sombra) / 80.0
    end
    return @guardada
  end

  # Recorre el mapa y devuelve donde hay farola y de que modelo.
  def self.buscar(map)
    sitios = []
    return sitios if !map
    return sitios if (map.tileset_name rescue "") != TILESET
    porId = {}
    MODELOS.each { |m| porId[384 + m[0] * 8 + m[1]] = m }
    datos = map.data
    return sitios if !datos
    for y in 0...map.height
      for x in 0...map.width
        for capa in 0...3
          m = porId[datos[x, y, capa]]
          sitios.push([x, y, m]) if m
        end
      end
    end
    return sitios
  end
end



# El halo de una farola. Vive en el mismo viewport que el mapa y se dibuja
# sumando, asi que de noche abre un charco de luz sobre el suelo oscurecido.
class OstFarolaLuz
  def initialize(x, y, modelo, viewport, map)
    @map = map
    @tx = x
    @ty = y
    @dx = modelo[2]
    @dy = modelo[3]
    @fase = rand(628) / 100.0   # cada farola late por su cuenta
    # medidas del motor: cuantas unidades internas ocupa una casilla
    @resX = Game_Map::REAL_RES_X
    @resY = Game_Map::REAL_RES_Y
    @subX = Game_Map::X_SUBPIXELS
    @subY = Game_Map::Y_SUBPIXELS
    @sprite = Sprite.new(viewport)
    begin
      @sprite.bitmap = Bitmap.new(OstFarolas::IMAGEN)
    rescue
      @sprite.bitmap = nil
    end
    if @sprite.bitmap
      @sprite.ox = @sprite.bitmap.width / 2
      @sprite.oy = @sprite.bitmap.height / 2
    end
    @sprite.blend_type = 1
    @sprite.zoom_x = modelo[5]
    @sprite.zoom_y = modelo[5]
    @sprite.color = Color.new(modelo[4][0], modelo[4][1], modelo[4][2], 210)
    @sprite.z = 1000
    @sprite.opacity = 0
    @disposed = false
    update
  end

  def disposed?
    return @disposed
  end

  def dispose
    return if @disposed
    b = @sprite.bitmap
    @sprite.dispose
    b.dispose if b && !b.disposed?
    @sprite = nil
    @map = nil
    @disposed = true
  end

  def update
    return if @disposed || !@sprite || @sprite.disposed?
    @fase += 0.045
    # un temblor muy corto, lo justo para que no parezca una calcomania
    temblor = 1.0 + (0.030 * Math.sin(@fase)) + (0.017 * Math.sin(@fase * 2.7))
    base = OstFarolas::LUZ_DIA +
           ((OstFarolas::LUZ_NOCHE - OstFarolas::LUZ_DIA) * OstFarolas.fuerza)
    op = (base * temblor).round
    op = 0 if op < 0
    op = 255 if op > 255
    @sprite.opacity = op
    @sprite.x = ((@tx * @resX) - @map.display_x) / @subX + @dx
    @sprite.y = ((@ty * @resY) - @map.display_y) / @subY + @dy
  end
end



EventHandlers.add(:on_new_spriteset_map, :ostinato_farolas,
  proc { |spriteset, viewport|
    mapa = spriteset.map
    OstFarolas.buscar(mapa).each { |sitio|
      spriteset.addUserSprite(
        OstFarolaLuz.new(sitio[0], sitio[1], sitio[2], viewport, mapa))
    }
  }
)
