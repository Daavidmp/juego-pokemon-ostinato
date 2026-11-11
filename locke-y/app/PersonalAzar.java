import com.dabomstew.pkrandom.Settings;
import com.dabomstew.pkrandom.ctr.GARCArchive;
import com.dabomstew.pkrandom.romhandlers.Abstract3DSRomHandler;
import com.dabomstew.pkrandom.romhandlers.Gen6RomHandler;
import com.dabomstew.pkrandom.romhandlers.RomHandler;

import java.io.PrintStream;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

/**
 * Parches en los datos de cada Pokémon (el GARC PokemonStats, a/2/1/8 en X/Y) de un mod ya randomizado, sin volver a
 * randomizar nada más (normas Mega, 1.2.4):
 *   java -cp PokeRandoZX.jar PersonalAzar rom personal [otro personal ...] registro.txt
 * 1. MT: si cada Pokémon sigue aprendiendo las MT del juego original (casi siempre las de su tipo: la app no le pedía
 *    al randomizador que las cambiara), se sortean con el randomizador «totalmente al azar», siguiendo las
 *    evoluciones, con todas las MO compatibles (para no quedarse atascado sin Surf o Fuerza).
 * 2. Superguarda (Wonder Guard) prohibida: donde salga, se cambia por otra habilidad al azar (ni Superguarda ni las
 *    inútiles para el randomizador). También en Shedinja.
 * Cada «personal» es el archivo del mod (fase fácil y completa); si no existe, se parte del de la ROM. Las dos fases
 * reciben los mismos cambios. Dice "Hecho n", o "YA" si no había nada que cambiar.
 */
public class PersonalAzar {
    static final int SUPERGUARDA = 25;
    static final int HABILIDADES = 0x18, MT = 0x28, MT_BYTES = 16;     // en cada entrada de 0x40 bytes

    public static void main(String[] args) throws Exception {
        String rom = args[0];
        List<String> personales = List.of(args).subList(1, args.length - 1);
        String registro = args[args.length - 1];
        Random azar = new Random();
        RomHandler rh = new Gen6RomHandler.Factory().create(azar);
        if (!rh.loadRom(rom)) throw new IllegalStateException("No se ha podido abrir la ROM: " + rom);
        try {
            Field campo = Gen6RomHandler.class.getDeclaredField("pokeGarc");
            campo.setAccessible(true);
            GARCArchive original = (GARCArchive) campo.get(rh);
            byte[] grandeRom = grande(original);
            Method leerArchivo = Abstract3DSRomHandler.class.getDeclaredMethod("readFile", String.class);
            leerArchivo.setAccessible(true);

            // las MT sorteadas una vez, para todas las fases (se escriben sobre el pokeGarc de la ROM y se copian)
            Settings s = new Settings();
            s.setTmsHmsCompatibilityMod(false, false, true, false);     // UNCHANGED, PREFER_TYPE, COMPLETELY_RANDOM, FULL
            s.setTmsFollowEvolutions(true);
            rh.randomizeTMHMCompatibility(s);
            rh.fullHMCompatibility();
            rh.copyTMCompatibilityToCosmeticFormes();
            rh.setTMHMCompatibility(rh.getTMHMCompatibility());
            byte[] grandeMt = rehacerGrande(original);

            Set<Integer> prohibidas = new HashSet<>(rh.getUselessAbilities());
            prohibidas.add(SUPERGUARDA);
            prohibidas.add(0);
            List<Integer> validas = new ArrayList<>();
            for (int a = 1; a <= rh.highestAbilityIndex(); a++) if (!prohibidas.contains(a)) validas.add(a);
            int[] cambioHab = new int[grandeRom.length / 0x40 * 3];       // la misma habilidad nueva en cada fase
            for (int k = 0; k < cambioHab.length; k++) cambioHab[k] = validas.get(azar.nextInt(validas.size()));

            List<String> log = new ArrayList<>();
            int hechos = 0;
            for (String c : personales) {
                Path p = Paths.get(c);
                GARCArchive garc = new GARCArchive(Files.exists(p) ? Files.readAllBytes(p) : (byte[]) leerArchivo.invoke(rh, "a/2/1/8"), true);
                byte[] g = grande(garc);
                if (g.length != grandeRom.length) throw new IllegalStateException("El archivo no es de esta ROM: " + c);
                boolean cambia = false;
                int n = g.length / 0x40;
                // 1. MT: solo si son las del juego original en todos
                boolean originales = true;
                for (int i = 0; i < n && originales; i++)
                    originales = Arrays.equals(Arrays.copyOfRange(g, i * 0x40 + MT, i * 0x40 + MT + MT_BYTES),
                            Arrays.copyOfRange(grandeRom, i * 0x40 + MT, i * 0x40 + MT + MT_BYTES));
                if (originales) {
                    for (int i = 0; i < n; i++) System.arraycopy(grandeMt, i * 0x40 + MT, g, i * 0x40 + MT, MT_BYTES);
                    cambia = true;
                    if (log.isEmpty() || !log.get(0).startsWith("MT")) log.add(0, "MT: compatibilidad totalmente al azar (siguiendo las evoluciones), todas las MO");
                }
                // 2. Superguarda
                for (int i = 0; i < n; i++)
                    for (int k = 0; k < 3; k++)
                        if ((g[i * 0x40 + HABILIDADES + k] & 0xFF) == SUPERGUARDA) {
                            int nueva = cambioHab[i * 3 + k];
                            g[i * 0x40 + HABILIDADES + k] = (byte) nueva;
                            cambia = true;
                            String linea = "Superguarda -> " + rh.abilityName(nueva) + " (entrada " + i + ", habilidad " + (k + 1) + ")";
                            if (!log.contains(linea)) log.add(linea);
                        }
                if (!cambia) {
                    System.out.println("YA " + c);
                    continue;
                }
                // los cambios a cada entrada suelta y a la tabla grande (la última, con todas seguidas)
                for (int i = 0; i < n && i < garc.files.size() - 1; i++) {
                    byte[] e = garc.files.get(i).get(0);
                    System.arraycopy(g, i * 0x40, e, 0, 0x40);
                }
                garc.files.get(garc.files.size() - 1).put(0, g);
                Files.createDirectories(p.getParent());
                Path tmp = p.resolveSibling(p.getFileName() + ".nuevo");
                Files.write(tmp, garc.getBytes());
                Files.move(tmp, p, StandardCopyOption.REPLACE_EXISTING);
                hechos++;
            }
            if (hechos == 0) {
                System.out.println("YA");
                return;
            }
            try (PrintStream out = new PrintStream(registro, StandardCharsets.UTF_8)) {
                out.println("--Pokelocke 1.2.4: MT al azar y sin Superguarda--");
                for (String l : log) out.println(l);
            }
            System.out.println("Hecho " + hechos);
        } finally {
            ((Abstract3DSRomHandler) rh).closeInnerRom();
        }
    }

    /** La tabla grande: el último archivo del GARC, con las entradas de 0x40 bytes seguidas. */
    static byte[] grande(GARCArchive garc) {
        return garc.files.get(garc.files.size() - 1).get(0).clone();
    }

    /** La tabla grande rehecha con las entradas sueltas (setTMHMCompatibility solo cambia las sueltas). */
    static byte[] rehacerGrande(GARCArchive garc) {
        byte[] g = grande(garc);
        for (int i = 0; i < g.length / 0x40 && i < garc.files.size() - 1; i++) {
            byte[] e = garc.files.get(i).get(0);
            System.arraycopy(e, 0, g, i * 0x40, Math.min(0x40, e.length));
        }
        return g;
    }
}
