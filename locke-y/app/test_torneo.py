"""Prueba del cuadro del torneo: de 2 a 16 jugadores, con resultados al azar, hasta que hay campeón.
    python3 app/test_torneo.py
"""
import random

import online


def jugar(n, azar):
    jugadores = [f'J{i}' for i in range(n)]
    partidos, final = online._cuadro(jugadores)
    por_id = {p['id']: p for p in partidos}
    primera = [p for p in partidos if p['fase'] == 'principal' and p['ronda'] == 0]
    en_primera = [f['j'] for p in primera for f in p['fuentes'] if f and 'j' in f]
    assert sorted(en_primera) == sorted(jugadores), 'cada jugador sale una vez en la primera ronda'
    repesca = [p for p in partidos if p['fase'] == 'repesca']
    plaza = [p for p in partidos if p['plaza']]
    assert len(plaza) == n % 2, 'partido del que no tiene rival solo con impares'
    assert all(p['mejor_de'] == 1 for p in repesca) and all(p['mejor_de'] == 3 for p in partidos if p['fase'] == 'principal')
    assert len(repesca) == (max(0, len(primera) - (1 if plaza else 0) - 1) if plaza else 0), 'repesca: perdedores − 1 partidos'
    derrotas = {j: 0 for j in jugadores}
    while por_id[final]['gana'] is None:
        listos = [p for p in partidos if p['gana'] is None and all(p['ab'])]
        assert listos, 'siempre hay algún partido que jugar hasta la final'
        p = azar.choice(listos)
        p['gana'] = azar.randint(0, 1)
        derrotas[p['ab'][1 - p['gana']]] += 1
        online._propagar(partidos)
    campeon = por_id[final]['ab'][por_id[final]['gana']]
    assert derrotas[campeon] == 0 or (n % 2 and derrotas[campeon] == 1), 'el campeón no ha perdido (o solo en la 1.ª ronda, con repesca)'
    jugados = {n for p in partidos for n in p['ab'] if n}
    assert jugados == set(jugadores), 'todos juegan al menos un partido'
    if plaza:
        sin_rival = plaza[0]['fuentes'][0]['j']
        assert all(sin_rival not in p['ab'] for p in primera if not p['plaza']), 'el que no tiene rival no juega la 1.ª ronda normal'
    return len(partidos), len(repesca)


def main():
    azar = random.Random(30)
    for n in range(2, 17):
        for _ in range(200):
            total, rep = jugar(n, azar)
        print(f'{n:2} jugadores: {total:2} partidos ({rep} de repesca) · 200 torneos hasta el campeón, bien')
    # un torneo guardado con el formato de antes (rondas fijas, pases directos) se convierte sin perder resultados
    viejo = {'nombre': 'T', 'jugadores': ['A', 'B', 'C'], 'rondas': [
        [{'ab': ['A', None], 'gana': 0}, {'ab': ['B', 'C'], 'gana': 1, 'ma': '2', 'mb': '1'}],
        [{'ab': ['A', 'C'], 'gana': None, 'vivo': True}]]}
    t = online._al_dia(viejo)
    online._propagar(t['partidos'])
    final = next(p for p in t['partidos'] if p['id'] == t['final'])
    assert final['ab'] == ['A', 'C'] and final['vivo'] and t['partidos'][1]['ma'] == '2', 'formato de antes'
    print('Torneo con el formato de antes: convertido con sus resultados, bien')


if __name__ == '__main__':
    main()
