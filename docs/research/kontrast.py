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
# Ein Theme (Ahmed 09.11.: "Ein theme. Dark/white."), Spiegel von LumenFarben.tokens
T = {
 ('Lumen', 'hell'):   dict(grund='#FFFFFF', flaeche='#F2F2F7', text='#000000', text2='#5E5E62', rand='#8A8A8E', akzent='#457A00', auf='#FFFFFF', akzentF='#9BE800', aufF='#000000'),
 ('Lumen', 'dunkel'): dict(grund='#000000', flaeche='#1C1C1E', text='#FFFFFF', text2='#98989F', rand='#8E8E93', akzent='#A6FF00', auf='#000000', akzentF='#A6FF00', aufF='#000000'),
}

# Gemeinsame Farben: Ringfarben (Ahmeds Vorgabe, nur auf schwarzer Ringplatte) und Text-Varianten (Tief) fuer helle/dunkle Flaechen
RING = dict(bewegen='#FA114F', trainieren_h='#2DBE4F', trainieren_d='#A6FF00', erholen_h='#0A9FE0', erholen_d='#00E0F0')
PLATTE = '#000000'
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
        out.append((g, 'aufAkzentFlaeche auf akzentFlaeche (Hauptknopf)', p['aufF'], p['akzentF'], 4.5))
        t = TIEF[md]
        for k in ('bewegen', 'trainieren', 'erholen'):
            out.append((g, f'{k}-Tief auf flaeche', t[k], p['flaeche'], 4.5))
            out.append((g, f'{k}-Tief auf grund', t[k], p['grund'], 4.5))
        for k in ('gut', 'warn', 'schlecht'):
            out.append((g, f'{k} auf flaeche', t[k], p['flaeche'], 4.5))
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
        r = cr(fg, bg)
        ok = r >= m
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
