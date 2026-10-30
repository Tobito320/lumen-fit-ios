#!/usr/bin/env python3
"""WCAG-2.2-Kontrast fuer alle Farb-Tokens von Lumen Fit (docs/research/design.md Abschnitt 3).
Aufruf: python3 docs/research/kontrast.py          -> Tabellen, Exit 1 bei FAIL einer Pflicht-Paarung
        python3 docs/research/kontrast.py --md     -> Markdown-Tabellen fuer design.md
Formel: L = 0,2126 R + 0,7152 G + 0,0722 B (sRGB linearisiert), Verhaeltnis (L1+0,05)/(L2+0,05).
"""
import sys

def lum(h):
    h = h.lstrip('#'); r, g, b = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def cr(a, b):
    la, lb = lum(a), lum(b)
    if la < lb: la, lb = lb, la
    return (la + 0.05) / (lb + 0.05)

def mix(a, b, t):  # a mit Deckkraft t ueber b
    a = a.lstrip('#'); b = b.lstrip('#')
    return '#' + ''.join('%02X' % round(int(a[i:i + 2], 16) * t + int(b[i:i + 2], 16) * (1 - t)) for i in (0, 2, 4))

# Themes: (grund, flaeche, text, text2, rand, akzent, aufAkzent, muster-Farbe, muster-Deckkraft auf Hero)
T = {
 ('Monochrom', 'hell'):  dict(grund='#FFFFFF', flaeche='#F2F2F7', text='#000000', text2='#5E5E62', rand='#8A8A8E', akzent='#000000', auf='#FFFFFF', stripe='#FFFFFF', sa=.10),
 ('Monochrom', 'dunkel'):dict(grund='#000000', flaeche='#1C1C1E', text='#FFFFFF', text2='#98989F', rand='#8E8E93', akzent='#FFFFFF', auf='#000000', stripe='#000000', sa=.12),
 ('Graphit', 'hell'):    dict(grund='#F2F2F7', flaeche='#FFFFFF', text='#1C1C1E', text2='#5A5A5E', rand='#85858A', akzent='#1C1C1E', auf='#FFFFFF', stripe='#FFFFFF', sa=.10),
 ('Graphit', 'dunkel'):  dict(grund='#000000', flaeche='#1C1C1E', text='#FFFFFF', text2='#98989F', rand='#8E8E93', akzent='#FFFFFF', auf='#000000', stripe='#000000', sa=.12),
 ('Stahl', 'hell'):      dict(grund='#F5F7FA', flaeche='#E8EDF3', text='#0B1220', text2='#566377', rand='#7B8798', akzent='#1F4E79', auf='#FFFFFF', stripe='#FFFFFF', sa=.10),
 ('Stahl', 'dunkel'):    dict(grund='#0B1220', flaeche='#151E2E', text='#F2F5FA', text2='#9AA8BC', rand='#7B8BA3', akzent='#7FB2E5', auf='#0B1220', stripe='#0B1220', sa=.12),
 ('Glut', 'hell'):       dict(grund='#FFF8F3', flaeche='#FFEBDD', text='#1A0E05', text2='#6B4A33', rand='#9A7258', akzent='#A84300', auf='#FFFFFF', stripe='#FFFFFF', sa=.10),
 ('Glut', 'dunkel'):     dict(grund='#0D0D0D', flaeche='#1A1A1A', text='#F5F5F5', text2='#9A9A9A', rand='#808080', akzent='#FF6A00', auf='#000000', stripe='#000000', sa=.12),
 ('Wald', 'hell'):       dict(grund='#F7F8F6', flaeche='#E9ECE6', text='#111611', text2='#566156', rand='#7A877A', akzent='#2F5D3A', auf='#FFFFFF', stripe='#FFFFFF', sa=.10),
 ('Wald', 'dunkel'):     dict(grund='#0C120D', flaeche='#172019', text='#EEF3EE', text2='#9DAE9D', rand='#7E907F', akzent='#8FC79A', auf='#0C120D', stripe='#0C120D', sa=.12),
 ('Lovea', 'hell'):      dict(grund='#FFFFFF', flaeche='#FFEDF0', text='#1C1C1E', text2='#6A5A5E', rand='#8C7C80', akzent='#CF1F41', auf='#FFFFFF', stripe='#FFFFFF', sa=.10),
 ('Lovea', 'dunkel'):    dict(grund='#000000', flaeche='#211418', text='#F5F5F7', text2='#B9A6AB', rand='#8F7C82', akzent='#FF3B5C', auf='#000000', stripe='#000000', sa=.12),
}

