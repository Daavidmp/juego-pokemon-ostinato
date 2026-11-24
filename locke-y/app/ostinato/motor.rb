# El motor de combate de Pokémon Ostinato para el combate en línea de Pokelocke (2.4.0).
#
#   ruby motor.rb <carpeta del juego>        (lee órdenes JSON por la entrada, una por línea, y contesta una por línea)
#
# Carga el código del juego (Essentials v21 + los plugins de Ostinato) sin gráficos y lleva cada combate en un Fiber:
# cuando el motor necesita que un jugador elija (la orden del turno o a quién sacar), el Fiber se para hasta que llega.
# Órdenes:
#   {"cmd":"nuevo","id":"4821-1","jugadores":["A","B"],"equipos":[[pk...],[pk...]],"normas":{...}}
#   {"cmd":"accion","id":"4821-1","lado":0,"accion":{"tipo":"ataque","i":2,"mega":false}|{"tipo":"cambio","i":3}|{"tipo":"rendirse"}}
#   {"cmd":"ver","id":"4821-1"}      {"cmd":"cerrar","id":"4821-1"}
# Respuesta: {"ok":true,"id":...,"n":total de sucesos,"log":[sucesos nuevos desde la última respuesta],"vistas":[v0,v1],
#             "espera":[e0,e1],"fin":null|0|1|"empate"} o {"ok":false,"error":"..."}
#
# Los textos van con marcas para que cada uno los lea desde su lado: \u0001<lado><l|U><nombre>\u0002 es un Pokémon
# («Greninja» si es tuyo, «el Greninja rival» si no), \u0003<lado><l|U>\u0002 un equipo («tu equipo» / «el equipo
# rival»), \u0004<lado>S<nombres>\u0002 una salida y \u0004<lado>R<nombre>\u0002 una retirada.
require 'json'
require_relative 'carga'

# el protocolo va por la salida de verdad; lo que el juego escriba con puts, a la de errores
PROTOCOLO = $stdout.dup
PROTOCOLO.sync = true
PROTOCOLO.set_encoding('UTF-8')
$stdout = $stderr
$stdin.set_encoding('UTF-8')
ERR = cargar_ostinato
preparar_partida
# el aviso de errores del juego abre una ventana; aquí, el error de verdad hacia arriba (lo recoge seguir)
def pbPrintException(e) = raise(e)

module Marca
  def self.pk(lado, low, nombre) = "\u0001#{lado}#{low ? 'l' : 'U'}#{nombre}\u0002"
  def self.equipo(lado, low) = "\u0003#{lado}#{low ? 'l' : 'U'}\u0002"
end

class Battle::Battler
  def pbThis(lowerCase = false) = Marca.pk(@index & 1, lowerCase, name)
  def pbTeam(lowerCase = false) = Marca.equipo(@index & 1, lowerCase)
  def pbOpposingTeam(lowerCase = false) = Marca.equipo(1 - (@index & 1), lowerCase)
end

# --- lo que lleva cada combate: las órdenes que esperan, lo que pasa (log) y en qué está ---
class Mando
  attr_accessor :pendiente, :espera, :log, :batalla, :fin, :error, :fibra
  def initialize
    @pendiente = [nil, nil]
    @espera = [nil, nil]
    @log = []
    @fin = nil
  end

  def ev(t, **d) = @log << {t: t, **d}

  # el motor pide una orden a un lado: si ya está, la toma; si no, se para hasta que llegue
  def pedir(lado, tipo)
    loop do
      a = @pendiente[lado]
      @pendiente[lado] = nil
      if a && (tipo == :accion || %w[cambio rendirse].include?(a['tipo']))
        @espera[lado] = nil
        return a
      end
      @espera[lado] = tipo
      Fiber.yield
    end
  end
end

def resumen_pk(pk, battler = nil)
  return nil if !pk
  b = battler
  {especie: GameData::Species.get(pk.species).id.to_s, numero: (GameData::Species.get(pk.species).id_number rescue nil),
   nombre: pk.name, nivel: pk.level, ps: b ? b.hp : pk.hp, max: b ? b.totalhp : pk.totalhp,
   estado: (b ? b.status : pk.status).to_s.downcase, shiny: pk.shiny?, genero: pk.gender, forma: pk.form,
   tipos: (b ? b.pbTypes(true) : pk.types).map(&:to_s)}
