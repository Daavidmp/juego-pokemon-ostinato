import com.dabomstew.pkrandom.pokemon.MegaEvolution;
import com.dabomstew.pkrandom.pokemon.Pokemon;
import com.dabomstew.pkrandom.pokemon.StaticEncounter;
import com.dabomstew.pkrandom.romhandlers.Abstract3DSRomHandler;
import com.dabomstew.pkrandom.romhandlers.Gen6RomHandler;
import com.dabomstew.pkrandom.romhandlers.RomHandler;

import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * La mega de la Torre Maestra en una partida que ya existe (normas Mega, 1.3.1):
 *   java -cp PokeRandoZX.jar MegaTorre rom DllField.cro [otro DllField.cro ...]
 * El regalo de Corelia (en el juego original, Lucario con la Lucarionita equipada) pasa a ser un Pokemon al azar NO
 * legendario que pueda megaevolucionar, con SU megapiedra equipada (el UPR cambiaba solo la especie y dejaba la
 * Lucarionita). Cada DllField.cro es el del mod de la partida (fase facil y completa): los dos reciben el mismo regalo.
 * Nada mas del archivo cambia. Dice "Hecho <Pokemon> <objeto>", "YA" si ya lo tenia, o "SIN REGALO".
 */
public class MegaTorre {
    public static void main(String[] args) throws Exception {
        Random azar = new Random();
        RomHandler rh = new Gen6RomHandler.Factory().create(azar);
        if (!rh.loadRom(args[0])) throw new IllegalStateException("No se ha podido abrir la ROM: " + args[0]);
        try {
            int indice = -1;
            List<StaticEncounter> rom = rh.getStaticPokemon();
            for (int i = 0; i < rom.size(); i++) if (rom.get(i).pkmn != null && rom.get(i).pkmn.number == 448) indice = i;
            if (indice < 0) { System.out.println("SIN REGALO"); return; }
            Method escribir = Abstract3DSRomHandler.class.getDeclaredMethod("writeFile", String.class, byte[].class);
            Method leer = Abstract3DSRomHandler.class.getDeclaredMethod("readFile", String.class);
            escribir.setAccessible(true);
            leer.setAccessible(true);
            List<MegaEvolution> megas = new ArrayList<>();
            for (Pokemon p : rh.getPokemon())
                if (p != null && p.number <= 721 && !p.isLegendary() && p.megaEvolutionsFrom != null)
                    for (MegaEvolution m : p.megaEvolutionsFrom) if (m.argument > 0) megas.add(m);
            MegaEvolution elegida = megas.get(azar.nextInt(megas.size()));
            String[] objetos = rh.getItemNames();
            String hecho = null;
            for (int k = 1; k < args.length; k++) {
                Path p = Paths.get(args[k]);
                escribir.invoke(rh, "DllField.cro", Files.readAllBytes(p));
                List<StaticEncounter> fijos = rh.getStaticPokemon();
                StaticEncounter regalo = fijos.get(indice);
                boolean bien = regalo.pkmn != null && !regalo.pkmn.isLegendary() && regalo.pkmn.megaEvolutionsFrom != null
                        && regalo.pkmn.megaEvolutionsFrom.stream().anyMatch(m -> m.argument == regalo.heldItem);
                if (bien) continue;
                regalo.pkmn = elegida.from;
                regalo.forme = 0;
                regalo.heldItem = elegida.argument;
                rh.setStaticPokemon(fijos);
                StaticEncounter leido = rh.getStaticPokemon().get(indice);
                if (leido.pkmn.number != elegida.from.number || leido.heldItem != elegida.argument)
                    throw new IllegalStateException("El regalo no se ha escrito bien en " + p);
                Path tmp = p.resolveSibling(p.getFileName() + ".nuevo");
                Files.write(tmp, (byte[]) leer.invoke(rh, "DllField.cro"));
                Files.move(tmp, p, StandardCopyOption.REPLACE_EXISTING);
                hecho = elegida.from.name + " con " + objetos[elegida.argument];
            }
            System.out.println(hecho != null ? "Hecho " + hecho : "YA");
        } finally {
            ((Abstract3DSRomHandler) rh).closeInnerRom();
        }
    }
}
