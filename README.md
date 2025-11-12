# tablet_org

Kompletny zasób FiveM z tabletem organizacji dostosowanym do najnowszego ESX.
Interfejs NUI mieści się w widoku gry i pozwala z poziomu tabletu tworzyć oraz
aktualizować organizację (dowolna nazwa i właściciel), a dane są zapisywane w
bazie MySQL przy użyciu `oxmysql`.

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
     `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
     PRIMARY KEY (`id`)
   ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
   ```

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

## Użytkowanie w grze

1. Po załadowaniu zasobu gracze mogą wpisać `/tabletorg` (lub przypisany klawisz),
   aby otworzyć tablet.
2. Panel wyświetla aktualny status organizacji, pozwala wpisać dowolną nazwę i
   właściciela oraz zapisuje dane w bazie danych.
3. Ponowne zapisanie formularza aktualizuje istniejący rekord – zmiana nazwy
   odświeża datę utworzenia, natomiast modyfikacja właściciela zachowuje
   wcześniejszą datę.

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
interakcje odbywają się pomiędzy klientem i serwerem FiveM, bez potrzeby
uruchamiania dodatkowych usług HTTP.
