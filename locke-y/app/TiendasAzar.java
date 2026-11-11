import com.dabomstew.pkrandom.Settings;
import com.dabomstew.pkrandom.pokemon.ItemList;
import com.dabomstew.pkrandom.pokemon.Shop;
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
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Random;
import java.util.Set;

/**
 * Tiendas aleatorias del segundo dependiente de los Centros Pokémon (normas Mega).
 *   java -cp PokeRandoZX.jar TiendasAzar.java rom code.bin [otro code.bin ...] registro.txt
 * Las tiendas de Pokémon Y están en una tabla del code.bin. El randomizador solo cambia las tiendas "especiales": las
 * de MT (el segundo dependiente de los Centros de Luminalia) se las salta, y por eso salían iguales en todas las
 * partidas. Este programa carga la ROM original, le pone el code.bin de la partida y:
 *   1. si las tiendas especiales siguen como en la ROM (partidas randomizadas antes de la 1.2.0), las randomiza con
 *      el randomizador y las mismas reglas que las partidas nuevas;
 *   2. si las tiendas de MT siguen vendiendo las MT de la ROM, les pone MT al azar: siguen siendo tiendas de MT,
 *      pero con MT distintas en cada partida y sin repetir ninguna entre las cuatro tiendas.
 * Nada más del code.bin cambia. Los precios no se tocan. La fase fácil y la completa tienen code.bin distintos: las
 * mismas tiendas nuevas se escriben en cada uno. Dice "Hecho n", "YA" (nada que cambiar) o "SIN TIENDAS" (ROM
 * modificada en la que no se encuentra la tabla).
 */
public class TiendasAzar {
    public static void main(String[] args) throws Exception {
        String rom = args[0];
        List<String> codigos = List.of(args).subList(1, args.length - 1);
        String registro = args[args.length - 1];
        Random azar = new Random();
        RomHandler rh = new Gen6RomHandler.Factory().create(azar);
        if (!rh.loadRom(rom)) {
            throw new IllegalStateException("No se ha podido abrir la ROM: " + rom);
        }
        try {
            Field campo = Gen6RomHandler.class.getDeclaredField("code");
            campo.setAccessible(true);
            int largo = ((byte[]) campo.get(rh)).length;
            Map<Integer, int[]> originalesMT = contenidoMT(rh, (byte[]) campo.get(rh));
            Map<Integer, Shop> originales = rh.getShopItems();
            System.out.println("tiendas en la ROM: " + originales.size());
            if (originales.isEmpty()) {
                System.out.println("SIN TIENDAS");
                return;
            }
            Map<Integer, Shop> nuevas = null;
            Map<Integer, int[]> nuevasMT = null;
            int hechos = 0;
            for (String c : codigos) {
                Path p = Paths.get(c);
                byte[] propio = Files.readAllBytes(p);
                if (propio.length != largo) throw new IllegalStateException("El code.bin no es de esta ROM: " + c);
                campo.set(rh, propio);
                boolean cambia = false;
                if (mismas(originales, rh.getShopItems())) {
                    if (nuevas == null) {
                        Settings s = new Settings();
                        s.setShopItemsMod(false, false, true);    // UNCHANGED, SHUFFLE, RANDOM
                        s.setBanBadRandomShopItems(true);
                        s.setBanRegularShopItems(true);
                        s.setBanOPShopItems(true);
                        s.setBalanceShopPrices(false);
                        rh.randomizeShopItems(s);
                        nuevas = rh.getShopItems();
                    } else {
                        rh.setShopItems(nuevas);
                    }
                    cambia = true;
                }
                byte[] code = (byte[]) campo.get(rh);
                if (nuevasMT == null) nuevasMT = sortearMT(rh, originalesMT, azar);
                if (ponerMT(rh, code, originalesMT, nuevasMT)) cambia = true;
                if (!cambia) {
                    System.out.println("YA " + c);
                    continue;
                }
                Path tmp = p.resolveSibling(p.getFileName() + ".nuevo");
                Files.write(tmp, code);
                Files.move(tmp, p, StandardCopyOption.REPLACE_EXISTING);
                hechos++;
            }
            if (hechos == 0) {
                System.out.println("YA");
                return;
            }
            try (PrintStream log = new PrintStream(registro, StandardCharsets.UTF_8)) {
                String[] nombres = rh.getItemNames();
                log.println("--Shops-- (Pokelocke: tiendas aleatorias del segundo dependiente)");
                for (Shop t : rh.getShopItems().values()) {
                    log.println(t.name);
                    for (int i : t.items) log.println("- " + nombres[i]);
                    log.println();
                }
                for (Map.Entry<Integer, int[]> e : nuevasMT.entrySet()) {
                    log.println("Tienda de MT " + e.getKey() + " (Luminalia)");
                    for (int i : e.getValue()) log.println("- " + nombres[i]);
                    log.println();
                }
            }
            System.out.println("Hecho " + hechos);
        } finally {
            ((Abstract3DSRomHandler) rh).closeInnerRom();
        }
    }

