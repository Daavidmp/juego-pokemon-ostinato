import com.dabomstew.pkrandom.constants.GlobalConstants;
import com.dabomstew.pkrandom.pokemon.Move;
import com.dabomstew.pkrandom.romhandlers.Abstract3DSRomHandler;
import com.dabomstew.pkrandom.romhandlers.Gen6RomHandler;
import com.dabomstew.pkrandom.romhandlers.RomHandler;

import java.io.PrintStream;
import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

/**
 * El ataque de cada MT, al azar en una partida que ya existe (normas Mega, 1.2.6):
 *   java -cp PokeRandoZX.jar MTAzar rom guardar code.bin [otro code.bin ...] registro.txt
 * Hasta la 1.2.6 cada MT enseñaba el mismo ataque en todas las rooms. Aquí se sortea uno nuevo para cada MT, salvo:
 *   - las que el jugador ya tiene en la mochila (guardar: números de MT separados por comas, 1-100): no cambian
 *   - las de uso fuera de combate (Destello, Golpe Roca…)
 * Los ataques nuevos son de menos de 70 de potencia (o de estado), sin repetir, ni MO, ni los prohibidos del
 * randomizador. Las mismas MT en todos los code.bin (fase fácil y completa). Dice "Hecho n".
 */
public class MTAzar {
    static final int MAX_POTENCIA_MT = 69;

    public static void main(String[] args) throws Exception {
        String rom = args[0];
        Set<Integer> guardar = new HashSet<>();
        for (String x : args[1].split(",")) if (!x.isBlank()) guardar.add(Integer.parseInt(x.trim()));
        List<String> codigos = List.of(args).subList(2, args.length - 1);
        String registro = args[args.length - 1];
        Random azar = new Random();
        RomHandler rh = new Gen6RomHandler.Factory().create(azar);
        if (!rh.loadRom(rom)) throw new IllegalStateException("No se ha podido abrir la ROM: " + rom);
        try {
            Field campo = Gen6RomHandler.class.getDeclaredField("code");
            campo.setAccessible(true);
            int largo = ((byte[]) campo.get(rh)).length;
            byte[] primero = Files.readAllBytes(Paths.get(codigos.get(0)));
            if (primero.length != largo) throw new IllegalStateException("El code.bin no es de esta ROM");
            campo.set(rh, primero);
            List<Integer> mts = new ArrayList<>(rh.getTMMoves());
            List<Move> movs = rh.getMoves();
            Set<Integer> campoMovs = new HashSet<>(rh.getFieldMoves());
            Set<Integer> usados = new HashSet<>(mts);
            usados.addAll(rh.getHMMoves());
            usados.addAll(rh.getMovesBannedFromLevelup());
            List<Integer> posibles = new ArrayList<>();
            for (Move m : movs) {
                if (m == null || m.number > 621 || m.number == 165 || usados.contains(m.number)) continue;   // 165: Forcejeo
                if (m.number < GlobalConstants.bannedRandomMoves.length && GlobalConstants.bannedRandomMoves[m.number]) continue;
                if (m.power > MAX_POTENCIA_MT || m.power == 1) continue;     // 1: daño variable o fijo
                posibles.add(m.number);
            }
            List<String> log = new ArrayList<>();
            for (int i = 0; i < mts.size() && !posibles.isEmpty(); i++) {
                int mt = i + 1;
                if (guardar.contains(mt) || campoMovs.contains(mts.get(i))) continue;
                int nuevo = posibles.remove(azar.nextInt(posibles.size()));
                log.add(String.format("MT%02d: %s -> %s", mt, movs.get(mts.get(i)).name, movs.get(nuevo).name));
                mts.set(i, nuevo);
            }
            int hechos = 0;
            for (String c : codigos) {
                Path p = Paths.get(c);
                byte[] code = Files.readAllBytes(p);
                if (code.length != largo) throw new IllegalStateException("El code.bin no es de esta ROM: " + c);
                campo.set(rh, code);
                rh.setTMMoves(mts);
                Path tmp = p.resolveSibling(p.getFileName() + ".nuevo");
                Files.write(tmp, (byte[]) campo.get(rh));
                Files.move(tmp, p, StandardCopyOption.REPLACE_EXISTING);
                hechos++;
            }
            try (PrintStream out = new PrintStream(registro, StandardCharsets.UTF_8)) {
                out.println("--Pokelocke 1.2.6: el ataque de cada MT, al azar (sin tocar las de la mochila: " + guardar.size() + ")--");
                for (String l : log) out.println(l);
            }
            System.out.println("Hecho " + hechos);
        } finally {
            ((Abstract3DSRomHandler) rh).closeInnerRom();
        }
    }
}
