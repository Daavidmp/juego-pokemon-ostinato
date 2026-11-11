import com.dabomstew.pkrandom.FileFunctions;
import com.dabomstew.pkrandom.Randomizer;
import com.dabomstew.pkrandom.Settings;
import com.dabomstew.pkrandom.ctr.AMX;
import com.dabomstew.pkrandom.ctr.GARCArchive;
import com.dabomstew.pkrandom.pokemon.Encounter;
import com.dabomstew.pkrandom.pokemon.Evolution;
import com.dabomstew.pkrandom.pokemon.ItemList;
import com.dabomstew.pkrandom.pokemon.EvolutionType;
import com.dabomstew.pkrandom.pokemon.MegaEvolution;
import com.dabomstew.pkrandom.pokemon.EncounterSet;
import com.dabomstew.pkrandom.pokemon.Move;
import com.dabomstew.pkrandom.pokemon.MoveLearnt;
import com.dabomstew.pkrandom.pokemon.Pokemon;
import com.dabomstew.pkrandom.pokemon.StaticEncounter;
import com.dabomstew.pkrandom.pokemon.Trainer;
import com.dabomstew.pkrandom.pokemon.TrainerPokemon;
import com.dabomstew.pkrandom.romhandlers.Abstract3DSRomHandler;
import com.dabomstew.pkrandom.romhandlers.Gen6RomHandler;
import com.dabomstew.pkrandom.romhandlers.RomHandler;

import java.io.FileInputStream;
import java.io.PrintStream;
import java.lang.reflect.Method;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
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
 *    (las MT de 70 de potencia o más se cambian por otras de menos de 70 antes de guardar las dos: son las mismas
 *    en las dos fases)
 */