end

class EscenaRed < Battle::DebugSceneNoVisuals
  def initialize(mando)
    super(false)
    @m = mando
  end

  # los textos que el juego escribe desde el lado del jugador (lado 0) y no llevan pbThis: con marca
  def texto(msg)
    t = msg.to_s
    if t.end_with?('te desafía!') || t.end_with?('te desafían!')
      t = "\u0007\u0002"                                         # «¡X te desafía!», a cada uno su rival
    elsif (m = t.match(/\A¡Adelante, (.+)!\z/))
      t = "\u00040S#{m[1]}\u0002"
    elsif (m = t.match(/\A¡.+ saca a (.+)!\z/))
      t = "\u00041S#{m[1]}\u0002"
    end
    @m.ev(:msg, txt: t)
  end
  def pbDisplayMessage(msg, brief = false) = texto(msg)
  def pbDisplay(msg) = texto(msg)
  def pbDisplayPausedMessage(msg) = texto(msg)
  def pbDisplayConfirmMessage(msg) = (texto(msg); false)
  def pbShowCommands(msg, commands, defaultValue) = (texto(msg) if msg; 0)

  # la animación del juego que toca: la de «ataca el jugador» (anim0) y la de «ataca el rival» (anim1, que puede ser una
  # OppMove: [número, true]); cada Pokelocke usa la de su lado (como Battle::Scene#pbAnimation)
  BUSCADOR = Battle::Scene.allocate
  def pbAnimation(moveID, user, targets, hitNum = 0)
    mv = GameData::Move.try_get(moveID)
    @m.ev(:anim, mov: moveID.to_s, de: user&.index, a: Array(targets).compact.map(&:index), golpe: hitNum,
              tipo: mv&.type.to_s, cat: mv ? %w[F E S][mv.category] : 'F',
              anim0: (BUSCADOR.pbFindMoveAnimation(moveID, 0, hitNum) rescue nil),
              anim1: (BUSCADOR.pbFindMoveAnimation(moveID, 1, hitNum) rescue nil))
  end

  def pbCommonAnimation(name, user = nil, target = nil) = @m.ev(:comun, nombre: name.to_s, de: user&.index, a: target&.index)
  def pbDamageAnimation(battler, effectiveness = 0) = @m.ev(:golpe, lado: battler.index & 1, efic: effectiveness)

  def pbHitAndHPLossAnimation(targets)
    targets.each do |b, _old, eff|
      @m.ev(:golpe, lado: b.index & 1, efic: eff)
      @m.ev(:ps, lado: b.index & 1, ps: b.hp, max: b.totalhp)
    end
  end

  def pbHPChanged(battler, oldHP, showAnim = false) = @m.ev(:ps, lado: battler.index & 1, ps: battler.hp, max: battler.totalhp)
  def pbFaintBattler(battler) = @m.ev(:debil, lado: battler.index & 1)
  def pbRecall(idx) = @m.ev(:vuelve, lado: idx & 1)

  def pbSendOutBattlers(sendOuts, startBattle = false)
    sendOuts.each { |idx, pk| @m.ev(:sale, lado: idx & 1, pk: resumen_pk(pk, @battle.battlers[idx])) }
  end

  def pbChangePokemon(idx, pk)
    b = idx.respond_to?(:index) ? idx : @battle.battlers[idx]
    @m.ev(:forma, lado: b.index & 1, pk: resumen_pk(pk, b))
  end

  def pbRefreshOne(idx)
    b = @battle.battlers[idx]
    @m.ev(:ficha, lado: idx & 1, ps: b.hp, max: b.totalhp, estado: b.status.to_s.downcase) if b && b.pokemon
  end

  def pbRefresh = @battle.battlers.each_with_index { |b, i| pbRefreshOne(i) if b }
  def pbShowAbilitySplash(battler, delay = false, logTrigger = true) = @m.ev(:habilidad, lado: battler.index & 1, nombre: battler.abilityName)
  def pbReplaceAbilitySplash(battler) = pbShowAbilitySplash(battler)
  def pbHideAbilitySplash(battler); end
  def pbEndBattle(result); end

  def method_missing(n, *a, **k, &b) = Relleno.new     # lo que añaden los plugins de Ostinato a la escena
  def respond_to_missing?(*) = true
