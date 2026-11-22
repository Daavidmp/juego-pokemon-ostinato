import com.dabomstew.pkrandom.pokemon.Move;
import com.dabomstew.pkrandom.pokemon.MoveLearnt;
import com.dabomstew.pkrandom.pokemon.Pokemon;
import com.dabomstew.pkrandom.pokemon.Trainer;
import com.dabomstew.pkrandom.pokemon.TrainerPokemon;
import com.dabomstew.pkrandom.romhandlers.Abstract3DSRomHandler;
import com.dabomstew.pkrandom.romhandlers.Gen6RomHandler;
import com.dabomstew.pkrandom.romhandlers.RomHandler;

import java.io.PrintStream;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.stream.Stream;

/**
 * Vuelve a sortear los Pokemon de los entrenadores de una partida que ya existe, con mas probabilidad de que salgan
 * ultimas etapas evolutivas (Pokemon que ya no evolucionan). Peticion de David para la room de Damian (2.2.5):
 *   java -cp PokeRandoZX.jar RivalesFinales rom romfs_del_mod probabilidad_final registro.log
 * Con "primeras" en vez de la probabilidad (2.2.6, todas las rooms Mega): solo cambia los Pokemon de primera etapa
 * (MegaFases.sinPrimeras) y deja los demas.
 * Solo cambia la especie (y sus ataques si el entrenador lleva ataques propios: los 4 ultimos que aprende por nivel
 * con los movimientos de ESA partida). Niveles, objetos y numero de Pokemon se quedan. El as con Megapiedra no se
 * toca (la piedra va con su Pokemon). Sin legendarios. Escribe solo trdata y trpoke (a/0/3/8 y a/0/4/0) del mod.
 * Dice "Hecho N" con los Pokemon cambiados, o "SIN ENTRENADORES".
 */
public class RivalesFinales {
    static final String TRDATA = "a/0/3/8", TRPOKE = "a/0/4/0";

    /** Ultima etapa de una linea evolutiva: viene de otro y ya no evoluciona (Venusaur si; Tauros, que no evoluciona
     *  nunca, no). */
    static boolean final_(Pokemon p) {
        return p.evolutionsFrom.isEmpty() && !p.evolutionsTo.isEmpty();
    }

    public static void main(String[] args) throws Exception {
        String rom = args[0];
        Path romfs = Paths.get(args[1]);
        boolean primeras = "primeras".equals(args[2]);
        double probFinal = primeras ? 0 : Double.parseDouble(args[2]);
        String registro = args[3];
        Random azar = new Random();
        RomHandler rh = new Gen6RomHandler.Factory().create(azar);
        if (!rh.loadRom(rom)) throw new IllegalStateException("No se ha podido abrir la ROM: " + rom);
        try {
            Method escribir = Abstract3DSRomHandler.class.getDeclaredMethod("writeFile", String.class, byte[].class);
            Method leer = Abstract3DSRomHandler.class.getDeclaredMethod("readFile", String.class);
            escribir.setAccessible(true);
            leer.setAccessible(true);
            // la partida tal cual esta: todo el romfs del mod encima de la ROM (ataques por nivel al azar, etc.)
            try (Stream<Path> archivos = Files.walk(romfs)) {
                for (Path p : (Iterable<Path>) archivos.filter(Files::isRegularFile)::iterator) {
                    String nombre = romfs.relativize(p).toString().replace('\\', '/');
                    if (nombre.endsWith(".nuevo")) continue;
                    escribir.invoke(rh, nombre, Files.readAllBytes(p));
                }
            }
            List<Pokemon> finales = new ArrayList<>(), todos = new ArrayList<>();
            for (Pokemon p : rh.getPokemon()) {
                if (p == null || p.number > MegaFases.MAX_ESPECIE || p.isLegendary()) continue;
                if (!MegaFases.primeraEtapa(p)) todos.add(p);         // 2.2.6: nunca primeras etapas
                if (final_(p)) finales.add(p);
            }
            Map<Integer, List<MoveLearnt>> aprende = rh.getMovesLearnt();
            List<Move> movs = rh.getMoves();
            List<Trainer> entrenadores = rh.getTrainers();
            if (entrenadores.isEmpty()) { System.out.println("SIN ENTRENADORES"); return; }
            int cambiados = 0, deFinal = 0, total = 0;
            if (primeras) entrenadores.clear();                   // lo hace MegaFases.sinPrimeras, abajo
            for (Trainer t : entrenadores) {
                for (TrainerPokemon tp : t.pokemon) {
                    if (tp.hasMegaStone) continue;                           // el as megaevolucionable, con su piedra
                    List<Pokemon> bolsa = azar.nextDouble() < probFinal ? finales : todos;
                    tp.pokemon = bolsa.get(azar.nextInt(bolsa.size()));
                    tp.forme = 0; tp.formeSuffix = ""; tp.abilitySlot = 0;
                    if (t.pokemonHaveCustomMoves()) {
                        tp.moves = MegaFases.movimientos(tp.pokemon, tp.level, aprende, movs, Integer.MAX_VALUE);
                        tp.resetMoves = false;
                    }
                    cambiados++;
                }
            }
            if (primeras) cambiados = MegaFases.sinPrimeras(rh, azar);
            else rh.setTrainers(entrenadores, false);
            int quedan = 0;
            // se comprueba releyendo lo escrito
            for (Trainer t : rh.getTrainers()) for (TrainerPokemon tp : t.pokemon) {
                total++;
                if (final_(tp.pokemon)) deFinal++;
                if (!tp.hasMegaStone && MegaFases.primeraEtapa(tp.pokemon)) quedan++;
            }
            if (quedan > 0) throw new IllegalStateException("Quedan " + quedan + " Pokemon de primera etapa");
            if (cambiados == 0) { System.out.println("YA"); return; }
            for (String nombre : new String[] {TRDATA, TRPOKE}) {
                Path p = romfs.resolve(nombre);
                Path tmp = p.resolveSibling(p.getFileName() + ".nuevo");
                Files.write(tmp, (byte[]) leer.invoke(rh, nombre));
                Files.move(tmp, p, StandardCopyOption.REPLACE_EXISTING);
            }
            try (PrintStream log = new PrintStream(new java.io.FileOutputStream(registro, true), true, "UTF-8")) {
                log.println();
                log.println(primeras ? "--Pokelocke: entrenadores sin primeras etapas (" + cambiados + " cambiados)--"
                        : "--Pokelocke: entrenadores sorteados otra vez, " + Math.round(probFinal * 100) + " % de ultimas etapas--");
                for (Trainer t : rh.getTrainers()) {
                    if (t.pokemon.isEmpty()) continue;
                    StringBuilder sb = new StringBuilder("#" + t.index + " " + (t.tag == null ? "" : t.tag + " ") + t.fullDisplayName + ":");
                    for (TrainerPokemon tp : t.pokemon) sb.append(" ").append(tp.pokemon.name).append(" Nv").append(tp.level).append(",");
                    log.println(sb.substring(0, sb.length() - 1));
                }
            }
            System.out.println("Hecho " + cambiados + " (" + deFinal + " de " + total + " en su ultima etapa)");
        } finally {
            ((Abstract3DSRomHandler) rh).closeInnerRom();
        }
    }
}