public class MegaFases {
    static final int MAX_POTENCIA_RIVAL = 70;     // rivales: iguales o menores de 70
    static final int MAX_POTENCIA_MT = 69;        // MT: inferiores de 70
    static final int MAX_ESPECIE = 721;
    static final int NIVEL_INTERCAMBIO = 40, HUNTAIL = 367, GOREBYSS = 368;

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
        int torre = indiceTorreMaestra(rh);                     // antes de randomizar: aun es el Lucario
        try (PrintStream log = new PrintStream(registro, "UTF-8")) {
            new Randomizer(s, rh, textos, true).randomize(completa, log);
        }
        try {
            intercambioANivel(rh);
            regalosAleatorios(rh, azar, registro);
            combatesImportantes(rh, azar);
            asMegaTrasCuartaMedalla(rh, azar);
            megaTorreMaestra(rh, azar, torre, registro);
            // mtSuaves(rh, azar);   // 1.3.0: las MT ya no se rebajan (David: al azar sin limite, el UPR las sortea con tmsMod)
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

    // ---------- la mega de la Torre Maestra ----------
    static final int LUCARIO = 448;

    /** En que posicion de la lista de regalos y encuentros fijos esta el Lucario que da Corelia en la Torre Maestra. */
    static int indiceTorreMaestra(RomHandler rh) {
        List<StaticEncounter> fijos = rh.getStaticPokemon();
        for (int i = 0; i < fijos.size(); i++) if (fijos.get(i).pkmn != null && fijos.get(i).pkmn.number == LUCARIO) return i;
        return -1;
    }

    /** El regalo de la Torre Maestra (tras la 3.a medalla): un Pokemon al azar NO legendario que pueda megaevolucionar,
     *  con su megapiedra equipada (en el juego original, Lucario con la Lucarionita). El UPR cambiaba solo la especie y
     *  dejaba la Lucarionita (salio Latios con Lucarionita). 1.3.1, lo pidio David. */
    static void megaTorreMaestra(RomHandler rh, Random azar, int indice, String registro) throws Exception {
        if (indice < 0) { System.out.println("Torre Maestra: no se encuentra el regalo"); return; }
        List<MegaEvolution> megas = new ArrayList<>();
        for (Pokemon p : rh.getPokemon())
            if (p != null && p.number <= MAX_ESPECIE && !p.isLegendary() && p.megaEvolutionsFrom != null)
                for (MegaEvolution m : p.megaEvolutionsFrom) if (m.argument > 0) megas.add(m);
        if (megas.isEmpty()) { System.out.println("Torre Maestra: no hay megas"); return; }
        MegaEvolution m = megas.get(azar.nextInt(megas.size()));
        List<StaticEncounter> fijos = rh.getStaticPokemon();
        StaticEncounter regalo = fijos.get(indice);
        regalo.pkmn = m.from;
        regalo.forme = 0;
        regalo.heldItem = m.argument;
        rh.setStaticPokemon(fijos);
        StaticEncounter leido = rh.getStaticPokemon().get(indice);
        String[] objetos = rh.getItemNames();
        String linea = "Torre Maestra: " + leido.pkmn.name + " con " + objetos[leido.heldItem] + " equipada";
        System.out.println(linea);
        Files.write(Paths.get(registro), ("\n--Pokelocke: la mega de la Torre Maestra--\n" + linea + "\n").getBytes(StandardCharsets.UTF_8),
                StandardOpenOption.APPEND);
    }

    /** Las evoluciones por intercambio, con o sin objeto, pasan a ser por nivel: nadie tiene con quién cambiar en
     *  mitad de un locke. Clamperl tiene dos: como las dos serían al mismo nivel, el sexo decide cuál. */
    static void intercambioANivel(RomHandler rh) {
        for (Pokemon p : rh.getPokemon()) {
            if (p == null) continue;
            for (Evolution e : p.evolutionsFrom) {
                if (e.type != EvolutionType.TRADE && e.type != EvolutionType.TRADE_ITEM && e.type != EvolutionType.TRADE_SPECIAL) continue;
                e.type = e.to.number == HUNTAIL ? EvolutionType.LEVEL_MALE_ONLY
                        : e.to.number == GOREBYSS ? EvolutionType.LEVEL_FEMALE_ONLY : EvolutionType.LEVEL;
                e.extraInfo = e.level = NIVEL_INTERCAMBIO;
            }
        }
    }

    // Los regalos de NPC y entrenadores no los toca el UPR: están en los guiones de cada zona (a/0/1/2, comprimidos dentro
    // de cada archivo). Todos llaman a la misma función del guion con (cantidad, 1, objeto): push.c objeto, push.c 12, call.
    static final String ZONAS = "a/0/1/2";
    static final int PUSH_C = 0xBC, CALL = 0x31, RET_ARGS = 0x000C00BC;
    static final int TM_MIN = 328, TM_MAX = 419, MO_MIN = 420, MO_MAX = 425, MEGA_MIN = 656, MEGA_MAX = 685;
    // no se cambian aunque el UPR los deje: las ROM de Genesect y los fósiles, que la historia da a elegir
    static final Set<Integer> DE_LA_HISTORIA = Set.of(116, 117, 118, 119, 710, 711);

    static boolean esMT(int o) { return o >= TM_MIN && o <= TM_MAX || o == 618 || o == 619 || o == 620 || o >= 690 && o <= 694; }

    /** Lo que se puede cambiar: los objetos clave, las MO y las megapiedras los pide la historia. */
    static boolean cambiable(ItemList permitidos, int o) {
        return (esMT(o) || permitidos.isAllowed(o)) && !(o >= MO_MIN && o <= MO_MAX) && !(o >= MEGA_MIN && o <= MEGA_MAX) && !DE_LA_HISTORIA.contains(o);
    }

    /** La función de regalar del guion: lee sus argumentos y mete el objeto en la mochila. */
    static boolean esRegalo(ByteBuffer c, int destino) {
        if (destino < 0 || destino % 4 != 0 || destino + 36 > c.capacity()) return false;
        int x = c.getInt(destino + 4);
        return c.getInt(destino) == 0x87 && c.getInt(destino + 8) == 0 && c.getInt(destino + 12) == PUSH_C
                && c.getInt(destino + 16) == 0x000100BC && c.getInt(destino + 20) == 0x87 && c.getInt(destino + 24) == x + 1
                && c.getInt(destino + 28) == 8 && c.getInt(destino + 32) == 0xFFFC00BF;
    }

    static void regalosAleatorios(RomHandler rh, Random azar, String registro) throws Exception {
        Method leer = Abstract3DSRomHandler.class.getDeclaredMethod("readGARC", String.class, boolean.class);
        Method escribir = Abstract3DSRomHandler.class.getDeclaredMethod("writeGARC", String.class, GARCArchive.class);
        leer.setAccessible(true);
        escribir.setAccessible(true);
        GARCArchive zonas = (GARCArchive) leer.invoke(rh, ZONAS, false);
        ItemList permitidos = rh.getAllowedItems();
        String[] nombres = rh.getItemNames();
        List<Integer> mts = new ArrayList<>(), comunes = new ArrayList<>(), bajos = new ArrayList<>();
        for (int o = 1; o < nombres.length; o++) {
            if (esMT(o)) mts.add(o);
            else if (!cambiable(permitidos, o) || !rh.getNonBadItems().isAllowed(o)) continue;
            else if (o >= 16) comunes.add(o);
            else if (o > 1) bajos.add(o);                  // sin la Master Ball
        }
        Collections.shuffle(mts, azar);
        int siguienteMt = 0, cambiados = 0, enteros = 0;
        StringBuilder log = new StringBuilder("\n--Regalos de NPC y entrenadores--\n");
        for (int i = 0; i < zonas.files.size(); i++) {
            for (byte[] d : zonas.files.get(i).values()) {
                if (d == null) continue;
                ByteBuffer b = ByteBuffer.wrap(d).order(ByteOrder.LITTLE_ENDIAN);
                for (int o = 4; o + 4 < d.length; o++) {
                    if ((d[o] & 255) != 0xE0 || (d[o + 1] & 255) != 0xF1 || d[o + 2] != 0x0A || d[o + 3] != 0x0A) continue;
                    int largo = b.getInt(o - 4);
                    if (largo < 32 || o - 4 + largo > d.length) continue;
                    AMX x = new AMX(Arrays.copyOfRange(d, o - 4, o - 4 + largo));
                    byte[] copia = x.decData.clone();
                    ByteBuffer c = ByteBuffer.wrap(x.decData).order(ByteOrder.LITTLE_ENDIAN);
                    StringBuilder aqui = new StringBuilder();
                    int enEste = 0;
                    for (int w = 8; w + 16 <= x.decData.length; w += 4) {
                        int v = c.getInt(w);
                        if ((v & 0xFFFF) != PUSH_C || c.getInt(w + 4) != RET_ARGS || c.getInt(w + 8) != CALL) continue;
                        if (!esRegalo(c, w + 12 + c.getInt(w + 12))) continue;
                        int viejo = v >>> 16;
                        if (viejo == 0 || !cambiable(permitidos, viejo)) continue;
                        // el guion va comprimido: un número de menos de 16 ocupa un byte menos y no cabría igual
                        int nuevo;
                        if (esMT(viejo)) nuevo = mts.get(siguienteMt++ % mts.size());
                        else if (viejo < 16) nuevo = bajos.get(azar.nextInt(bajos.size()));
                        else nuevo = comunes.get(azar.nextInt(comunes.size()));
                        c.putInt(w, (nuevo << 16) | PUSH_C);
                        aqui.append(nombres[viejo]).append(" -> ").append(nombres[nuevo]).append('\n');
                        enEste++;
                    }
                    if (enEste == 0) continue;
                    byte[] nuevoAmx = x.getBytes();
                    // mismo tamaño o no se toca: detrás van otros guiones de la zona
                    if (nuevoAmx.length != largo) {
                        enteros += enEste;
                        continue;
                    }
                    byte[] prueba = new AMX(nuevoAmx).decData;
                    if (!Arrays.equals(prueba, x.decData) || prueba.length != copia.length) {
                        throw new IllegalStateException("Un guion no se relee igual en el archivo " + i);
                    }
                    System.arraycopy(nuevoAmx, 0, d, o - 4, largo);
                    cambiados += enEste;
                    log.append(aqui);
                }
            }
        }
        escribir.invoke(rh, ZONAS, zonas);
        log.append("Cambiados: ").append(cambiados).append(", sin cambiar por tamano: ").append(enteros).append('\n');
        Files.write(Paths.get(registro), log.toString().getBytes(StandardCharsets.UTF_8), StandardOpenOption.APPEND);
        System.out.println("Regalos cambiados: " + cambiados + " · sin cambiar por tamaño: " + enteros);
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

        int salvajesFinales = 0;
        for (EncounterSet zona : zonas) for (Encounter e : zona.encounters) if (!debil(e.pokemon)) salvajesFinales++;
        System.out.println("salvajes que ya no pueden evolucionar: " + salvajesFinales);
    }

    /** Las MT de 70 de potencia o más se cambian por otras de menos de 70. Se hace antes de guardar las dos fases: las
     *  MT son las mismas toda la partida y no cambian al abrir la randomización completa (2.ª medalla). */
    static void mtSuaves(RomHandler rh, Random azar) {
        List<Move> movs = rh.getMoves();
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
        System.out.println("MT de 70 o más que quedan: " + fuertes + " de " + mts.size());
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