end

# --- el combate en línea: los dos lados los deciden personas (por el Mando), ninguno la IA ---
class BatallaRed < Battle
  attr_accessor :mando

  def pbOwnedByPlayer?(idxBattler) = super   # el lado 0 es «el jugador» para el motor; los textos van con marcas

  def pbHasMegaRing?(idxBattler) = true

  def pbCommandPhaseLoop(isPlayer)
    lado = isPlayer ? 0 : 1
    @battlers.each_with_index do |b, idx|
      break if decided?
      next if !b || (idx & 1) != lado
      next if b.effects[PBEffects::Commanding] >= 0
      next if @choices[idx][0] != :None || !pbCanShowCommands?(idx)
      loop do
        a = @mando.pedir(lado, :accion)
        break if registrar(idx, lado, a)
      end
    end
  end

  def registrar(idx, lado, a)
    case a['tipo']
    when 'rendirse'
      @mando.ev(:msg, txt: "\u0005#{lado}\u0002")      # «X se ha rendido»
      @decision = lado == 0 ? Outcome::LOSE : Outcome::WIN
      return true
    when 'cambio'
      i = a['i'].to_i
      if puede_salir?(idx, i) && pbCanSwitch?(idx, i, nil)
        pbRegisterSwitch(idx, i)
        return true
      end
      @mando.error[lado] = 'No puedes cambiar a ese Pokémon ahora.'
      return false
    else
      if !pbCanShowFightMenu?(idx)
        return pbAutoChooseMove(idx)
      end
      i = a['i'].to_i
      if pbCanChooseMove?(idx, i, false) && pbRegisterMove(idx, i, false)
        pbRegisterMegaEvolution(idx) if a['mega'] && pbCanMegaEvolve?(idx)
        return true
      end
      @mando.error[lado] = 'No puedes usar ese movimiento ahora.'
      return false
    end
  end

  def puede_salir?(idx, i)
    party = pbParty(idx)
    return false if i < 0 || i >= party.length || !party[i] || party[i].egg? || party[i].fainted?
    return false if pbFindBattler(i, idx)
    true
  end

  def pbSwitchInBetween(idxBattler, checkLaxOnly = false, canCancel = false)
    lado = idxBattler & 1
    loop do
      a = @mando.pedir(lado, :cambio)
      if a['tipo'] == 'rendirse'
        @mando.ev(:msg, txt: "\u0005#{lado}\u0002")
        @decision = lado == 0 ? Outcome::LOSE : Outcome::WIN
        # devuelve alguien válido para que el motor siga hasta ver que ya está decidido
        return pbParty(idxBattler).each_index.find { |j| puede_salir?(idxBattler, j) } || -1
      end
      i = a['i'].to_i
      return i if puede_salir?(idxBattler, i)
      @mando.error[lado] = 'Ese Pokémon no puede salir.'
    end
  end

  # sin mensajes de dinero ni de «has perdido»: el final lo dice Pokelocke
  def pbEndOfBattle = @decision
end

# las salidas y retiradas, desde cada lado
class Battle
  def pbMessagesOnReplace(idxBattler, idxParty)
    @mando&.ev(:msg, txt: "\u0004#{idxBattler & 1}S#{pbParty(idxBattler)[idxParty].name}\u0002")
  end

  def pbMessageOnRecall(battler)
    @mando&.ev(:msg, txt: "\u0004#{battler.index & 1}R#{battler.name}\u0002")
  end
end

