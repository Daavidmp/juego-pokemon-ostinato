#===============================================================================
# Pokemon Ostinato - Pokemon animados en combate
#
#   Los sprites de Graphics/Pokemon/Animados/ (Front, Back, Front shiny,
#   Back shiny; los de Pokemon Anil, del "[DBK] Animated Pokemon System":
#   ver CREDITOS.md) son tiras de cuadros cuadrados. Solo se usan en combate;
#   la mochila, el equipo, la Pokedex, etc. siguen con los de
#   Graphics/Pokemon/ (fijos).
#
#   Al poner el dibujo de un Pokemon en combate, la tira se trocea en sus
#   cuadros, ampliados x2 como los fijos (los de Anil son a tamano real y los
#   de Ostinato van al doble), y se pasan los cuadros a su ritmo (VELOCIDAD,
#   la de Anil). Asi todo lo de 016 (escala, pies en el suelo, corte de tus
#   Pokemon tras la barra), 018 (camaras) y 019/031 (debilitarse) funciona
#   igual: ven un bitmap del tamano de siempre.
#   Los pies se ponen donde los tenia el dibujo fijo (sus medidas de
#   pokemon_metrics.txt estan hechas para el), salvo donde 016 ya los apoya
#   por su cuenta (dobles y suelo del tunel).
#   Si una especie no tiene tira (o es variocolor y no hay tira variocolor),
#   se queda con el dibujo fijo.
#===============================================================================
module OstAnimados
  DIR    = "Graphics/Pokemon/Animados/"
  ESCALA = 2
  RETRASO = 0.060      # segundos por cuadro con velocidad 2 (Anil: velocidad / 2 * 60 ms)

  # velocidad de cada especie en Anil: [espaldas, de frente]; si falta, 2
  VELOCIDAD = {
    "IVYSAUR" => [1],
    "CHARIZARD" => [1],
    "WARTORTLE" => [1],
    "BUTTERFREE" => [1],
    "WEEDLE" => [1],
    "KAKUNA" => [1],
    "SPEAROW" => [1],
    "PIKACHU" => [1],
    "NIDORINA" => [1],
    "NIDOQUEEN" => [1],
    "NIDORANmA" => [1],
    "NIDOKING" => [1],
    "VULPIX" => [1],
    "WIGGLYTUFF" => [3],
    "ZUBAT" => [1],
    "ODDISH" => [1],
    "GLOOM" => [1],
    "VILEPLUME" => [1],
    "VENONAT" => [1],
    "PERSIAN" => [1],
    "GOLDUCK" => [1],
    "GROWLITHE" => [1],
    "KADABRA" => [1],
    "MACHAMP" => [1],
    "WEEPINBELL" => [1],
    "VICTREEBEL" => [1],
    "GOLEM" => [1],
    "PONYTA" => [1],
    "RAPIDASH" => [1],
    "SLOWBRO" => [1],
    "MAGNETON" => [1],
    "DODUO" => [1],
    "DODRIO" => [1],
    "GRIMER" => [1],
    "MUK" => [1],
    "SHELLDER" => [1],
    "DROWZEE" => [1],
    "HYPNO" => [1],
    "VOLTORB" => [1],
    "RHYHORN" => [1],
    "TANGELA" => [1],
    "KANGASKHAN" => [1],
    "STARYU" => [1],
    "STARMIE" => [1],
    "MRMIME" => [1],
    "SCYTHER" => [1],
    "GYARADOS" => [1],
    "DITTO" => [1],
    "JOLTEON" => [1],
    "OMASTAR" => [1],
    "MEW" => [1],
    "TOTODILE" => [1],
    "FERALIGATR" => [1],
    "SENTRET" => [1],
    "LEDYBA" => [1],
    "SPINARAK" => [1],
    "CROBAT" => [1],
    "PICHU" => [1],
    "TOGEPI" => [1],
    "TOGETIC" => [1],
    "NATU" => [1],
    "XATU" => [1],
    "SUDOWOODO" => [4],
    "HOPPIP" => [1],
    "SKIPLOOM" => [1],
    "YANMA" => [1],
    "WOOPER" => [1],
    "SLOWKING" => [1],
    "GIRAFARIG" => [1],
    "SNUBBULL" => [1],
    "QWILFISH" => [1],
    "SHUCKLE" => [1],
    "TEDDIURSA" => [1],
    "SLUGMA" => [1],
    "OCTILLERY" => [1],
    "HOUNDOUR" => [1],
    "PHANPY" => [1],
    "HITMONTOP" => [1],
    "SMOOCHUM" => [1],
    "BLISSEY" => [1],
    "SUICUNE" => [1],
    "LUGIA" => [4],
    "TORCHIC" => [1],
    "COMBUSKEN" => [2,1],
    "MIGHTYENA" => [1],
    "LINOONE" => [1],
    "WURMPLE" => [1],
    "NUZLEAF" => [1],
    "SWELLOW" => [1],
    "RALTS" => [1],
    "MASQUERAIN" => [1],
    "VIGOROTH" => [1],
    "NINJASK" => [1],
    "MAWILE" => [1],
    "MEDICHAM" => [1],
    "VOLBEAT" => [1],
    "ILLUMISE" => [1],
    "ROSELIA" => [1],
    "SWALOT" => [1],
    "SHARPEDO" => [1],
    "WAILMER" => [1],
    "TORKOAL" => [1],
    "SPOINK" => [1],
    "GRUMPIG" => [1],
    "TRAPINCH" => [1],
    "SWABLU" => [1],
    "ALTARIA" => [1],
    "CRAWDAUNT" => [1],
    "MILOTIC" => [3],
    "SHUPPET" => [1],
    "DUSCLOPS" => [1],
    "CHIMECHO" => [1],
    "ABSOL" => [1],
    "WYNAUT" => [1],
    "SPHEAL" => [1],
    "SEALEO" => [1],
    "WALREIN" => [1],
    "HUNTAIL" => [1],
    "GOREBYSS" => [1],
    "RELICANTH" => [1],
    "RAYQUAZA" => [1],
    "CHIMCHAR" => [1],
    "INFERNAPE" => [1],
    "EMPOLEON" => [1],
    "STARAVIA" => [1],
    "STARAPTOR" => [1],
    "BIDOOF" => [1],
    "BIBAREL" => [1],
    "KRICKETOT" => [1],
    "SHINX" => [1],
    "LUXIO" => [1],
    "LUXRAY" => [1],
    "ROSERADE" => [1],
    "CRANIDOS" => [1],
    "BURMY" => [1],
    "WORMADAM" => [1],
    "VESPIQUEN" => [1],
    "PACHIRISU" => [1],
    "BUNEARY" => [1],
    "PURUGLY" => [1],
    "STUNKY" => [1],
    "SKUNTANK" => [1],
    "MIMEJR" => [1],
    "SPIRITOMB" => [1],
    "RIOLU" => [1],
    "LUCARIO" => [1],
    "SKORUPI" => [1],
    "CROAGUNK" => [1],
    "SNOVER" => [1],
    "WEAVILE" => [1],
    "RHYPERIOR" => [3],
    "TOGEKISS" => [1],
    "LEAFEON" => [1],
    "GLISCOR" => [1],
    "FROSLASS" => [1],
    "HEATRAN" => [3],
    "GIRATINA" => [3],
    "SHAYMIN" => [1],
    "ARCEUS" => [2,3],
    "SNIVY" => [1],
    "SERPERIOR" => [1],
    "EMBOAR" => [1],
    "OSHAWOTT" => [1],
    "SAMUROTT" => [1],
    "LILLIPUP" => [1],
    "HERDIER" => [1],
    "STOUTLAND" => [1],
    "SIMISAGE" => [1],
    "SIMIPOUR" => [1],
    "UNFEZANT" => [1],
    "ZEBSTRIKA" => [1],
    "ROGGENROLA" => [1],
    "GIGALITH" => [1],
    "EXCADRILL" => [1],
    "TIMBURR" => [1],
    "SEWADDLE" => [1],
    "SWADLOON" => [1],
    "SCOLIPEDE" => [3],
    "PETILIL" => [1],
    "SANDILE" => [1],
    "DARUMAKA" => [1],
    "MARACTUS" => [1],
    "SCRAFTY" => [1],
    "TIRTOUGA" => [1],
    "ZOROARK" => [1],
    "GOTHITA" => [1],
    "GOTHORITA" => [1],
    "GOTHITELLE" => [1],
    "SOLOSIS" => [1],
    "DUOSION" => [1],
    "VANILLITE" => [1],
    "VANILLISH" => [2,1],
    "SAWSBUCK" => [1],
    "FRILLISH" => [1],
    "JELLICENT" => [1],
    "GALVANTULA" => [1],
    "LAMPENT" => [1],
    "CHANDELURE" => [1],
    "FRAXURE" => [1],
    "SHELMET" => [1],
    "STUNFISK" => [1],
    "MIENFOO" => [1],
    "BISHARP" => [1],
    "BRAVIARY" => [1],
    "VULLABY" => [1],
    "ZWEILOUS" => [1],
    "HYDREIGON" => [1],
    "VIRIZION" => [1],
    "TORNADUS" => [3],
    "ZEKROM" => [3],
    "GENESECT" => [1],
    "CHESNAUGHT" => [3,2],
    "FENNEKIN" => [1,2],
    "BRAIXEN" => [3],
    "BUNNELBY" => [2,3],
    "VIVILLON" => [3],
    "LITLEO" => [4],
    "FLORGES" => [1],
    "PANGORO" => [4,2],
    "FURFROU" => [3,2],
    "MEOWSTIC" => [3],
    "AEGISLASH" => [3],
    "SPRITZEE" => [1],
    "INKAY" => [3,2],
    "MALAMAR" => [3],
    "BARBARACLE" => [4,3],
    "DRAGALGE" => [3],
    "CLAUNCHER" => [3],
    "CLAWITZER" => [3],
    "HELIOPTILE" => [3,2],
    "HELIOLISK" => [3],
    "AMAURA" => [1],
    "AURORUS" => [4],
    "SLIGGOO" => [3],
    "GOODRA" => [3,2],
    "PHANTUMP" => [3],
    "TREVENANT" => [4,3],
    "PUMPKABOO" => [4,2],
    "GOURGEIST" => [3],
    "AVALUGG" => [4],
    "NOIVERN" => [3],
    "XERNEAS" => [3],
    "VOLCANION" => [4,2],
    "DARTRIX" => [3],
    "DECIDUEYE" => [3],
    "LITTEN" => [1,2],
    "INCINEROAR" => [3],
    "PRIMARINA" => [4,2],
    "PIKIPEK" => [3],
    "TRUMBEAK" => [1],
    "TOUCANNON" => [3,2],
    "GUMSHOOS" => [3,2],
    "CRABRAWLER" => [3],
    "ROCKRUFF" => [3],
    "LYCANROC" => [3,2],
    "WISHIWASHI" => [3,2],
    "MAREANIE" => [3,2],
    "TOXAPEX" => [4,2],
    "DEWPIDER" => [1,2],
    "FOMANTIS" => [1],
    "LURANTIS" => [3],
    "BEWEAR" => [1,2],
    "BOUNSWEET" => [1],
    "STEENEE" => [1],
    "TSAREENA" => [3],
    "GOLISOPOD" => [1],
    "SANDYGAST" => [3],
    "PALOSSAND" => [3],
    "PYUKUMUKU" => [1],
    "SILVALLY" => [1],
    "MINIOR" => [3],
    "TOGEDEMARU" => [1],
    "BRUXISH" => [4,1],
    "TAPUKOKO" => [3],
    "TAPULELE" => [3,2],
    "LUNALA" => [3,2],
    "NIHILEGO" => [3],
    "BUZZWOLE" => [4,2],
    "GUZZLORD" => [3],
    "MARSHADOW" => [3],
    "POIPOLE" => [2,1],
    "STAKATAKA" => [4],
    "ZERAORA" => [1],
    "MELMETAL" => [3],
    "THWACKEY" => [3],
    "CINDERACE" => [3,2],
    "SOBBLE" => [3],
    "DRIZZILE" => [3],
    "BLIPBUG" => [3],
    "DOTTLER" => [3],
    "ORBEETLE" => [3],
    "THIEVUL" => [3],
    "GOSSIFLEUR" => [3,2],
    "WOOLOO" => [1,2],
    "DUBWOOL" => [4],
    "DREDNAW" => [3],
    "COALOSSAL" => [4,2],
    "APPLIN" => [2,3],
    "APPLETUN" => [3],
    "ARROKUDA" => [3,2],
    "BARRASKEWDA" => [3],
    "CENTISKORCH" => [3],
    "SINISTEA" => [3],
    "POLTEAGEIST" => [3],
    "HATTREM" => [3],
    "HATTERENE" => [3,2],
    "MORGREM" => [3],
    "OBSTAGOON" => [4],
    "PERRSERKER" => [1],
    "CURSOLA" => [1],
    "SIRFETCHD" => [3,2],
    "RUNERIGUS" => [3],
    "MILCERY" => [3],
    "ALCREMIE" => [3,2],
    "SNOM" => [3,2],
    "FROSMOTH" => [3,2],
    "EISCUE" => [3],
    "MORPEKO" => [3],
    "CUFANT" => [3],
    "COPPERAJAH" => [4,3],
    "ARCTOZOLT" => [3,1],
    "DURALUDON" => [4],
    "ETERNATUS" => [3,2],
    "KUBFU" => [3,2],
    "URSHIFU" => [3],
    "ZARUDE" => [3],
    "REGIDRAGO" => [1],
    "GLASTRIER" => [4,3],
    "SPECTRIER" => [3],
    "CALYREX" => [3],
    "BASCULEGION_1" => [3],
    "FINNEON_female" => [3],
    "GARCHOMP_female" => [4],
    "BUIZEL_female" => [4],
    "GABITE_female" => [3],
    "GIBLE_female" => [3],
    "GLIGAR_female" => [3],
    "GLOOM_female" => [1],
    "GULPIN_female" => [3],
    "HIPPOPOTAS_female" => [3],
    "HIPPOWDON_female" => [3],
    "HOUNDOOM_female" => [3],
    "KADABRA_female" => [1],
    "KRICKETUNE_female" => [3],
    "LEDIAN_female" => [4],
    "LEDYBA_female" => [3],
    "LUDICOLO_female" => [4],
    "LUMINEON_female" => [4],
    "MAGIKARP_female" => [3],
    "MAMOSWINE_female" => [3],
    "MEDITITE_female" => [3],
    "MEGANIUM_female" => [3],
    "MILOTIC_female" => [3],
    "MURKROW_female" => [3],
    "PILOSWINE_female" => [3],
    "POLITOED_female" => [3],
    "POLTEAGEIST_1" => [3],
    "QUAGSIRE_female" => [3],
    "ROSELIA_female" => [3],
    "ROSERADE_female" => [1,2],
    "SEAKING_female" => [3],
    "SILVALLY_1" => [1],
    "SNOVER_female" => [3],
    "STARAVIA_female" => [3],
    "STARLY_female" => [3],
    "STEELIX_female" => [3],
    "SWALOT_female" => [3],
    "TOXICROAK_female" => [3],
    "URSARING_female" => [3],
    "VILEPLUME_female" => [1],
    "WOBBUFFET_female" => [3],
    "ZUBAT_female" => [1],
    "FLOATZEL_female" => [3],
    "HERACROSS_female" => [3],
    "ROCKRUFF_2" => [3],
    "PIKACHU_16" => [1,2],
    "ROYALEON" => [1],
    "JUMPLUFF_1" => [3],
    "VICTREEBEL_1" => [2,1],
    "CHESNAUGHT_1" => [3,1],
    "GRENINJA_3" => [3,1],
    "RAICHU_2" => [3],
    "EELEKTROSS_1" => [1],
    "CLEFABLE_1" => [4,2],
    "STARMIE_1" => [2,1],
    "MEGANIUM_1" => [2,1],
    "SKARMORY_1" => [2,1],
    "CHIMECHO_1" => [2,1],
    "SCOLIPEDE_1" => [1],
    "SCRAFTY_1" => [2,1],
    "BARBARACLE_1" => [2,1],
    "DRAGALGE_1" => [3,1],
    "ZYGARDE_4" => [2,1],
    "BAXCALIBUR_1" => [3,1],
    "FERALIGATR_1" => [2,1],
    "EMBOAR_1" => [1],
    "BASCULIN_3" => [1],
    "CHANDELURE_1" => [1],
    "ABSOL_2" => [2,1],
    "GARCHOMP_2" => [3],
    "MEOWSTIC_2" => [3],
    "SCOVILLAIN_1" => [2,1],
    "GLIMMORA_1" => [3,2],
    "HEATRAN_1" => [3],
    "DARKRAI_1" => [2,3],
    "PIKACHU_16_female" => [1,2],
  }

  def self.velocidad(pkmn, back)
    sp = pkmn.species.to_s
    claves = []
    claves.push("#{sp}_#{pkmn.form}_female") if pkmn.form > 0 && pkmn.female?
    claves.push("#{sp}_#{pkmn.form}") if pkmn.form > 0
    claves.push("#{sp}_female") if pkmn.female?
    claves.push(sp)
    v = nil
    claves.each { |c| break if (v = VELOCIDAD[c]) }
    return 2 if !v
    return back ? v[0] : (v[1] || v[0])
  end

  # la tira de este Pokemon, o nil
  def self.archivo(pkmn, back)
    return nil if !pkmn || pkmn.egg?
    ret = GameData::Species.check_graphic_file(DIR, pkmn.species, pkmn.form, pkmn.gender,
                                               pkmn.shiny?, (pkmn.shadowPokemon? rescue false),
                                               back ? "Back" : "Front")
    return nil if !ret
    return nil if File.basename(ret).start_with?("000")         # el "?" de relleno
    return nil if pkmn.shiny? && !ret.include?(" shiny/")       # sin variocolor: el fijo, que si lo tiene
    return ret
  rescue
    return nil
  end
