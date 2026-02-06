# Implementierungsanleitung: Speech-to-Text und Backup-Export

## Übersicht

Diese Anleitung beschreibt die Implementierung von:
1. **Native iOS Speech-to-Text** - Ersetzt die browserbasierte SpeechRecognition
2. **Backup-Export** - Ermöglicht das Herunterladen von Backup-Dateien via Share Sheet

## Dateien die erstellt/geändert werden müssen

### 1. Info.plist Einträge

Fügen Sie folgende Einträge in Ihre Info.plist hinzu (über Xcode Target > Info):

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Die App verwendet Spracherkennung für die Diktatfunktion.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Die App benötigt Mikrofonzugriff für die Spracheingabe.</string>
```

### 2. Architektur-Übersicht

```
┌─────────────────┐     JS Bridge      ┌──────────────────┐
│   index.html    │ ←───────────────→ │  ContentView     │
│   (WebView)     │  postMessage/     │  (SwiftUI)       │
│                 │  evaluateJS       │                  │
└─────────────────┘                    └──────────────────┘
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    │                         │                         │
            ┌───────▼───────┐         ┌───────▼───────┐         ┌───────▼───────┐
            │ WKWebView     │         │ Speech        │         │ FileManager   │
            │ Configuration │         │ Framework     │         │ + Share Sheet │
            └───────────────┘         └───────────────┘         └───────────────┘
```

### 3. JavaScript-API für die HTML-Seite

Die HTML-Seite kommuniziert mit Swift über:

**Nachrichten an Swift senden:**
```javascript
// Spracheingabe starten
window.webkit.messageHandlers.diktat.postMessage({befehl: 'an'});

// Spracheingabe stoppen  
window.webkit.messageHandlers.diktat.postMessage({befehl: 'aus'});

// Backup exportieren
window.webkit.messageHandlers.sicherung.postMessage({
    text: JSON.stringify(backupDaten),
    name: 'backup_' + Date.now() + '.json'
});
```

**Callbacks von Swift empfangen:**
```javascript
// Erkannter Text
window.dText = function(text) {
    console.log('Erkannt:', text);
};

// Status-Änderung (true = aufnahme läuft)
window.dStatus = function(aktiv) {
    console.log('Aufnahme:', aktiv ? 'läuft' : 'gestoppt');
};

// Fehler bei Spracheingabe
window.dFehler = function(nachricht) {
    console.error('Fehler:', nachricht);
};

// Export erfolgreich
window.eOK = function() {
    console.log('Export erfolgreich');
};

// Export-Fehler
window.eFehler = function(nachricht) {
    console.error('Export-Fehler:', nachricht);
};
```

## Test-Anleitung

1. **Projekt in Xcode öffnen**
2. **Info.plist Berechtigungen hinzufügen** (siehe oben)
3. **Auf echtem Gerät testen** (Simulator unterstützt kein Mikrofon)
4. **Spracheingabe testen:**
   - Button in WebView antippen
   - Berechtigung erteilen wenn gefragt
   - Sprechen und Text-Erkennung prüfen
5. **Backup testen:**
   - Daten eingeben
   - Export-Button antippen
   - Share Sheet sollte erscheinen
   - "In Dateien sichern" wählen

## Wichtige Hinweise

- Die Speech-to-Text Funktion benötigt ein **echtes Gerät** (kein Simulator)
- Beide Berechtigungen müssen vom Nutzer **erteilt** werden
- Das Share Sheet funktioniert auf **iPhone und iPad**
- Für iPad wird automatisch ein **Popover** verwendet