# --- los Pokémon de la partida, con lo que manda Pokelocke (ya en los nombres internos de Essentials) ---
STATS_PK6 = %i[HP ATTACK DEFENSE SPEED SPECIAL_ATTACK SPECIAL_DEFENSE]
def crear_pokemon(d)
  pk = Pokemon.new(d['especie'].to_sym, d['nivel'].to_i)
  pk.form = d['forma'].to_i if d['forma']
  pk.name = d['mote'] if d['mote'] && !d['mote'].empty?
  pk.gender = d['genero'].to_i if d['genero'] && d['genero'].to_i < 2
  pk.shiny = !!d['shiny']
  pk.nature = d['naturaleza'].to_sym if d['naturaleza'] && GameData::Nature.exists?(d['naturaleza'].to_sym)
  pk.ability = d['habilidad'].to_sym if d['habilidad'] && GameData::Ability.exists?(d['habilidad'].to_sym)
  pk.item = d['objeto'].to_sym if d['objeto'] && GameData::Item.exists?(d['objeto'].to_sym)
  (d['ivs'] || []).each_with_index { |v, k| pk.iv[STATS_PK6[k]] = v.to_i }
  (d['evs'] || []).each_with_index { |v, k| pk.ev[STATS_PK6[k]] = v.to_i }
  movs = (d['ataques'] || []).map(&:to_sym).select { |m| GameData::Move.exists?(m) }
  pk.forget_all_moves
  movs.each_with_index do |m, k|
    mv = Pokemon::Move.new(m)
    mv.ppup = (d['pp_up'] || [])[k].to_i
    mv.pp = mv.total_pp
    pk.moves << mv
  end
  pk.calc_stats
  pk.heal
  pk
end

def vista(m, lado)
  bat = m.batalla
  yo = bat.battlers[lado]
  el = bat.battlers[1 - lado]
  party = bat.pbParty(lado)
  activo = yo ? yo.pokemonIndex : 0
  equipo = party.each_with_index.map do |pk, i|
    b = (i == activo && yo) ? yo : nil
    r = resumen_pk(pk, b)
    r[:habilidad] = (b ? b.abilityName : pk.ability&.name).to_s
    r[:objeto] = (b ? b.itemName : pk.item&.name).to_s
    r[:st] = b ? {atk: b.attack, def: b.defense, spa: b.spatk, spd: b.spdef, spe: b.speed} :
                 {atk: pk.attack, def: pk.defense, spa: pk.spatk, spd: pk.spdef, spe: pk.speed}
    movs = b ? b.moves : pk.moves.map { |mv| Battle::Move.from_pokemon_move(bat, mv) }
    r[:ataques] = movs.each_with_index.map do |mv, k|
      g = GameData::Move.get(mv.id)
      efic = nil
      if el && !el.fainted? && g.category < 2
        efic = Effectiveness.calculate(mv.pbCalcType(b || yo), *el.pbTypes(true)).to_f rescue nil   # ya es el multiplicador (×2, ×0,5...)
      end
      {id: mv.id.to_s, nombre: g.name, tipo: g.type.to_s, cat: %w[F E S][g.category], potencia: g.power, precision: g.accuracy,
       pp: mv.pp, max: mv.total_pp, desc: g.description, efic: efic,
       elegible: b ? bat.pbCanChooseMove?(yo.index, k, false) : true}
    end
    r
  end
  st = yo ? yo.stages : {}
  cambios = {atk: st[:ATTACK], def: st[:DEFENSE], spa: st[:SPECIAL_ATTACK], spd: st[:SPECIAL_DEFENSE], spe: st[:SPEED],
             acc: st[:ACCURACY], eva: st[:EVASION]}.transform_values(&:to_i)
  rival = el ? resumen_pk(el.pokemon, el) : nil
  if el
    s2 = el.stages
    rival[:cambios] = {atk: s2[:ATTACK], def: s2[:DEFENSE], spa: s2[:SPECIAL_ATTACK], spd: s2[:SPECIAL_DEFENSE], spe: s2[:SPEED],
                       acc: s2[:ACCURACY], eva: s2[:EVASION]}.transform_values(&:to_i)
  end
  {lado: lado, turno: bat.turnCount, activo: activo, equipo: equipo, cambios: cambios, rival: rival,
   stats: equipo[activo] ? equipo[activo][:st].merge(hp: equipo[activo][:max]) : {},
   rival_bolas: bat.pbParty(1 - lado).map { |pk| pk.fainted? ? 'debil' : (pk.status != :NONE ? 'estado' : 'bola') },
   puede_cambiar: yo ? (bat.pbCanSwitchOut?(yo.index) rescue true) : true,
   mega: yo ? (bat.pbCanMegaEvolve?(yo.index) rescue false) : false}
