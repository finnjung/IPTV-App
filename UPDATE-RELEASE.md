# Fire TV App Update Release Anleitung

## Übersicht

Die streameee Fire TV App prüft beim Start automatisch auf Updates und zeigt einen Update-Dialog an, wenn eine neue Version verfügbar ist.

```
Server: https://streameee.tv/
├── app                     # Kurzer Download-Link (Redirect)
├── dl/
│   └── streameee.apk       # Aktuelle APK für Download-Link
└── update/
    ├── manifest.json       # Enthält Versioninfo + APK-URL
    └── streameee-vX.Y.Z.apk # Versionierte APK für Updates
```

**Wichtig:** Das Deploy-Skript lädt die APK an BEIDE Stellen hoch:
- `/dl/streameee.apk` → für den kurzen Link `streameee.tv/app`
- `/update/streameee-vX.Y.Z.apk` → für das Auto-Update-System

---

## Schnellstart: Neues Release veröffentlichen

### 1. Version in pubspec.yaml erhöhen

```yaml
# pubspec.yaml
version: 1.0.1+2  # Format: VERSION+VERSIONCODE
```

**Wichtig:**
- `VERSION` (1.0.1) = Anzeige für User
- `VERSIONCODE` (2) = Integer, muss bei jedem Release erhöht werden!

### 2. Dependencies installieren (einmalig)

```bash
npm install
```

### 3. APK bauen und hochladen

```bash
# Mit Build:
node deploy-apk.js --build --notes "- Neue Features\n- Bugfixes"

# Oder nur hochladen (wenn APK bereits gebaut):
node deploy-apk.js --notes "- Neue Features"
```

---

## Detaillierte Anleitung

### Schritt 1: Version erhöhen

Öffne `pubspec.yaml` und erhöhe die Version:

```yaml
# Von:
version: 1.0.0+1

# Zu:
version: 1.0.1+2
```

**Regeln für Versionierung:**
- **Major** (1.x.x): Große Änderungen, Breaking Changes
- **Minor** (x.1.x): Neue Features
- **Patch** (x.x.1): Bugfixes
- **VersionCode** (+N): MUSS bei jedem Release erhöht werden (1, 2, 3, ...)

### Schritt 2: APK bauen

```bash
flutter build apk --release
```

Die APK wird erstellt unter:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Schritt 3: Deploy-Skript ausführen

```bash
# Mit automatischem Build:
node deploy-apk.js --build --notes "- Feature X hinzugefügt\n- Bug Y behoben"

# Ohne Build (APK muss existieren):
node deploy-apk.js --notes "- Feature X hinzugefügt"

# Force Update (User MUSS updaten):
node deploy-apk.js --build --force --notes "- Kritisches Sicherheitsupdate"
```

### Schritt 4: Verifizieren

```bash
# Manifest prüfen:
curl https://streameee.tv/update/manifest.json

# APK erreichbar?
curl -I https://streameee.tv/update/streameee-v1.0.1.apk
```

---

## Deploy-Skript Optionen

| Option | Beschreibung |
|--------|--------------|
| `--build` | APK vor Upload bauen |
| `--notes "..."` | Release Notes setzen |
| `--force` | Force Update aktivieren (User kann nicht überspringen) |

### Beispiele

```bash
# Normales Release:
node deploy-apk.js --build --notes "- Neue Streaming-Features\n- Performance verbessert"

# Hotfix:
node deploy-apk.js --build --notes "- Kritischer Bugfix"

# Kritisches Sicherheitsupdate:
node deploy-apk.js --build --force --notes "- Sicherheitslücke geschlossen"
```

---

## manifest.json Format

Das Skript erstellt automatisch die `manifest.json`:

```json
{
  "version": "1.0.1",
  "versionCode": 2,
  "apkUrl": "https://streameee.tv/update/streameee-v1.0.1.apk",
  "releaseNotes": "- Neue Features\n- Bugfixes",
  "forceUpdate": false
}
```

| Feld | Beschreibung |
|------|--------------|
| `version` | Anzeige-Version (z.B. "1.0.1") |
| `versionCode` | Integer, muss höher sein als installierte Version |
| `apkUrl` | Download-URL der APK |
| `releaseNotes` | Text für Update-Dialog |
| `forceUpdate` | `true` = User muss updaten, `false` = "Später" möglich |

---

## Testen

### Auf Fire TV testen

1. App mit niedrigem versionCode installieren:
   ```bash
   # In pubspec.yaml: version: 0.0.1+0
   flutter build apk --release
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

2. Höhere Version auf Server deployen:
   ```bash
   # In pubspec.yaml: version: 1.0.0+1
   node deploy-apk.js --build --notes "Test-Update"
   ```

3. App starten → Update-Dialog sollte erscheinen

### Lokaler Server-Test

```bash
# Manifest abrufen:
curl https://streameee.tv/update/manifest.json

# Erwartete Ausgabe:
{
  "version": "1.0.0",
  "versionCode": 1,
  "apkUrl": "https://streameee.tv/update/streameee-v1.0.0.apk",
  "releaseNotes": "- Erste Version",
  "forceUpdate": false
}
```

---

## Fehlerbehebung

### "FTP-Konfiguration fehlt"
→ `.env.ftp` Datei erstellen (siehe `.env.ftp.example`)

### "APK nicht gefunden"
→ Zuerst `flutter build apk --release` ausführen oder `--build` Flag verwenden

### Update-Dialog erscheint nicht
1. Prüfen ob versionCode auf Server HÖHER ist als installierte Version
2. Prüfen ob manifest.json erreichbar: `curl https://streameee.tv/update/manifest.json`
3. Prüfen ob App auf Fire TV läuft (Update-Check nur auf TV-Geräten)

### Download schlägt fehl
1. APK-URL in manifest.json prüfen
2. APK auf Server erreichbar? `curl -I https://streameee.tv/update/streameee-vX.Y.Z.apk`

---

## Checkliste für Release

- [ ] Version in `pubspec.yaml` erhöht (sowohl VERSION als auch VERSIONCODE)
- [ ] Änderungen getestet
- [ ] Release Notes geschrieben
- [ ] `node deploy-apk.js --build --notes "..."` ausgeführt
- [ ] manifest.json auf Server geprüft
- [ ] APK-Download getestet
- [ ] Update-Flow auf Fire TV getestet