# Gemeinsame Farben: Ringfarben (Ahmeds Vorgabe, nur auf schwarzer Ringplatte) und Text-Varianten (Tief) fuer helle/dunkle Flaechen
RING = dict(bewegen='#FA114F', trainieren_h='#2DBE4F', trainieren_d='#A6FF00', erholen_h='#0A9FE0', erholen_d='#00E0F0')
PLATTE = '#000000'
# Deckkraft der Musterlinien je Theme (volle Staerke im Kopfbereich, Karten 45 %)
PA = {('Monochrom','hell'):.12,('Monochrom','dunkel'):.12,('Graphit','hell'):.10,('Graphit','dunkel'):.10,('Stahl','hell'):.14,('Stahl','dunkel'):.14,('Glut','hell'):.14,('Glut','dunkel'):.20,('Wald','hell'):.18,('Wald','dunkel'):.18,('Lovea','hell'):.12,('Lovea','dunkel'):.16}
# Tief-Varianten (Text und duenne Linien auf Theme-Flaechen). hell = auf hellen Flaechen, dunkel = auf dunklen
TIEF = {
 'hell':   dict(bewegen='#D00A3C', trainieren='#16742F', erholen='#00699E', gut='#16742F', warn='#8F4B00', schlecht='#C4161C'),
 'dunkel': dict(bewegen='#FF4F7E', trainieren='#A6FF00', erholen='#00E0F0', gut='#30D158', warn='#FFB340', schlecht='#FF6961'),
}
LUMI = {  # Koerper (Verlaufsmitte, Rand) und Kontur je Stimmung; Kontur nur auf hellen Flaechen noetig (Lumi ist Dekor mit Textalternative)
 'muede': dict(mitte='#7C8CF8', rand='#5E5CE6', kontur='#4B49C9'),
 'bereit': dict(mitte='#FFC53D', rand='#FF9500', kontur='#9A5B00'),
 'stolz': dict(mitte='#FF7A3D', rand='#FA114F', kontur='#C20D3F'),
}

