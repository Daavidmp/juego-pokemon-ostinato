import com.dabomstew.pkrandom.FileFunctions;
import com.dabomstew.pkrandom.Randomizer;
import com.dabomstew.pkrandom.Settings;
import com.dabomstew.pkrandom.pokemon.Encounter;
import com.dabomstew.pkrandom.pokemon.MegaEvolution;
import com.dabomstew.pkrandom.pokemon.EncounterSet;
import com.dabomstew.pkrandom.pokemon.Move;
import com.dabomstew.pkrandom.pokemon.MoveLearnt;
import com.dabomstew.pkrandom.pokemon.Pokemon;
import com.dabomstew.pkrandom.pokemon.Trainer;
import com.dabomstew.pkrandom.pokemon.TrainerPokemon;
import com.dabomstew.pkrandom.romhandlers.Gen6RomHandler;
import com.dabomstew.pkrandom.romhandlers.RomHandler;

import java.io.FileInputStream;
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.ResourceBundle;
import java.util.Set;

/**
 * Mega Pokelocke: una randomización y dos juegos.
 *   java -cp PokeRandoZX.jar MegaFases.java rom ajustes.rnqs salida_completa salida_facil registro.log
 * 1. Randomiza la ROM con los ajustes, pone 6 Pokémon en los combates importantes (rivales, líderes, villanos
 *    con nombre; el primero contra Shauna se queda con 1), y a partir de la 4.ª medalla su último Pokémon es uno
 *    con megaevolución y su Megapiedra. La guarda en salida_completa.
 * 2. Sobre esa misma randomización aplica la fase fácil (hasta la segunda medalla) y la guarda en salida_facil:
 *    - entrenadores y salvajes solo con Pokémon que aún pueden evolucionar: una evolución final pasa a su
 *      preevolución y uno que no evoluciona (o un legendario) se cambia por uno al azar que sí pueda
 *    - los Pokémon de los entrenadores solo usan movimientos de 70 de potencia o menos (o de estado), sin los
 *      de daño variable o fijo, que el UPR apunta con potencia 1
 *    - las MT de 70 de potencia o más se cambian por otras de menos de 70
 */
public class MegaFases {
    static final int MAX_POTENCIA_RIVAL = 70;     // rivales: iguales o menores de 70
    static final int MAX_POTENCIA_MT = 69;        // MT: inferiores de 70
    static final int MAX_ESPECIE = 721;

    public static void main(String[] args) throws Exception {
        String rom = args[0], ajustes = args[1], completa = args[2], facil = args[3], registro = args[4];
        Settings s;
        try (FileInputStream in = new FileInputStream(ajustes)) {
            s = Settings.read(in);
        }
        s.setCustomNames(FileFunctions.getCustomNames());
        Random azar = new Random();
        RomHandler rh = new Gen6RomHandler.Factory().create(azar);
        if (!rh.loadRom(rom)) {
            throw new IllegalStateException("No se ha podido abrir la ROM: " + rom);
        }
        ResourceBundle textos = ResourceBundle.getBundle("com/dabomstew/pkrandom/newgui/Bundle");
        try (PrintStream log = new PrintStream(registro, "UTF-8")) {
            new Randomizer(s, rh, textos, true).randomize(completa, log);
        }
        try {
            combatesImportantes(rh, azar);
            asMegaTrasCuartaMedalla(rh, azar);
            if (!rh.saveRomDirectory(completa)) {
                throw new IllegalStateException("No se ha podido guardar la versión completa");
            }
            faseFacil(rh, azar);
            if (!rh.saveRomDirectory(facil)) {
                throw new IllegalStateException("No se ha podido guardar la fase fácil");
            }
        } finally {
            // la ROM se abre en una carpeta temporal junto al .jar (tmp_<juego>): el CLI la borra al acabar
            ((com.dabomstew.pkrandom.romhandlers.Abstract3DSRomHandler) rh).closeInnerRom();
        }
        System.out.println("Hecho");
    }

    // Pokémon Y: combates contra villanos y amigos con nombre que no llevan etiqueta propia en el UPR (índices
    // de entrenador de la ROM, los mismos en todos los idiomas): Tierno 324 y 573, Trevor 325, Aliana 175 y 344,
    // Xerosic 345, Mable 346 y 347, Celosia 349, Bryony 351. Los «Team Flare Admin» sin nombre son secuaces
    static final Set<Integer> VILLANOS_Y_AMIGOS = Set.of(324, 573, 325, 175, 344, 345, 346, 347, 349, 351);

