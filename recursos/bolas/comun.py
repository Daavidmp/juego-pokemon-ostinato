import sys
sys.path.insert(0, "/mnt/c/Users/david.martinez/pkmn-devkit")
from devkit.rxdata.project import Project
from devkit.rxdata import marshal
JUEGO = "/mnt/c/Users/david.martinez/Documents/juego-pokemon-ostinato/Pokémon Ostinato"
P = Project(JUEGO)
def s(v):
    v = getattr(v, "value", v)
    return v.decode("utf-8", "replace") if isinstance(v, (bytes, bytearray)) else v