end

# Un cuadro de la tira: lleva apuntadas las filas vacias de abajo, las mismas
# para todos los cuadros (las de la tira entera), para que los pies no bailen
class OstCuadro < Bitmap
  attr_accessor :ost_vacio
end

# Lo que el combate espera de un AnimatedBitmap (bitmap, width, height,
# update, dispose), con los cuadros ya troceados y ampliados
class OstTira
  attr_reader :total, :vacio

  def initialize(archivo, velocidad, pkmn)
    @pkmn = pkmn
    @velocidad = velocidad
    tira = Bitmap.new(archivo)
    lado = tira.height
    @total = (tira.width > lado && tira.width % lado == 0) ? tira.width / lado : 1
    ancho = (@total > 1) ? lado : tira.width
    @cuadros = Array.new(@total) do |i|
      b = OstCuadro.new(ancho * OstAnimados::ESCALA, lado * OstAnimados::ESCALA)
      b.stretch_blt(b.rect, tira, Rect.new(i * ancho, 0, ancho, lado))
      b
    end
    tira.dispose
    # filas vacias por debajo de los pies en toda la tira (el cuadro mas bajo)
    @vacio = @cuadros.map { |b| OstCombate.vacio_abajo(b) }.min || 0
    @cuadros.each { |b| b.ost_vacio = @vacio }
    @i = 0
    @antes = System.uptime
  end

  def bitmap;   return @cuadros[@i]; end
  def width;    return bitmap.width; end
  def height;   return bitmap.height; end
  def length;   return @total; end
  def disposed?; return @cuadros.nil?; end

  def update
    return if !@cuadros || @total <= 1
    v = @velocidad
    case (@pkmn.status rescue :NONE)
    when :FROZEN then return
    when :SLEEP  then v *= 3
    end
    return if v <= 0
    retraso = v / 2.0 * OstAnimados::RETRASO
    ahora = System.uptime
    pasos = ((ahora - @antes) / retraso).floor
    return if pasos <= 0
    @i = (@i + pasos) % @total
    @antes += pasos * retraso
  end

  def dispose
    return if !@cuadros
    @cuadros.each { |b| b.dispose if !b.disposed? }
    @cuadros = nil
  end
