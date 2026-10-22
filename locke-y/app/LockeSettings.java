import com.dabomstew.pkrandom.Settings;
import com.dabomstew.pkrandom.pokemon.ExpCurve;

import java.io.FileOutputStream;
import java.lang.reflect.Field;

/**
 * Escribe un archivo de ajustes (.rnqs) del Universal Pokemon Randomizer ZX
 * a partir de pares campo=valor con los nombres de los campos de Settings.
 * Se ejecuta sin compilar: java -cp PokeRandoZX.jar LockeSettings.java salida.rnqs campo=valor ...
 */
public class LockeSettings {
    @SuppressWarnings({"unchecked", "rawtypes"})
    public static void main(String[] args) throws Exception {
        Settings s = new Settings();
        s.setRomName("Pokemon Y");
        s.setSelectedEXPCurve(ExpCurve.MEDIUM_FAST);   // la interfaz lo rellena; el constructor no
        for (int i = 1; i < args.length; i++) {
            String[] kv = args[i].split("=", 2);
            Field f = Settings.class.getDeclaredField(kv[0]);
            f.setAccessible(true);
            Class<?> t = f.getType();
            if (t == boolean.class) f.setBoolean(s, Boolean.parseBoolean(kv[1]));
            else if (t == int.class) f.setInt(s, Integer.parseInt(kv[1]));
            else if (t.isEnum()) f.set(s, Enum.valueOf((Class) t, kv[1]));
            else throw new IllegalArgumentException("Campo no admitido: " + kv[0]);
        }
        try (FileOutputStream out = new FileOutputStream(args[0])) {
            s.write(out);
        }
    }
}
