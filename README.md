# tablet_org

Kompletny zasób FiveM z tabletem organizacji dostosowanym do najnowszego ESX.
Interfejs NUI mieści się w widoku gry, został oprawiony w ramkę tabletu i
umożliwia z poziomu panelu tworzyć oraz utrzymywać organizację (dowolna nazwa,
właściciel, motto, komunikat rekrutacyjny, skarbiec, plan dnia i notatki). Dane są
zapisywane w bazie MySQL przy użyciu `oxmysql`.

## Instalacja

1. Skopiuj katalog `resources/tablet_org` do folderu `resources/` na swoim
   serwerze FiveM.
2. Upewnij się, że posiadasz aktualną wersję `es_extended` (ESX) udostępniającą
   import `@es_extended/imports.lua`.
3. Zainstaluj i uruchom zasób [`oxmysql`](https://github.com/overextended/oxmysql)
   (wymagany do zapisu danych w bazie).
4. Zaimportuj do swojej bazy danych następującą strukturę (zmodyfikuj nazwę
   tabeli, jeśli zmienisz ją w konfiguracji):

   ```sql
   CREATE TABLE IF NOT EXISTS `tablet_organizations` (
     `id` INT NOT NULL AUTO_INCREMENT,
     `name` VARCHAR(128) NOT NULL,
     `owner` VARCHAR(64) NOT NULL,
     `motto` TEXT NULL,
     `recruitment_message` TEXT NULL,
     `funds` INT NOT NULL DEFAULT 0,
     `note` TEXT NULL,
     `daily_plan` LONGTEXT NULL,
     `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
     `updated_at` DATETIME NULL,
     PRIMARY KEY (`id`)
   ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
   ```

   Zasób podczas startu samodzielnie utworzy brakujące kolumny, więc ręczna
   migracja jest wymagana tylko przy pierwszym wdrożeniu.

5. Dodaj w `server.cfg` wpisy uruchamiające zależności w odpowiedniej kolejności,
   np.:

   ```cfg
   ensure oxmysql
   ensure tablet_org
   ```

## Konfiguracja

Plik `resources/tablet_org/config.lua` udostępnia podstawowe ustawienia:

- `Config.OpenCommand` – komenda otwierająca tablet (domyślnie `tabletorg`).
- `Config.DefaultKey` – sugerowany klawisz przypięty do komendy (`F10`).
- `Config.AllowedJobs` – tabela z nazwami prac ESX uprawnionych do korzystania z
  panelu (pozostaw puste, aby umożliwić dostęp każdemu).
- `Config.DatabaseTable` – nazwa tabeli MySQL przechowującej konfigurację
  organizacji.
- `Config.MaxMottoLength`, `Config.MaxRecruitmentLength`, `Config.MaxNoteLength`
  – maksymalna długość treści w formularzach tabletu.
- `Config.MaxFundsAdjustment` – maksymalna jednorazowa operacja skarbca.
- `Config.MaxStoredFunds` – limit środków przechowywanych w skarbcu.
- `Config.MaxPlanEntries`, `Config.MaxPlanLabelLength` – ograniczenia liczby
  i długości pozycji planu dnia edytowanego w zakładce kalendarza.

## Użytkowanie w grze

1. Po załadowaniu zasobu gracze mogą wpisać `/tabletorg` (lub przypisany klawisz),
   aby otworzyć tablet.
2. Interfejs podzielony jest na zakładki bocznego menu. Strona główna zbiera
   najważniejsze wskaźniki i skróty do sekcji zarządzania.
3. Formularz konfiguracyjny pozwala nadać nazwę, właściciela, motto i komunikat
   rekrutacyjny. Ponowne zapisanie formularza aktualizuje istniejący rekord –
   zmiana nazwy odświeża datę utworzenia.
4. Zakładka kalendarza umożliwia ułożenie planu dnia do ośmiu pozycji, które są
   automatycznie synchronizowane z bazą i wyświetlane w podglądzie na stronie
   głównej.
5. Zakładka skarbca umożliwia dodawanie i wypłacanie środków z limitem operacji
   i limitem przechowywania definiowanym w konfiguracji.
6. Zakładka notatek zapisuje ważną wiadomość dla organizacji i udostępnia ją w
   podglądzie skrótowym na stronie głównej.
7. Zakładki „Rekrutacja”, „Baza danych”, „Zadania” oraz „Analizy” prezentują
   planszę „W budowie – wkrótce dostępne”, przygotowaną pod przyszłe moduły.

Dane organizacji są ładowane przy starcie zasobu i udostępniane wszystkim
uprawnionym graczom poprzez NUI.

## Struktura zasobu

```
resources/tablet_org/
├── client/main.lua       # logika kliencka, obsługa NUI i fokusu
├── server/main.lua       # walidacja danych, zapis do bazy MySQL, kontrola dostępu
├── config.lua            # ustawienia komendy, klawisza, dostępu i nazwy tabeli
├── fxmanifest.lua        # definicja zasobu
└── html/                 # interfejs tabletu (index.html, styles.css, tablet.js)
```

UI korzysta z wbudowanego formularza i komunikacji NUI, dzięki czemu wszystkie
interakcje (konfiguracja, finanse, notatki) odbywają się pomiędzy klientem i
serwerem FiveM, bez potrzeby uruchamiania dodatkowych usług HTTP.
