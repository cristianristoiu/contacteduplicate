# Contacte Duplicate - ghid tema UI

## Scop

Acest document defineste directia vizuala pentru aplicatia mobila Contacte Duplicate, Android si iOS.

Tema trebuie sa fie unitara in toata aplicatia. Nu se folosesc teme diferite pe ecrane separate.

## Moduri globale

Aplicatia suporta trei optiuni in Settings:

- Light
- Dark
- Follow system

Regula obligatorie: tema aleasa se aplica global pe toate ecranele.

## Principii vizuale

- Interfata moderna, curata, premium, fara aglomerare.
- Carduri rotunjite, umbre discrete si spatii generoase.
- Accent principal albastru-electric cu violet.
- Datele sensibile sunt prezentate clar, fara senzatie de risc sau actiune ascunsa.
- Ecranele de confirmare trebuie sa arate explicit ce se modifica inainte de merge.

## Logo si icon

Fisier principal:

- `docs/theme/design/logo.svg`

Logo-ul este gandit ca icon de aplicatie si nu contine text. Pentru store listing, splash screen sau pagina de branding se poate folosi logo-ul impreuna cu textul `ContacteDuplicate`.

Reguli pentru icon:

- Pentru iOS: export PNG 1024x1024, fara transparenta.
- Pentru Android: foloseste adaptive icon cu foreground separat si background gradient.
- Nu se adauga text mic in icon.
- Nu se folosesc elemente de brand Google, Apple, iCloud sau Outlook in icon.

## Culori principale

### Brand

| Token | Valoare | Utilizare |
| --- | --- | --- |
| `brand.navy.950` | `#061126` | fundal dark principal |
| `brand.navy.900` | `#0D1839` | card dark / icon base |
| `brand.navy.800` | `#111F4C` | suprafete dark |
| `brand.blue.500` | `#25D8FF` | accent scanare / merge |
| `brand.blue.600` | `#1F8BFF` | butoane principale |
| `brand.violet.500` | `#5B35D5` | accent secundar |
| `brand.violet.400` | `#8D5CFF` | gradient si highlight |

### Light mode

| Token | Valoare | Utilizare |
| --- | --- | --- |
| `light.background` | `#F5F8FF` | fundal general |
| `light.surface` | `#FFFFFF` | carduri, liste, bottom sheets |
| `light.surfaceMuted` | `#EDF3FF` | filtre, zone info |
| `light.textPrimary` | `#121A33` | titluri |
| `light.textSecondary` | `#596584` | descrieri |
| `light.border` | `#E1E7F5` | linii si card borders |

### Dark mode

| Token | Valoare | Utilizare |
| --- | --- | --- |
| `dark.background` | `#061126` | fundal general |
| `dark.surface` | `#0D1839` | carduri principale |
| `dark.surfaceMuted` | `#101B45` | carduri secundare |
| `dark.textPrimary` | `#FFFFFF` | titluri |
| `dark.textSecondary` | `#AEBCE4` | descrieri |
| `dark.border` | `#273661` | separatori si contururi |

### Status

| Token | Valoare | Utilizare |
| --- | --- | --- |
| `status.success` | `#24B47E` | merge finalizat, scor sigur |
| `status.warning` | `#FFB020` | verificare manuala |
| `status.error` | `#EF4444` | eroare permisiune / scriere |
| `status.info` | `#25D8FF` | informatii si scanare |

## Tipografie

Font recomandat:

- iOS: SF Pro prin sistem.
- Android: Roboto prin sistem.
- Flutter: `ThemeData.useMaterial3 = true`, fara font custom obligatoriu in MVP.

Scala recomandata:

| Rol | Marime | Greutate |
| --- | --- | --- |
| Display | 34-40 | 800 |
| H1 | 28-32 | 800 |
| H2 | 22-24 | 700 |
| Body | 15-17 | 400/500 |
| Label | 13-14 | 600 |
| Caption | 12-13 | 400 |

## Spacing si radius

| Token | Valoare |
| --- | --- |
| `space.xs` | 4 |
| `space.sm` | 8 |
| `space.md` | 16 |
| `space.lg` | 24 |
| `space.xl` | 32 |
| `radius.sm` | 10 |
| `radius.md` | 16 |
| `radius.lg` | 24 |
| `radius.xl` | 32 |
| `radius.icon` | 28-32% din dimensiune |

## Componente UI

### Buton principal

- Fundal: gradient blue/violet sau `brand.blue.600`.
- Text alb.
- Inaltime minima: 52 px.
- Radius: 16-20 px.
- Nu se foloseste pentru actiuni periculoase.

### Buton secundar

- Fundal transparent sau surface.
- Border subtil.
- Text `brand.blue.600`.

### Card contact

Contine:

- avatar cu initiala
- nume contact
- numar contacte in grup
- motiv potrivire
- scor incredere
- badge status

### Badge scor

- 95-100: `Sigur`, verde.
- 80-94: `Probabil`, albastru.
- 60-79: `Verifica manual`, portocaliu.
- sub 60: ascuns implicit sau doar in mod audit.

### Progress ring

Folosit pe dashboard si scanare.

- Ring background: border muted.
- Ring active: gradient blue/violet.
- Text central: numar duplicate sau procent scanare.

### Bottom navigation

Tab-uri:

- Acasa
- Duplicate
- Backup
- Setari

Reguli:

- maxim 4 itemi in MVP
- icon simplu + label
- aria/tap target minim 44 px

## Ecrane principale

1. Onboarding permisiuni
2. Dashboard
3. Grupuri duplicate
4. Detalii grup si alegere campuri
5. Previzualizare merge
6. Backup
7. Istoric / undo
8. Setari

## Accesibilitate

- Contrast minim WCAG AA.
- Textele nu trebuie sa fie doar color-coded; foloseste si etichete text.
- Toate actiunile critice au confirmare.
- Tap target minim 44x44 pt.
- Suport pentru text scaling.

## Reguli de continut UI

Textele trebuie sa fie scurte si explicite:

- `Datele raman pe dispozitiv.`
- `Nu modificam nimic fara confirmarea ta.`
- `Backup creat inainte de modificare.`
- `Acest grup necesita verificare manuala.`

Nu se foloseste limbaj agresiv sau promisiuni absolute precum `100% fara risc`.