    static boolean mismas(Map<Integer, Shop> a, Map<Integer, Shop> b) {
        if (!a.keySet().equals(b.keySet())) return false;
        for (Integer k : a.keySet()) {
            if (!Objects.equals(a.get(k).items, b.get(k).items)) return false;
        }
        return true;
    }

    // ---------- las tiendas de MT ----------

    /** Dónde empieza cada tienda de MT en el code.bin y cuántos objetos tiene (la tabla va tienda tras tienda, dos
     *  bytes por objeto, en el orden de ShopItemSizes de la configuración del randomizador). */
    static Map<Integer, int[]> huecosMT(RomHandler rh) throws Exception {
        Field re = Gen6RomHandler.class.getDeclaredField("romEntry");
        re.setAccessible(true);
        Object entrada = re.get(rh);
        Field ae = entrada.getClass().getDeclaredField("arrayEntries");
        ae.setAccessible(true);
        @SuppressWarnings("unchecked")
        Map<String, int[]> tablas = (Map<String, int[]>) ae.get(entrada);
        Method m = Gen6RomHandler.class.getDeclaredMethod("getShopItemsOffset");
        m.setAccessible(true);
        int base = (Integer) m.invoke(rh);
        int[] tam = tablas.get("ShopItemSizes"), mt = tablas.get("TMShops");
        Map<Integer, int[]> huecos = new LinkedHashMap<>();
        for (int t : mt) {
            int off = base;
            for (int i = 0; i < t; i++) off += tam[i] * 2;
            huecos.put(t, new int[]{off, tam[t]});
        }
        return huecos;
    }

    static int leer(byte[] b, int o) { return (b[o] & 0xFF) | ((b[o + 1] & 0xFF) << 8); }

    static void escribir(byte[] b, int o, int v) { b[o] = (byte) v; b[o + 1] = (byte) (v >> 8); }

    /** Lo que vende cada tienda de MT en un code.bin. */
    static Map<Integer, int[]> contenidoMT(RomHandler rh, byte[] code) throws Exception {
        Map<Integer, int[]> r = new LinkedHashMap<>();
        for (Map.Entry<Integer, int[]> e : huecosMT(rh).entrySet()) {
            int off = e.getValue()[0], n = e.getValue()[1];
            int[] objetos = new int[n];
            for (int k = 0; k < n; k++) objetos[k] = leer(code, off + 2 * k);
            r.put(e.getKey(), objetos);
        }
        return r;
    }

    /** MT al azar para cada tienda de MT, del mismo tamaño que las de la ROM: siguen vendiendo MT (las de siempre en
     *  la tienda de MT, con su pantalla), pero distintas en cada partida y sin repetir ninguna entre las cuatro. */
    static Map<Integer, int[]> sortearMT(RomHandler rh, Map<Integer, int[]> originales, Random azar) {
        ItemList lista = rh.getAllowedItems();
        Set<Integer> usadas = new HashSet<>();
        Map<Integer, int[]> nuevas = new LinkedHashMap<>();
        for (Map.Entry<Integer, int[]> e : originales.entrySet()) {
            int[] mt = new int[e.getValue().length];
            for (int k = 0; k < mt.length; k++) {
                int id;
                do {
                    id = lista.randomTM(azar);
                } while (!usadas.add(id));
                mt[k] = id;
            }
            java.util.Arrays.sort(mt);              // en orden de número de MT, como en el juego
            nuevas.put(e.getKey(), mt);
        }
        return nuevas;
    }

    /** Pone las MT sorteadas en las tiendas de MT que aún venden las de la ROM. Devuelve si ha cambiado algo. */
    static boolean ponerMT(RomHandler rh, byte[] code, Map<Integer, int[]> originales, Map<Integer, int[]> nuevas)
            throws Exception {
        boolean cambia = false;
        ItemList todos = rh.getAllowedItems();
        Map<Integer, int[]> ahora = contenidoMT(rh, code);
        for (Map.Entry<Integer, int[]> e : huecosMT(rh).entrySet()) {
            // se cambian las que venden las MT de la ROM y las que se quedaron con objetos que no son MT (el parche de
            // la 1.2.1 de prueba, 2026-11-07, ponía objetos); las que ya tienen MT al azar se dejan como están
            boolean deLaRom = java.util.Arrays.equals(ahora.get(e.getKey()), originales.get(e.getKey()));
            boolean conObjetos = java.util.Arrays.stream(ahora.get(e.getKey())).anyMatch(i -> !todos.isTM(i));
            if (!deLaRom && !conObjetos) continue;
            int off = e.getValue()[0];
            int[] mt = nuevas.get(e.getKey());
            for (int k = 0; k < mt.length; k++) escribir(code, off + 2 * k, mt[k]);
            cambia = true;
        }
        return cambia;
    }
}
