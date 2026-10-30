import com.dabomstew.pkrandom.pokemon.Encounter;
import com.dabomstew.pkrandom.pokemon.EncounterSet;
import com.dabomstew.pkrandom.pokemon.Evolution;
import com.dabomstew.pkrandom.pokemon.EvolutionType;
import com.dabomstew.pkrandom.pokemon.MegaEvolution;
import com.dabomstew.pkrandom.pokemon.Move;
import com.dabomstew.pkrandom.pokemon.MoveLearnt;
import com.dabomstew.pkrandom.pokemon.Pokemon;
import com.dabomstew.pkrandom.pokemon.Trainer;
import com.dabomstew.pkrandom.pokemon.TrainerPokemon;
import com.dabomstew.pkrandom.romhandlers.RomHandler;

import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * Simulación de MegaFases con una ROM inventada (sin Pokémon Y): un RomHandler falso con unos pocos Pokémon con sus
 * números de la Pokédex de verdad (para que isLegendary del UPR funcione), megaevoluciones, movimientos y los
 * entrenadores importantes de la historia con sus niveles ya con el +15 %. Pasa por los tres pasos de verdad
 * (equipos de 6, ases con megaevolución tras Amaro, fase fácil) y comprueba lo que tiene que pasar.
 *   javac -cp PokeRandoZX.jar -d clases MegaFases.java PruebaMegaFases.java
 *   java -cp PokeRandoZX.jar;clases PruebaMegaFases
 */
public class PruebaMegaFases {
    static final List<Pokemon> pokemon = new ArrayList<>(Arrays.asList(new Pokemon[800]));
    static final List<Move> movs = new ArrayList<>();
    static final Map<Integer, List<MoveLearnt>> aprende = new HashMap<>();
    static final List<MegaEvolution> megas = new ArrayList<>();
    static List<Trainer> entrenadores = new ArrayList<>();
    static List<EncounterSet> zonas = new ArrayList<>();
    static List<Integer> mts = new ArrayList<>();
    static int fallos = 0;

    static Pokemon especie(int n, String nombre) {
        Pokemon p = new Pokemon();
        p.number = n; p.name = nombre;
        pokemon.set(n, p);
        aprende.put(n, new ArrayList<>(List.of(ml(33, 1), ml(52, 10), ml(89, 30), ml(94, 45), ml(2, 20), ml(69, 25))));
        return p;
    }

    static MoveLearnt ml(int mov, int nivel) {
        MoveLearnt m = new MoveLearnt(); m.move = mov; m.level = nivel; return m;
    }

    static void evoluciona(Pokemon de, Pokemon a) {
        Evolution e = new Evolution(de, a, true, EvolutionType.LEVEL, 16);
        de.evolutionsFrom.add(e); a.evolutionsTo.add(e);
    }

    static void mega(Pokemon de, int piedra) {
        Pokemon forma = new Pokemon(); forma.number = de.number; forma.name = de.name + "-Mega"; forma.formeNumber = 1;
        forma.baseForme = de;
        MegaEvolution m = new MegaEvolution(de, forma, 1, piedra);
        de.megaEvolutionsFrom.add(m); megas.add(m);
    }

    static void movimiento(int n, String nombre, int potencia) {
        while (movs.size() <= n) movs.add(null);
        Move m = new Move(); m.number = n; m.name = nombre; m.power = potencia; movs.set(n, m);
    }

    static Trainer entrenador(int indice, String tag, String nombre, boolean movsPropios, Pokemon[] eq, int... niveles) {
        Trainer t = new Trainer();
        t.index = indice; t.tag = tag; t.name = nombre; t.fullDisplayName = nombre;
        t.multiBattleStatus = Trainer.MultiBattleStatus.NEVER;
        t.pokemon = new ArrayList<>();
        for (int i = 0; i < niveles.length; i++) {
            TrainerPokemon tp = new TrainerPokemon();
            tp.pokemon = eq[i % eq.length]; tp.level = niveles[i]; tp.moves = new int[4]; tp.formeSuffix = "";
            t.pokemon.add(tp);
        }
        t.setPokemonHaveCustomMoves(movsPropios);
        entrenadores.add(t);
        return t;
    }

    static void comprobar(boolean ok, String que) {
        System.out.println((ok ? "  OK     " : "  FALLO  ") + que);
        if (!ok) fallos++;
    }

    static String equipo(Trainer t) {
        StringBuilder sb = new StringBuilder();
        for (TrainerPokemon tp : t.pokemon) {
            sb.append(tp.pokemon.name).append(" Nv").append(tp.level);
            if (tp.hasMegaStone) sb.append(" [Megapiedra ").append(tp.heldItem).append(']');
            sb.append(" · ");
        }
        return sb.length() > 3 ? sb.substring(0, sb.length() - 3) : "";
    }