end

# las filas vacias de un cuadro, sin recorrerlo (la cache de 016 se vacia a los 64)
module OstCombate
  class << self
    alias ostanim_vacio_abajo vacio_abajo
    def vacio_abajo(bm)
      return bm.ost_vacio if bm.is_a?(OstCuadro) && bm.ost_vacio && !bm.disposed?
      return ostanim_vacio_abajo(bm)
    end
  end
end

class Battle::Scene::BattlerSprite
  alias ostanim_setPokemonBitmap setPokemonBitmap
  def setPokemonBitmap(pkmn, back = false)
    @ost_tira_vs = nil
    archivo = OstCombate.activo? ? OstAnimados.archivo(pkmn, back) : nil
    if !archivo
      @ost_tira = false
      return ostanim_setPokemonBitmap(pkmn, back)
    end
    @pkmn = pkmn
    @_iconBitmap&.dispose
    # las filas vacias del dibujo fijo, para dejar los pies donde estaban
    fijo = GameData::Species.sprite_bitmap_from_pokemon(pkmn, back)
    @ost_tira_vs = fijo ? OstCombate.vacio_abajo(fijo.bitmap) : 0
    fijo&.dispose
    begin
      @_iconBitmap = OstTira.new(archivo, OstAnimados.velocidad(pkmn, back), pkmn)
      @ost_tira = true
    rescue StandardError => e
      echoln("OstAnimados: #{archivo}: #{e.message}")
      @_iconBitmap = GameData::Species.sprite_bitmap_from_pokemon(pkmn, back)
      @ost_tira = false
      @ost_tira_vs = nil
    end
    self.bitmap = (@_iconBitmap) ? @_iconBitmap.bitmap : nil
    pbSetPosition
  end

  alias ostanim_pbSetPosition pbSetPosition
  def pbSetPosition
    ostanim_pbSetPosition
    return if !@ost_tira || !@ost_tira_vs || !@_iconBitmap
    # 016 ya apoya por los pies a los rivales en dobles y en el tunel
    return if respond_to?(:ost_suelo_y) && ost_suelo_y
    k = respond_to?(:ost_k) ? ost_k : 1
    self.y = self.y + (@_iconBitmap.vacio - @ost_tira_vs) * k
    @ost_reposo_fondo = OstCamara.fondo(self) if defined?(OstCamara) && OstCombate.activo?
  end
end
