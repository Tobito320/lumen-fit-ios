#!/usr/bin/env python3
"""XLIFF (xcodebuild -exportLocalizations) <-> String Catalog (.xcstrings), Englisch zu Deutsch als Quelle.

  liste  <en.xliff> <aus.json>                 Alle Schlüssel je Tabelle mit Notiz und vorhandener Übersetzung.
  bauen  <uebersetzt.json> <ziel-ordner>       Schreibt/aktualisiert <Tabelle>.xcstrings je Ziel (vorhandene en-Werte bleiben, neue kommen dazu).

uebersetzt.json: {"<ziel>/<Tabelle>": {"<schlüssel>": "<englisch>"}}; ziel ist "LumenFit" oder "LumenFitWidgets".
"""
import json, os, sys
import xml.etree.ElementTree as ET

NS = {"x": "urn:oasis:names:tc:xliff:document:1.2"}


def tabelle(original: str) -> str:
    # "LumenFit/de.lproj/Localizable.strings" -> "LumenFit/Localizable"; Info.plist-Texte -> InfoPlist
    teile = original.replace("\\", "/").split("/")
    ziel = "LumenFitWidgets" if "LumenFitWidgets" in teile else "LumenFit"
    name = os.path.splitext(teile[-1])[0]
    if name in ("Info", "InfoPlist"):
        name = "InfoPlist"
    return f"{ziel}/{name}"


def liste(xliff: str, aus: str) -> None:
    baum = ET.parse(xliff)
    ergebnis: dict = {}
    for f in baum.getroot().findall("x:file", NS):
        t = tabelle(f.get("original", ""))
        for u in f.iter(f"{{{NS['x']}}}trans-unit"):
            schluessel = u.get("id")
            quelle = u.findtext("x:source", default="", namespaces=NS)
            notiz = u.findtext("x:note", default="", namespaces=NS)
            ziel = u.findtext("x:target", default=None, namespaces=NS)
            ergebnis.setdefault(t, {})[schluessel] = {"de": quelle, "notiz": notiz, "en": ziel}
    with open(aus, "w", encoding="utf-8") as d:
        json.dump(ergebnis, d, ensure_ascii=False, indent=1, sort_keys=True)
    print(sum(len(v) for v in ergebnis.values()), "Schlüssel in", len(ergebnis), "Tabellen")


def bauen(uebersetzt: str, ordner: str) -> None:
    daten = json.load(open(uebersetzt, encoding="utf-8"))
    for t, werte in daten.items():
        ziel, name = t.split("/", 1)
        pfad = os.path.join(ordner, ziel, "Resources", f"{name}.xcstrings")
        katalog = {"sourceLanguage": "de", "strings": {}, "version": "1.0"}
        if os.path.exists(pfad):
            katalog = json.load(open(pfad, encoding="utf-8"))
        for k, en in werte.items():
            eintrag = katalog["strings"].setdefault(k, {})
            if not en:
                continue
            loc = eintrag.setdefault("localizations", {})
            if "en" not in loc:
                loc["en"] = {"stringUnit": {"state": "translated", "value": en}}
        os.makedirs(os.path.dirname(pfad), exist_ok=True)
        with open(pfad, "w", encoding="utf-8") as d:
            json.dump(katalog, d, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : "))
            d.write("\n")
        print(pfad, len(katalog["strings"]))


def selbsttest() -> None:
    import tempfile
    x = """<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" version="1.2">
 <file original="LumenFit/de.lproj/Localizable.strings" source-language="de" target-language="en" datatype="plaintext"><body>
  <trans-unit id="%lld Sets" xml:space="preserve"><source>%lld Sets</source><note>Zahl</note></trans-unit>
  <trans-unit id="Heute" xml:space="preserve"><source>Heute</source><target>Today</target></trans-unit>
 </body></file>
 <file original="LumenFit/Info.plist" source-language="de" target-language="en" datatype="plaintext"><body>
  <trans-unit id="NSCameraUsageDescription" xml:space="preserve"><source>Kamera</source></trans-unit>
 </body></file>
</xliff>"""
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, "en.xliff"); open(p, "w").write(x)
        liste(p, os.path.join(tmp, "l.json"))
        l = json.load(open(os.path.join(tmp, "l.json")))
        assert l["LumenFit/Localizable"]["Heute"]["en"] == "Today"
        assert "NSCameraUsageDescription" in l["LumenFit/InfoPlist"]
        u = os.path.join(tmp, "u.json")
        json.dump({"LumenFit/Localizable": {"%lld Sets": "%lld sets", "Heute": "Today"}}, open(u, "w"))
        bauen(u, tmp)
        json.dump({"LumenFit/Localizable": {"Heute": "Now", "Neu": "New"}}, open(u, "w"))
        bauen(u, tmp)
        k = json.load(open(os.path.join(tmp, "LumenFit/Resources/Localizable.xcstrings")))
        assert k["strings"]["Heute"]["localizations"]["en"]["stringUnit"]["value"] == "Today"  # vorhandenes bleibt
        assert k["strings"]["Neu"]["localizations"]["en"]["stringUnit"]["value"] == "New"
        assert k["strings"]["%lld Sets"]["localizations"]["en"]["stringUnit"]["value"] == "%lld sets"
    print("selbsttest ok")


if __name__ == "__main__":
    befehl = sys.argv[1] if len(sys.argv) > 1 else ""
    if befehl == "liste" and len(sys.argv) == 4:
        liste(sys.argv[2], sys.argv[3])
    elif befehl == "bauen" and len(sys.argv) == 4:
        bauen(sys.argv[2], sys.argv[3])
    elif befehl == "selbsttest":
        selbsttest()
    else:
        sys.exit(__doc__)