    public static void main(String[] args) throws Exception {
        // --- la ROM inventada ---
        Pokemon bulba = especie(1, "Bulbasaur"), ivy = especie(2, "Ivysaur"), venu = especie(3, "Venusaur");
        Pokemon charm = especie(4, "Charmander"), charme = especie(5, "Charmeleon"), chari = especie(6, "Charizard");
        Pokemon magi = especie(129, "Magikarp"), gyara = especie(130, "Gyarados");
        Pokemon riolu = especie(447, "Riolu"), luca = especie(448, "Lucario");
        Pokemon absol = especie(359, "Absol"), mawile = especie(303, "Mawile"), tauros = especie(128, "Tauros");
        Pokemon fletch = especie(661, "Fletchling"), fletchi = especie(662, "Fletchinder"), talon = especie(663, "Talonflame");
        Pokemon mewtwo = especie(150, "Mewtwo"), xerneas = especie(716, "Xerneas");
        evoluciona(bulba, ivy); evoluciona(ivy, venu); evoluciona(charm, charme); evoluciona(charme, chari);
        evoluciona(magi, gyara); evoluciona(riolu, luca); evoluciona(fletch, fletchi); evoluciona(fletchi, talon);
        mega(venu, 659); mega(chari, 660); mega(gyara, 676); mega(luca, 673); mega(absol, 677); mega(mawile, 681);
        mega(mewtwo, 662);                                       // legendario: nunca debe salir de as
        movimiento(2, "Golpe Kárate", 50); movimiento(33, "Placaje", 40); movimiento(52, "Ascuas", 40);
        movimiento(69, "Sísmico", 1); movimiento(89, "Terremoto", 100); movimiento(94, "Psíquico", 90);
        movimiento(165, "Forcejeo", 50); movimiento(15, "Corte", 50); movimiento(57, "Surf", 90);
        movimiento(85, "Rayo", 90); movimiento(53, "Lanzallamas", 90); movimiento(58, "Rayo Hielo", 90);
        for (int n = 1; n <= 30; n++) if (n < movs.size() && movs.get(n) == null) movimiento(n, "Mov" + n, 20 + n);
        mts = new ArrayList<>(List.of(89, 94, 85, 53, 58, 2));

        EncounterSet ruta = new EncounterSet(); ruta.encounters = new ArrayList<>(); ruta.displayName = "Ruta 2";
        for (Pokemon p : new Pokemon[]{venu, tauros, magi, xerneas, luca}) {
            Encounter e = new Encounter(); e.pokemon = p; e.level = 3; ruta.encounters.add(e);
        }
        zonas.add(ruta);

        Pokemon[] variados = {chari, gyara, tauros, luca, talon, absol};
        // historia de Pokémon Y, con los niveles del juego × 1,15
        Trainer joven = entrenador(10, null, "Joven Austin", false, variados, 6);
        Trainer shauna = entrenador(11, "FRIEND1-0", "Shauna (1.er combate)", false, variados, 6);
        Trainer violeta = entrenador(6, "GYM1-LEADER", "Violeta", true, variados, 12, 14);
        Trainer rivalTorre = entrenador(30, "RIVAL3-0", "Rival · Torre Maestra", false, variados, 32, 35, 32);
        Trainer rivalTempera = entrenador(31, "RIVAL4-0", "Rival · Témpera", false, variados, 36, 36, 38);
        Trainer amaro = entrenador(22, "GYM4-LEADER", "Amaro", true, variados, 35, 39, 36);
        Trainer aliana = entrenador(175, null, "Aliana · Central", false, variados, 44);
        Trainer lem = entrenador(23, "GYM5-LEADER", "Lem", true, variados, 40, 40, 43);
        Trainer rival14 = entrenador(32, "RIVAL5-0", "Rival · Ruta 14", false, variados, 40, 40, 43);
        Trainer guay = entrenador(40, null, "Entrenador guay (normal)", false, variados, 63, 63);
        Trainer doble = entrenador(41, "FRIEND5-0", "Tierno (doble con compañero)", false, variados, 55, 55);
        doble.multiBattleStatus = Trainer.MultiBattleStatus.ALWAYS;
        Trainer malva = entrenador(50, "ELITE1", "Malva", true, variados, 72, 72, 72, 75);
        Trainer dianta = entrenador(55, "CHAMPION", "Dianta", true, variados, 74, 75, 75, 75, 76, 78);

        RomHandler rh = (RomHandler) Proxy.newProxyInstance(RomHandler.class.getClassLoader(), new Class<?>[]{RomHandler.class},
                (proxy, metodo, a) -> switch (metodo.getName()) {
                    case "getPokemon" -> pokemon;
                    case "getMoves" -> movs;
                    case "getMovesLearnt" -> aprende;
                    case "getMegaEvolutions" -> megas;
                    case "getTrainers" -> entrenadores;
                    case "setTrainers" -> { entrenadores = (List<Trainer>) a[0]; yield null; }
                    case "getEncounters" -> zonas;
                    case "setEncounters" -> { zonas = (List<EncounterSet>) a[1]; yield null; }
                    case "getTMMoves" -> new ArrayList<>(mts);
                    case "getHMMoves" -> List.of(15, 57);
                    case "setTMMoves" -> { mts = (List<Integer>) a[0]; yield null; }
                    default -> throw new UnsupportedOperationException(metodo.getName());
                });

        Map<Trainer, Integer> ultimoOriginal = new HashMap<>();
        for (Trainer t : entrenadores) ultimoOriginal.put(t, t.pokemon.get(t.pokemon.size() - 1).level);
        Random azar = new Random(2026);
        System.out.println("\n== 1. Combates importantes con 6 Pokémon ==");
        MegaFases.combatesImportantes(rh, azar);
        System.out.println("\n== 2. Ases con megaevolución después de Amaro ==");
        MegaFases.asMegaTrasCuartaMedalla(rh, azar);

        System.out.println("\n== Versión completa (después de la 2.ª medalla) ==");
        for (Trainer t : entrenadores) System.out.printf("  %-30s %s%n", t.name, equipo(t));

        System.out.println("\n== Comprobaciones ==");
        comprobar(shauna.pokemon.size() == 1, "Shauna (1.er combate) se queda con 1 Pokémon");
        comprobar(joven.pokemon.size() == 1, "un entrenador normal no se toca");
        comprobar(guay.pokemon.size() == 2 && !guay.pokemon.get(1).hasMegaStone, "un entrenador normal de nivel alto tampoco");
        comprobar(doble.pokemon.size() == 2 && !doble.pokemon.get(1).hasMegaStone, "un combate doble con compañero no se toca");
        // el as es el último del equipo original (en Pokémon Y no siempre es el de más nivel: Amaro lleva el Nv 39 en medio)
        for (Trainer t : List.of(violeta, rivalTorre, rivalTempera, amaro, aliana, lem, rival14, malva, dianta)) {
            int as = t.pokemon.get(t.pokemon.size() - 1).level;
            comprobar(t.pokemon.size() == 6 && as == ultimoOriginal.get(t), t.name + ": 6 Pokémon y el as (Nv" + as + ") sigue el último");
        }
        for (Trainer t : List.of(violeta, rivalTorre, rivalTempera, amaro)) {
            comprobar(t.pokemon.stream().noneMatch(x -> x.hasMegaStone), t.name + ": antes de la 4.ª medalla, sin Megapiedra");
        }
        for (Trainer t : List.of(aliana, lem, rival14, malva, dianta)) {
            TrainerPokemon as = t.pokemon.get(t.pokemon.size() - 1);
            comprobar(as.hasMegaStone && as.canMegaEvolve() && !as.pokemon.isLegendary() && t.pokemonHaveItems(),
                    t.name + ": el as (" + as.pokemon.name + ") megaevoluciona con su Megapiedra y no es legendario");
        }
        comprobar(rivalTempera.pokemon.get(5).level == 38 && lem.pokemon.get(5).level == 43, "el as conserva su nivel");

        System.out.println("\n== 3. Fase fácil (hasta la 2.ª medalla) ==");
        MegaFases.faseFacil(rh, azar);
        for (Trainer t : List.of(violeta, lem)) System.out.printf("  %-30s %s%n", t.name, equipo(t));
        boolean todosDebiles = entrenadores.stream().flatMap(t -> t.pokemon.stream()).allMatch(x -> MegaFases.debil(x.pokemon));
        comprobar(todosDebiles, "fase fácil: todos los Pokémon de los entrenadores aún pueden evolucionar");
        boolean flojos = entrenadores.stream().flatMap(t -> t.pokemon.stream()).flatMapToInt(x -> Arrays.stream(x.moves))
                .filter(m -> m > 0).allMatch(m -> movs.get(m).power <= 70 && movs.get(m).power != 1);
        comprobar(flojos, "fase fácil: ningún ataque de los entrenadores pasa de 70 ni es de daño fijo");
        comprobar(zonas.get(0).encounters.stream().allMatch(e -> MegaFases.debil(e.pokemon)), "fase fácil: salvajes que aún evolucionan (ni Xerneas)");
        comprobar(mts.stream().allMatch(m -> movs.get(m).power < 70), "fase fácil: MT de menos de 70");

        System.out.println(fallos == 0 ? "\nTodo bien." : "\n" + fallos + " comprobaciones fallan.");
        System.exit(fallos == 0 ? 0 : 1);
    }
}
