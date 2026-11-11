import com.dabomstew.pkrandom.romhandlers.Abstract3DSRomHandler;
import com.dabomstew.pkrandom.romhandlers.Gen6RomHandler;
import com.dabomstew.pkrandom.romhandlers.RomHandler;

import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Deshace el sorteo de MT de la 1.2.6/1.2.7 en una partida concreta (se pidio para la de Cesbay):
 *   java -cp PokeRandoZX.jar MTVolver rom "mt:antes:despues mt:antes:despues ..." code.bin [otro code.bin ...]
 * Cada MT vuelve al ataque que tenia antes del sorteo (el de su mt_azar.log), pero solo si sigue teniendo el que le
 * puso el sorteo: si ya es otro, no se toca. Dice "Hecho n" (MT devueltas) o "YA".
 */
public class MTVolver {
    public static void main(String[] args) throws Exception {
        RomHandler rh = new Gen6RomHandler.Factory().create(new Random());
        if (!rh.loadRom(args[0])) throw new IllegalStateException("No se ha podido abrir la ROM: " + args[0]);
        try {
            Field campo = Gen6RomHandler.class.getDeclaredField("code");
            campo.setAccessible(true);
            int largo = ((byte[]) campo.get(rh)).length;
            String[] cambios = args[1].trim().split("\\s+");
            int devueltas = 0;
            for (int k = 2; k < args.length; k++) {
                Path p = Paths.get(args[k]);
                byte[] code = Files.readAllBytes(p);
                if (code.length != largo) throw new IllegalStateException("El code.bin no es de esta ROM: " + p);
                campo.set(rh, code);
                List<Integer> mts = new ArrayList<>(rh.getTMMoves());
                int aqui = 0;
                for (String c : cambios) {
                    String[] t = c.split(":");
                    int i = Integer.parseInt(t[0]) - 1, antes = Integer.parseInt(t[1]), despues = Integer.parseInt(t[2]);
                    if (mts.get(i) == despues) { mts.set(i, antes); aqui++; }
                }
                if (aqui == 0) continue;
                rh.setTMMoves(mts);
                Path tmp = p.resolveSibling(p.getFileName() + ".nuevo");
                Files.write(tmp, (byte[]) campo.get(rh));
                Files.move(tmp, p, StandardCopyOption.REPLACE_EXISTING);
                devueltas = Math.max(devueltas, aqui);
            }
            System.out.println(devueltas > 0 ? "Hecho " + devueltas : "YA");
        } finally {
            ((Abstract3DSRomHandler) rh).closeInnerRom();
        }
    }
}
