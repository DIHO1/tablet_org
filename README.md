# tablet_org

Kompletny zasób FiveM z tabletem organizacji dostosowanym do najnowszego ESX.
Interfejs NUI mieści się w widoku gry i pozwala tworzyć (wyłącznie) organizację
„Best” wraz z przypisaniem właściciela.

## Instalacja

1. Skopiuj katalog `resources/tablet_org` do folderu `resources/` na swoim
   serwerze FiveM.
2. Upewnij się, że posiadasz aktualną wersję `es_extended` (ESX) udostępniającą
   import `@es_extended/imports.lua`.
3. Dodaj w `server.cfg` wpis:

   ```cfg
   ensure tablet_org
   ```

## Konfiguracja

Plik `resources/tablet_org/config.lua` udostępnia podstawowe ustawienia:

- `Config.OpenCommand` – komenda otwierająca tablet (domyślnie `tabletorg`).
- `Config.DefaultKey` – sugerowany klawisz przypięty do komendy (`F10`).
- `Config.AllowedJobs` – tabela z nazwami prac ESX uprawnionych do korzystania z
  panelu (pozostaw puste, aby umożliwić dostęp każdemu).
- `Config.StorageFile` – ścieżka do pliku JSON z zapisaną konfiguracją
  organizacji.

## Użytkowanie w grze

1. Po załadowaniu zasobu gracze mogą wpisać `/tabletorg` (lub przypisany klawisz),
   aby otworzyć tablet.
2. Panel wyświetla aktualny status organizacji, pozwala wskazać właściciela oraz
   zapisuje dane na serwerze.
3. Formularz akceptuje wyłącznie nazwę „Best” – pozostałe nazwy zostaną
   odrzucone z odpowiednim komunikatem.

Dane organizacji są przechowywane w `resources/tablet_org/data/organization.json`
(zapis następuje automatycznie po utworzeniu/aktualizacji).

## Struktura zasobu

```
resources/tablet_org/
├── client/main.lua       # logika kliencka, obsługa NUI i fokusu
├── server/main.lua       # walidacja danych, zapisywanie JSON, kontrola dostępu
├── config.lua            # ustawienia komendy, klawisza i dostępu
├── fxmanifest.lua        # definicja zasobu
└── html/                 # interfejs tabletu (index.html, styles.css, tablet.js)
```

UI korzysta z wbudowanego formularza i komunikacji NUI, dzięki czemu nie wymaga
żadnego dodatkowego zaplecza HTTP. Wszystkie interakcje odbywają się pomiędzy
klientem i serwerem FiveM.

