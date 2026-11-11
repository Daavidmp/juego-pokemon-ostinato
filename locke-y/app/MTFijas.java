import com.dabomstew.pkrandom.romhandlers.Abstract3DSRomHandler;
import com.dabomstew.pkrandom.romhandlers.Gen6RomHandler;
import com.dabomstew.pkrandom.romhandlers.RomHandler;

import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.Random;

/**
 * Las MT de la fase fácil, también en la completa (normas Mega, 1.2.4):
 *   java -cp PokeRandoZX.jar MTFijas rom code.bin_facil code.bin_completa
 * Hasta la 1.2.4, la fase fácil cambiaba las MT de 70 o más por otras más flojas solo en su mod, y al abrir la
 * randomización completa (2.ª medalla) las MT enseñaban otros ataques. Aquí se copian los ataques de cada MT del
 * code.bin de la fase fácil al de la completa; nada más del code.bin cambia (las descripciones de las MT están en el
 * texto del romfs: ese archivo lo copia la app). Dice "Hecho" o "YA" si ya eran las mismas.
 */
public class MTFijas {
    public static void main(String[] args) throws Exception {
        RomHandler rh = new Gen6RomHandler.Factory().create(new Random());
        if (!rh.loadRom(args[0])) throw new IllegalStateException("No se ha podido abrir la ROM: " + args[0]);
        try {
            Field campo = Gen6RomHandler.class.getDeclaredField("code");
            campo.setAccessible(true);
            int largo = ((byte[]) campo.get(rh)).length;
            Path facil = Paths.get(args[1]), completa = Paths.get(args[2]);
            byte[] cf = Files.readAllBytes(facil), cc = Files.readAllBytes(completa);
            if (cf.length != largo || cc.length != largo) throw new IllegalStateException("El code.bin no es de esta ROM");
            campo.set(rh, cf);
            List<Integer> mts = rh.getTMMoves();
            campo.set(rh, cc);
            if (rh.getTMMoves().equals(mts)) {
                System.out.println("YA");
                return;
            }
            rh.setTMMoves(mts);
            byte[] nuevo = (byte[]) campo.get(rh);
            Path tmp = completa.resolveSibling(completa.getFileName() + ".nuevo");
            Files.write(tmp, nuevo);
            Files.move(tmp, completa, StandardCopyOption.REPLACE_EXISTING);
            System.out.println("Hecho");
        } finally {
            ((Abstract3DSRomHandler) rh).closeInnerRom();
        }
    }
}