def zeilen():
    out = []  # (gruppe, name, fg, bg, min)
    for (th, md), p in T.items():
        g = f'{th} {md}'
        for bg in ('grund', 'flaeche'):
            out += [(g, f'text auf {bg}', p['text'], p[bg], 4.5), (g, f'text2 auf {bg}', p['text2'], p[bg], 4.5),
                    (g, f'akzent auf {bg} (Text/Symbol)', p['akzent'], p[bg], 4.5), (g, f'rand auf {bg} (Bedienelement)', p['rand'], p[bg], 3.0)]
        out.append((g, 'aufAkzent auf akzent (Knopf)', p['auf'], p['akzent'], 4.5))
        # Hero-Streifen: schlechtester Punkt = Streifenfarbe ueber Akzent
        st = mix(p['stripe'], p['akzent'], p['sa'])
        out.append((g, 'aufAkzent auf Hero-Streifen (schlechtester Punkt)', p['auf'], st, 4.5))
        t = TIEF[md]
        for k in ('bewegen', 'trainieren', 'erholen'):
            out.append((g, f'{k}-Tief auf flaeche', t[k], p['flaeche'], 4.5))
            out.append((g, f'{k}-Tief auf grund', t[k], p['grund'], 4.5))
        for k in ('gut', 'warn', 'schlecht'):
            out.append((g, f'{k} auf flaeche', t[k], p['flaeche'], 4.5))
    # INFO: Hero-Nebentext des Entwurfs v9 (aufAkzent mit 75 % Deckkraft) ueber dem Streifen; Umsetzung: kein Dimmen, voller aufAkzent
    for (th, md), p in T.items():
        st = mix(p['stripe'], p['akzent'], p['sa'])
        out.append((f'INFO Entwurf v9 Hero-Nebentext 75 % {th} {md}', 'aufAkzent 75 % auf Hero-Streifen', mix(p['auf'], st, .75), st, 4.5))
    # Muster (Linien in Akzentfarbe, Deckkraft pa): schlechtester Punkt = Linie genau unter Text. Kopfbereich: volle Deckkraft; Karten: pa * 0,45
    for (th, md), p in T.items():
        g = f'{th} {md}'; pa = PA[(th, md)]
        top = mix(p['akzent'], p['grund'], pa)
        card = mix(p['akzent'], p['flaeche'], pa * .45)
        out.append((g, f'Muster {int(pa*100)} %: text2 auf Kopfbereich-Linie', p['text2'], top, 4.5))
        out.append((g, f'Muster: text auf Kopfbereich-Linie', p['text'], top, 4.5))
        out.append((g, f'Muster {int(pa*45)} %: text2 auf Karten-Linie', p['text2'], card, 4.5))
    # Ringplatte (immer schwarz)
    for k, v in (('bewegen', RING['bewegen']), ('trainieren hell', RING['trainieren_h']), ('trainieren dunkel', RING['trainieren_d']),
                 ('erholen hell', RING['erholen_h']), ('erholen dunkel', RING['erholen_d'])):
        out.append(('Ringplatte schwarz', f'{k} {v}', v, PLATTE, 3.0))
        out.append(('Ringplatte schwarz', f'weisser Text neben {k}', '#FFFFFF', PLATTE, 4.5))
    # Streichung: exakte Ringfarben direkt auf Flaechen (nur Info, Mockup-Zustand)
    for (th, md), p in T.items():
        for k, v in (('bewegen', RING['bewegen']), ('trainieren', RING['trainieren_h'] if md == 'hell' else RING['trainieren_d']),
                     ('erholen', RING['erholen_h'] if md == 'hell' else RING['erholen_d'])):
            out.append((f'INFO ohne Platte {th} {md}', f'Ringfarbe {k} auf flaeche', v, p['flaeche'], 3.0))
    for k, l in LUMI.items():
        for (th, md), p in T.items():
            fg = l['kontur'] if md == 'hell' else l['rand']
            for bg in ('grund', 'flaeche'):
                out.append((f'Lumi {th} {md}', f'{k}: {"Kontur" if md == "hell" else "Rand"} {fg} auf {bg}', fg, p[bg], 3.0))
    return out

if __name__ == '__main__':
    md = '--md' in sys.argv
    fails = 0; last = None
    for g, n, fg, bg, m in zeilen():
        r = cr(fg, bg); ok = r >= m
        info = g.startswith('INFO')
        if not ok and not info: fails += 1
        if g != last:
            print(('\n### ' if md else '\n== ') + g); last = g
            if md: print('| Paar | Vordergrund | Hintergrund | Verhaeltnis | min | |\n|---|---|---|---|---|---|')
        flag = 'OK' if ok else ('INFO-FAIL' if info else 'FAIL')
        if md: print(f'| {n} | {fg} | {bg} | {r:.2f} | {m} | {flag} |')
        else: print(f'{n:52}{fg} auf {bg}  {r:6.2f}  min {m}  {flag}')
    print(f'\nFAIL (Pflicht): {fails}')
    sys.exit(1 if fails else 0)
