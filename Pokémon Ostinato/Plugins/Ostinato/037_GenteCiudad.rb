#===============================================================================
# Pokemon Ostinato - La ciudad del gimnasio (mapa 19): gente por las aceras
#
#   Unos vecinos pasean por las aceras y las plazas, nunca por la calzada. Cada
#   uno tiene su paseo (casillas por las que pasa, en linea recta de una a la
#   siguiente): de ida y vuelta, o dando la vuelta entera. A veces se paran un
#   rato en una esquina. Si Kaia les corta el paso, esperan mirandola; si no se
#   aparta, los de ida y vuelta se dan la vuelta. No se dejan atravesar.
#   Se pintan desde aqui, como los coches (036): no son eventos del mapa.
#   Los paseos se comprobaron casilla a casilla contra el paso del tileset 50.
#===============================================================================
module OstGente
  MAPA      = 19
  VELOCIDAD = 1.0        # px por fotograma (Kaia andando va a unos 4)
  PASO      = 10.0       # px andados por cada dibujo de la animacion
  ESPERA    = 90         # fotogramas esperando a que Kaia se aparte antes de darse la vuelta
  # [personaje, casillas del paseo, :ida_vuelta o :vuelta]
  PASEOS = [
    ["hombre1",  [[5, 9], [5, 27]],                              :ida_vuelta],   # acera de la izquierda
    ["mujer2",   [[21, 32], [21, 37], [36, 37], [36, 32]],       :ida_vuelta],   # plaza del metro
    ["chaval2",  [[18, 24], [46, 24]],                           :ida_vuelta],   # acera de arriba de la calle
    ["anciano2", [[68, 15], [68, 26]],                           :ida_vuelta],   # acera de la derecha
    ["chica1",   [[50, 13], [67, 13], [67, 22]],                 :ida_vuelta],   # delante del Centro Pokemon
    ["mujer1",   [[13, 14], [25, 14], [25, 19], [13, 19]],       :vuelta]        # jardin de la cerveceria
  ]
  FILA = { 2 => 0, 4 => 1, 6 => 2, 8 => 3 }

  class Vecino
    attr_accessor :grafico, :camino, :modo, :i, :sentido, :x, :y, :hacia, :dir,
                  :andado, :quieto, :esperando, :sprite
  end

  def self.en_mapa?; return $game_map && $game_map.map_id == MAPA; end
  def self.vecinos; return @vecinos || []; end

  def self.crear
    soltar
    @vecinos = PASEOS.map do |g, camino, modo|
      v = Vecino.new
      v.grafico = g
      v.camino = camino
      v.modo = modo
      n = camino.length
      j = rand(n)                       # cada uno empieza en una esquina de su paseo
      if modo == :vuelta
        v.sentido = 1
        v.i = (j + 1) % n
      elsif j == n - 1
        v.sentido = -1
        v.i = j - 1
      else
        v.sentido = 1
        v.i = j + 1
      end
      v.x = camino[j][0] * 32.0
      v.y = camino[j][1] * 32.0
      v.hacia = nil
      v.dir = 2
      v.andado = 0.0
      v.quieto = rand(120)
      v.esperando = 0
      v
    end
  end

  def self.soltar
    vecinos.each { |v| OstDlg.soltar(v.sprite) if v.sprite }
    @vecinos = nil
    @vp = nil
  end

  # las casillas que ocupa: la suya y, si va andando, tambien la de al lado
  def self.casillas(v)
    return [[(v.x / 32).floor, (v.y / 32).floor], [(v.x / 32).ceil, (v.y / 32).ceil]]
  end

  def self.gente_en?(x, y, menos = nil)
    return false if !en_mapa?
    vecinos.any? { |v| !v.equal?(menos) && casillas(v).include?([x, y]) }
  end

  def self.kaia_en?(x, y)
    pl = $game_player
    return true if pl.x == x && pl.y == y
    rx = (pl.real_x.to_f / Game_Map::REAL_RES_X).round
    ry = (pl.real_y.to_f / Game_Map::REAL_RES_Y).round
    return rx == x && ry == y
  end

  def self.siguiente(v)
    n = v.camino.length
    if v.modo == :vuelta
      v.i = (v.i + 1) % n
    else
      v.sentido = -v.sentido if v.i + v.sentido < 0 || v.i + v.sentido >= n
      v.i += v.sentido
    end
  end

  def self.mover
    vecinos.each do |v|
      if v.hacia                        # andando hacia la casilla de al lado
        hx = v.hacia[0] * 32.0
        hy = v.hacia[1] * 32.0
        v.x += [[hx - v.x, VELOCIDAD].min, -VELOCIDAD].max
        v.y += [[hy - v.y, VELOCIDAD].min, -VELOCIDAD].max
        v.andado += VELOCIDAD
        v.hacia = nil if v.x == hx && v.y == hy
        next
      end
      if v.quieto > 0
        v.quieto -= 1
        next
      end
      tx = (v.x / 32).round
      ty = (v.y / 32).round
      wx, wy = v.camino[v.i]
      if tx == wx && ty == wy           # en una esquina: a la siguiente, y a veces se para un rato
        siguiente(v)
        v.quieto = rand < 0.4 ? 40 + rand(110) : 0
        next
      end
      nx = tx + (wx <=> tx)
      ny = ty + (wy <=> ty)
      v.dir = nx > tx ? 6 : nx < tx ? 4 : ny > ty ? 2 : 8
      if kaia_en?(nx, ny) || gente_en?(nx, ny, v)
        v.esperando += 1
        if v.esperando > ESPERA && v.modo == :ida_vuelta
          v.sentido = -v.sentido          # vuelve a la esquina de la que venia
          v.i += v.sentido
          v.esperando = 0
        end
        next
      end
      v.esperando = 0
      v.hacia = [nx, ny]
    end
  end

  def self.pintar
    if !en_mapa?
      soltar if @vecinos
      return
    end
    vp = (Spriteset_Map.viewport rescue nil)
    return if !vp || vp.disposed? || !@vecinos
    if @vp != vp
      vecinos.each { |v| v.sprite = nil }
      @vp = vp
    end
    ox = $game_map.display_x.to_f / Game_Map::X_SUBPIXELS
    oy = $game_map.display_y.to_f / Game_Map::Y_SUBPIXELS
    vecinos.each do |v|
      if !v.sprite || v.sprite.disposed?
        v.sprite = Sprite.new(vp)
        v.sprite.bitmap = OstDlg.bmp("Graphics/Characters/#{v.grafico}.png")
      end
      b = v.sprite.bitmap
      next if !b
      fw = b.width / 4
      fh = b.height / 4
      f = v.hacia ? (v.andado / PASO).to_i % 4 : 0
      v.sprite.src_rect = Rect.new(f * fw, FILA[v.dir] * fh, fw, fh)
      v.sprite.ox = fw / 2
      v.sprite.oy = fh
      v.sprite.x = (v.x + 16 - ox).round
      v.sprite.y = (v.y + 32 - oy).round
      v.sprite.z = (v.y + 32 - oy).round + 31
    end
  end

  #--- cada fotograma -------------------------------------------------------------
  def self.comprobar
    if !en_mapa? || !$game_player
      soltar if @vecinos
      @mapa_visto = nil
      return
    end
    if !@mapa_visto.equal?($game_map.data)     # al entrar al mapa (o al recargarlo)
      @mapa_visto = $game_map.data
      crear
    end
    mover
  end
end

class Game_Player
  # Kaia no atraviesa a la gente
  alias ostgente_passable? passable?
  def passable?(x, y, dir, strict = false)
    nx = x + (dir == 6 ? 1 : dir == 4 ? -1 : 0)
    ny = y + (dir == 2 ? 1 : dir == 8 ? -1 : 0)
    return false if OstGente.gente_en?(nx, ny)
    return ostgente_passable?(x, y, dir, strict)
  end
end

class Scene_Map
  alias ostgente_update update
  def update
    ostgente_update
    OstGente.comprobar
  end

  alias ostgente_updateSpritesets updateSpritesets
  def updateSpritesets(*args)
    ostgente_updateSpritesets(*args)
    OstGente.pintar
  end
end
