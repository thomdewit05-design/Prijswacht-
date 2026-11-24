# Prijswacht

Bewaakt de prijs van wat je online koopt en helpt je het verschil terug te
vragen als die prijs daalt binnen je retourtermijn.

- Concept: [docs/concept.md](docs/concept.md)
- Stand van zaken: [docs/status.md](docs/status.md)

- Prijsstudie: [study/README.md](study/README.md)
- Server: [server/README.md](server/README.md)

## Bouwen

Rekenlogica testen (macOS of Linux):

```bash
cd ios/PrijswachtCore && swift test
```

App openen in Xcode (macOS, met [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

```bash
cd ios && xcodegen generate && open Prijswacht.xcodeproj
```