    /** Rivales, líderes, Alto Mando, campeona, Lysandre y los villanos con nombre: equipo de 6. El primer
     *  combate contra Shauna (FRIEND1) se queda con 1. Los combates dobles con compañero no se tocan. */
    static void combatesImportantes(RomHandler rh, Random azar) {
        List<Pokemon> relleno = new ArrayList<>();
        for (Pokemon p : rh.getPokemon()) {
            if (p != null && p.number <= MAX_ESPECIE && !p.isLegendary()) relleno.add(p);
        }
        Map<Integer, List<MoveLearnt>> aprende = rh.getMovesLearnt();
        List<Move> movs = rh.getMoves();
        List<Trainer> entrenadores = rh.getTrainers();
        int cambiados = 0;
        for (Trainer t : entrenadores) {
            if (t.multiBattleStatus == Trainer.MultiBattleStatus.ALWAYS || t.pokemon.isEmpty()) continue;
            String tag = t.tag == null ? "" : t.tag;
            if (tag.startsWith("FRIEND1")) {
                while (t.pokemon.size() > 1) t.pokemon.remove(t.pokemon.size() - 1);
                continue;
            }
            if (!importante(t) || t.pokemon.size() >= 6) continue;
            int nivel = Integer.MAX_VALUE;                         // los nuevos, al nivel del más bajo: el as
            for (TrainerPokemon tp : t.pokemon) nivel = Math.min(nivel, tp.level);   // sigue siendo el más alto
            while (t.pokemon.size() < 6) {
                TrainerPokemon nuevo = t.pokemon.get(0).copy();
                nuevo.pokemon = relleno.get(azar.nextInt(relleno.size()));
                nuevo.level = nivel; nuevo.heldItem = 0; nuevo.hasMegaStone = false;
                nuevo.forme = 0; nuevo.formeSuffix = ""; nuevo.abilitySlot = 0;
                nuevo.moves = t.pokemonHaveCustomMoves() ? movimientos(nuevo.pokemon, nivel, aprende, movs, Integer.MAX_VALUE)
                        : new int[4];
                t.pokemon.add(t.pokemon.size() - 1, nuevo);            // el as sigue saliendo el último
            }
            cambiados++;
        }
        rh.setTrainers(entrenadores, false);
        System.out.println("Combates importantes con 6 Pokémon: " + cambiados);
    }

    /** Rivales, amigos, líderes, Alto Mando, campeona, Lysandre y los villanos con nombre. */
    static boolean importante(Trainer t) {
        String tag = t.tag == null ? "" : t.tag;
        return t.isBoss() || tag.startsWith("RIVAL") || tag.startsWith("FRIEND") || VILLANOS_Y_AMIGOS.contains(t.index);
    }

    /** Después de la 4.ª medalla (Amaro), el as de cada combate importante es un Pokémon con megaevolución y lleva su
     *  Megapiedra. «Después» = algún Pokémon por encima del más alto de Amaro (ya con el +15 %): así entran el rival
     *  de la Ruta 14, Lem y el resto, y no el rival de Témpera ni el propio Amaro. Se queda el nivel del as. */
    static void asMegaTrasCuartaMedalla(RomHandler rh, Random azar) {
        List<Trainer> entrenadores = rh.getTrainers();
        int tope = 0;
        for (Trainer t : entrenadores) {
            if ("GYM4-LEADER".equals(t.tag)) for (TrainerPokemon tp : t.pokemon) tope = Math.max(tope, tp.level);
        }
        if (tope == 0) throw new IllegalStateException("No encuentro a Amaro (GYM4-LEADER)");
        List<MegaEvolution> megas = new ArrayList<>();          // solo las de Megapiedra y de no legendarios
        for (MegaEvolution m : rh.getMegaEvolutions()) {
            if (m.argument > 0 && m.from != null && m.from.number <= MAX_ESPECIE && !m.from.isLegendary()) megas.add(m);
        }
        if (megas.isEmpty()) throw new IllegalStateException("La ROM no tiene megaevoluciones");
        Map<Integer, List<MoveLearnt>> aprende = rh.getMovesLearnt();
        List<Move> movs = rh.getMoves();
        int cambiados = 0;
        for (Trainer t : entrenadores) {
            if (t.multiBattleStatus == Trainer.MultiBattleStatus.ALWAYS || t.pokemon.isEmpty() || !importante(t)) continue;
            int max = 0;
            for (TrainerPokemon tp : t.pokemon) max = Math.max(max, tp.level);
            if (max <= tope) continue;
            TrainerPokemon as = t.pokemon.get(t.pokemon.size() - 1);
            MegaEvolution m = megas.get(azar.nextInt(megas.size()));
            as.pokemon = m.from;
            as.heldItem = m.argument;
            as.hasMegaStone = true;
            as.forme = 0; as.formeSuffix = ""; as.abilitySlot = 0;
            if (t.pokemonHaveCustomMoves()) as.moves = movimientos(as.pokemon, as.level, aprende, movs, Integer.MAX_VALUE);
            t.setPokemonHaveItems(true);
            cambiados++;
        }
        rh.setTrainers(entrenadores, false);
        System.out.println("Combates importantes con el as megaevolucionable: " + cambiados + " (después de Amaro, nivel > " + tope + ")");
    }

    static boolean debil(Pokemon p) {
        return p != null && p.number <= MAX_ESPECIE && !p.evolutionsFrom.isEmpty();
    }