end

def espera_de(m)
  return [nil, nil] if m.fin
  bat = m.batalla
  (0..1).map do |lado|
    next 'cambio' if m.espera[lado] == :cambio
    next 'accion' if m.espera[lado] == :accion
    # en la fase de órdenes, el otro lado también puede ir eligiendo aunque el motor aún no le haya preguntado
    if bat.instance_variable_get(:@command_phase) && m.pendiente[lado].nil?
      b = bat.battlers[lado]
      next 'accion' if b && !b.fainted? && bat.choices[lado][0] == :None && bat.pbCanShowCommands?(lado)
    end
    nil
  end
end

COMBATES = {}
VISTO = Hash.new(0)

def seguir(m)
  return if m.fin || !m.fibra.alive?
  m.fibra.resume
  if !m.fibra.alive?
    d = m.batalla.decision
    m.fin = d == Battle::Outcome::WIN ? 0 : d == Battle::Outcome::LOSE ? 1 : 'empate'
    m.ev(:fin, ganador: m.fin)
  end
rescue Exception => e
  m.fin = 'error'
  m.ev(:msg, txt: "Error del motor: #{e.class}: #{e.message}")
  m.ev(:fin, ganador: nil)
  $stderr.puts "#{e.class}: #{e.message}\n#{e.backtrace.first(12).join("\n")}"
end

def respuesta(id, m)
  desde = VISTO[id]
  VISTO[id] = m.log.length
  {ok: true, id: id, n: m.log.length, log: m.log[desde..] || [], fin: m.fin, espera: espera_de(m),
   vistas: [vista(m, 0), vista(m, 1)], errores: m.error.dup.tap { m.error = [nil, nil] }}
end

def orden(o)
  id = o['id']
  case o['cmd']
  when 'hola'
    return {ok: true, errores_carga: ERR.size}
  when 'nuevo'
    m = Mando.new
    m.error = [nil, nil]
    equipos = o['equipos'].map { |e| e.map { |d| crear_pokemon(d) } }
    tipo = GameData::TrainerType.keys.first
    entrenadores = o['jugadores'].each_with_index.map { |n, k| t = NPCTrainer.new(n, tipo); t.party = equipos[k]; t }
    bat = BatallaRed.new(EscenaRed.new(m), equipos[0], equipos[1], [entrenadores[0]], [entrenadores[1]])
    bat.mando = m
    bat.internalBattle = false


    normas = o['normas'] || {}
    bat.rules['sleepclause'] = true if normas['sleep']
    bat.rules['evasionclause'] = true
    bat.rules['ohkoclause'] = true
    bat.rules['speciesclause'] = true if normas['species']
    m.batalla = bat
    m.fibra = Fiber.new { bat.pbStartBattle }
    COMBATES[id] = m
    seguir(m)
    return respuesta(id, m)
  when 'accion'
    m = COMBATES[id] or return {ok: false, error: 'Ese combate no existe'}
    lado = o['lado'].to_i
    e = espera_de(m)[lado]
    return {ok: false, error: 'Ahora no te toca elegir'} if !e && o['accion']['tipo'] != 'rendirse'
    m.pendiente[lado] = o['accion']
    seguir(m) if m.espera[lado] || o['accion']['tipo'] == 'rendirse' && m.espera.any?
    return respuesta(id, m)
  when 'ver'
    m = COMBATES[id] or return {ok: false, error: 'Ese combate no existe'}
    VISTO[id] = 0 if o['todo']
    return respuesta(id, m)
  when 'cerrar'
    COMBATES.delete(id)
    VISTO.delete(id)
    return {ok: true}
  end
  {ok: false, error: 'Orden desconocida'}
end

PROTOCOLO.puts JSON.generate({ok: true, listo: true, errores_carga: ERR.size})
$stdin.each_line do |linea|
  begin
    r = orden(JSON.parse(linea))
  rescue Exception => e
    r = {ok: false, error: "#{e.class}: #{e.message}"}
    $stderr.puts e.backtrace.first(8).join("\n")
  end
  PROTOCOLO.puts JSON.generate(r)
end