    /** La preevolución si la tiene y vale; si no, uno al azar que aún pueda evolucionar. */
    static Pokemon debilitar(Pokemon p, List<Pokemon> debiles, Random azar) {
        if (debil(p)) return p;
        if (p != null && !p.evolutionsTo.isEmpty()) {
            Pokemon pre = p.evolutionsTo.get(0).from;
            if (debil(pre)) return pre;
        }
        return debiles.get(azar.nextInt(debiles.size()));
    }

    static void faseFacil(RomHandler rh, Random azar) {
        List<Pokemon> debiles = new ArrayList<>();
        for (Pokemon p : rh.getPokemon()) if (debil(p)) debiles.add(p);
        List<Move> movs = rh.getMoves();
        Map<Integer, List<MoveLearnt>> aprende = rh.getMovesLearnt();

        // salvajes
        List<EncounterSet> zonas = rh.getEncounters(false);
        for (EncounterSet zona : zonas) {
            for (Encounter e : zona.encounters) {
                Pokemon nuevo = debilitar(e.pokemon, debiles, azar);
                if (nuevo != e.pokemon) { e.pokemon = nuevo; e.formeNumber = 0; }
            }
        }
        rh.setEncounters(false, zonas);

        // entrenadores: especie y movimientos
        List<Trainer> entrenadores = rh.getTrainers();
        for (Trainer t : entrenadores) {
            for (TrainerPokemon tp : t.pokemon) {
                Pokemon nuevo = debilitar(tp.pokemon, debiles, azar);
                if (nuevo != tp.pokemon) {
                    tp.pokemon = nuevo; tp.forme = 0; tp.formeSuffix = ""; tp.hasMegaStone = false;
                }
                tp.moves = movimientos(tp.pokemon, tp.level, aprende, movs, MAX_POTENCIA_RIVAL);
                tp.resetMoves = false;
            }
            t.setPokemonHaveCustomMoves(true);
        }
        rh.setTrainers(entrenadores, false);
        for (Trainer t : entrenadores) {                          // resumen en la salida: los líderes
            if (t.tag != null && t.tag.matches("GYM[1-8]-LEADER")) {
                StringBuilder sb = new StringBuilder(t.tag + ":");
                for (TrainerPokemon tp : t.pokemon) {
                    sb.append(" ").append(tp.pokemon.name).append(" Nv").append(tp.level).append(" [");
                    for (int m : tp.moves) if (m > 0) sb.append(movs.get(m).name).append(" ").append(movs.get(m).power).append(", ");
                    sb.append("]");
                }
                System.out.println(sb);
            }
        }

        // MT
        List<Integer> mts = new ArrayList<>(rh.getTMMoves());
        Set<Integer> usados = new HashSet<>(mts);
        usados.addAll(rh.getHMMoves());
        List<Integer> suaves = new ArrayList<>();
        for (Move m : movs) {
            if (m != null && m.number <= 621 && m.power > 1 && m.power <= MAX_POTENCIA_MT && !usados.contains(m.number)
                    && m.number != 165) suaves.add(m.number);          // 165: Forcejeo
        }
        for (int i = 0; i < mts.size(); i++) {
            Move m = movs.get(mts.get(i));
            if (m.power > MAX_POTENCIA_MT && !suaves.isEmpty()) {
                mts.set(i, suaves.remove(azar.nextInt(suaves.size())));
            }
        }
        rh.setTMMoves(mts);
        int fuertes = 0;
        for (int m : mts) if (movs.get(m).power > MAX_POTENCIA_MT) fuertes++;
        int salvajesFinales = 0;
        for (EncounterSet zona : zonas) for (Encounter e : zona.encounters) if (!debil(e.pokemon)) salvajesFinales++;
        System.out.println("MT de 70 o más que quedan: " + fuertes + " de " + mts.size()
                + " · salvajes que ya no pueden evolucionar: " + salvajesFinales);
    }

    /** Los 4 últimos que aprende por nivel hasta su nivel, sin los de más de maxPotencia (si hay tope, tampoco
     *  los de daño variable). */
    static int[] movimientos(Pokemon p, int nivel, Map<Integer, List<MoveLearnt>> aprende, List<Move> movs, int maxPotencia) {
        boolean tope = maxPotencia != Integer.MAX_VALUE;
        List<Integer> vistos = new ArrayList<>();
        List<MoveLearnt> lista = aprende.get(p.number);
        if (lista != null) {
            for (MoveLearnt ml : lista) {
                if (ml.level > nivel || ml.move <= 0 || ml.move >= movs.size()) continue;
                Move m = movs.get(ml.move);
                // potencia 1 = daño variable o fijo (Perforador, Contraataque, Furia Dragón…): fuera también
                if (m == null || m.power > maxPotencia || (tope && m.power == 1)) continue;
                vistos.remove(Integer.valueOf(ml.move));
                vistos.add(ml.move);
            }
        }
        if (vistos.isEmpty()) vistos.add(33);                         // Placaje
        int[] out = new int[4];
        List<Integer> ultimos = vistos.subList(Math.max(0, vistos.size() - 4), vistos.size());
        for (int i = 0; i < ultimos.size(); i++) out[i] = ultimos.get(i);
        return out;
    }
}
