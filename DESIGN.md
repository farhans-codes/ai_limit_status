---
name: AI Limit Status
description: Codex and Claude usage limits read like a station departure board.
colors:
  housing: "#141518"
  housing-edge: "#26282d"
  board-face: "#0f1012"
  tile-top: "#26292e"
  tile-bottom: "#1c1e22"
  tile-split: "#0b0c0e"
  flap: "#f2c14e"
  flap-dim: "#b8913a"
  board-white: "#ece8dd"
  board-muted: "#a7a398"
  enamel: "#e9ebe6"
  enamel-raised: "#f4f5f1"
  enamel-ink: "#121315"
  enamel-muted: "#4c4f55"
  enamel-rule: "#c9ccc5"
  signal: "#b8361f"
  signal-lit: "#ff6a4d"
  signal-ink: "#fff7f2"
typography:
  display:
    fontFamily: "Barlow Condensed, Arial Narrow, sans-serif"
    fontSize: "clamp(2.6rem, 6.4vw, 5.6rem)"
    fontWeight: 700
    lineHeight: 0.92
    letterSpacing: "-0.012em"
  headline:
    fontFamily: "Barlow Condensed, Arial Narrow, sans-serif"
    fontSize: "clamp(2.4rem, 4.6vw, 3.6rem)"
    fontWeight: 700
    lineHeight: 0.95
  title:
    fontFamily: "Barlow Condensed, Arial Narrow, sans-serif"
    fontSize: "clamp(1.45rem, 2.2vw, 1.8rem)"
    fontWeight: 700
    lineHeight: 1.1
  body:
    fontFamily: "Barlow, Helvetica Neue, Arial, sans-serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.6
    fontFeature: "tnum"
  label:
    fontFamily: "Barlow Condensed, Arial Narrow, sans-serif"
    fontSize: "0.85rem"
    fontWeight: 600
    letterSpacing: "0.12em"
  mono:
    fontFamily: "ui-monospace, SF Mono, Menlo, Consolas, monospace"
    fontSize: "0.88em"
rounded:
  tile: "3px"
  control: "4px"
  plate: "6px"
  board: "10px"
  sign: "16px"
spacing:
  gutter: "clamp(16px, 4vw, 48px)"
  measure: "68ch"
  container: "1180px"
  flap-gap: "6px"
components:
  plate:
    backgroundColor: "{colors.enamel-ink}"
    textColor: "{colors.enamel}"
    rounded: "{rounded.plate}"
    padding: "0.38em 0.6em 0.32em"
  plate-signal:
    backgroundColor: "{colors.signal}"
    textColor: "{colors.signal-ink}"
    rounded: "{rounded.plate}"
  platform-sign:
    backgroundColor: "{colors.enamel}"
    textColor: "{colors.enamel-ink}"
    rounded: "{rounded.sign}"
    padding: "clamp(18px, 2.4vw, 26px) clamp(20px, 2.6vw, 30px)"
  platform-sign-hover:
    backgroundColor: "{colors.flap}"
    textColor: "{colors.enamel-ink}"
  platform-sign-active:
    backgroundColor: "{colors.enamel-ink}"
    textColor: "{colors.enamel}"
  flap-tile:
    backgroundColor: "{colors.tile-top}"
    textColor: "{colors.flap}"
    rounded: "{rounded.tile}"
  button-copy:
    backgroundColor: "transparent"
    textColor: "{colors.flap}"
    rounded: "{rounded.control}"
    padding: "8px 12px"
  button-copy-active:
    backgroundColor: "{colors.flap}"
    textColor: "{colors.housing}"
---

# Design System: AI Limit Status

Scope: this system governs the marketing site in `site/` (GitHub Pages) only. The Flutter desktop app in `lib/` has its own UI and is out of scope.

## Overview

**Creative North Star: "The Departure Hall"**

Usage limits are read like a station departure board. Each provider is a service, each reset is a scheduled time, and macOS and Windows are the two platforms you board from. The top of the page is the hall: a black board housing with split-flap tiles in flap yellow. Everything below it is station enamel signage: off-white enamel, black lettering, rounded plate corners, ruled ledgers.

Density is high and orderly, like a timetable. Hierarchy comes from condensed uppercase signage and heavy rules, not from cards or gradients. Colour is literal to the world: yellow is flap ink, red is a low-limit signal, and nothing glows without a reason.

**Key Characteristics:**
- Two material zones: dark housing (board, header, footer) and light enamel (content).
- Split-flap tiles with a lighter top leaf, darker bottom leaf and a hairline split.
- Condensed signage grotesque for every heading and label, its regular cut for reading text.
- Tabular digits throughout.
- Ruled ledgers (2px ink top rule, 1px enamel-rule dividers) instead of card grids.

## Colors

A black-and-enamel station palette with one ink colour (flap yellow) and one alarm (signal red).

### Primary
- **Flap Yellow** (flap): characters on split-flap tiles, the clock, hover state of links and platform signs, focus outlines, text selection.
- **Dim Flap Brass** (flap-dim): quiet yellow for outlines on dark (copy button border, scrollbar thumb).

### Secondary
- **Signal Red** (signal): background of the alert notice and signal plates. Only for limits and alerts.
- **Lit Signal** (signal-lit): flap characters for a low remaining limit.
- **Signal Paper** (signal-ink): text on signal red.

### Neutral
- **Board Housing** (housing): header strip, board hall, footer, page edge.
- **Housing Edge** (housing-edge): 1-2px rules inside the housing.
- **Board Face** (board-face): the recessed board panel and the code well on dark.
- **Tile Top / Tile Bottom / Tile Split**: the two leaves and hairline of every flap tile.
- **Board White** (board-white) and **Board Muted** (board-muted): text and labels on dark.
- **Enamel** (enamel), **Enamel Raised** (enamel-raised): content background and inline code fill.
- **Enamel Ink** (enamel-ink): lettering, heavy rules, plate fill.
- **Enamel Muted** (enamel-muted): body copy and captions on enamel.
- **Enamel Rule** (enamel-rule): 1px dividers on enamel.

### Named Rules
**The Signal Only Rule.** Red appears only to mean a low limit or an alert. Never decorative.

**The Flap Ink Rule.** Yellow is the colour of characters on the board and of interaction (hover, focus, selection). It is not a fill for large enamel areas, except a platform sign under the pointer.

## Typography

**Display Font:** Barlow Condensed 500/600/700 (with Arial Narrow)
**Body Font:** Barlow 400/500/600 (with Helvetica Neue, Arial)
**Label/Mono Font:** system monospace for commands and code

**Character:** A condensed station grotesque for signage, paired with its own regular cut for reading. Self-hosted woff2 with `font-display: swap`.

### Hierarchy
- **Display** (700, clamp(2.6rem, 6.4vw, 5.6rem), 0.92, uppercase, balanced, max 13ch): the board title only.
- **Headline** (700, clamp(2.4rem, 4.6vw, 3.6rem), 0.95, uppercase): platform sign names, ledger numerals.
- **Title** (700, clamp(1.45rem, 2.2vw, 1.8rem), 1.1, uppercase): item headings in ledgers and notes.
- **Body** (400, 1.0625rem, 1.6, tabular numerals): reading text, max 68ch on enamel.
- **Label** (600, 0.85rem, 0.12-0.14em tracking, uppercase): board column labels, clock label, copy button. Nav and footer links use the same face at 1.05rem, 0.04-0.05em tracking.

### Named Rules
**The Tabular Rule.** Every digit on the page is tabular; times and percentages must not shift when they change.

**The Signage Case Rule.** Condensed type is set uppercase; Barlow reading text is never uppercase.

## Layout

A single column of full-bleed bands (housing, enamel, housing) with content capped at 1180px and side padding `gutter`. Section padding is clamp(56px, 8vw, 104px) top. The board table is a four-column grid sized in flap cells (`--cell`, clamp(16px, 2vw, 26px)) plus 6px gaps; below 960px each row restacks into service + remaining, then limit, then reset, and column labels hide. Platform signs sit two-up and stack below 960px. Content below the hall is ledger-ruled lists, a two-column notes list, and an 880px FAQ.

## Elevation & Depth

Mostly flat enamel; depth is reserved for physical objects in the world: the board panel, the flap tiles, the platform signs and the product screenshot.

### Shadow Vocabulary
- **Board panel** (`0 18px 28px -18px rgba(0,0,0,0.7), inset 0 1px 0 rgba(255,255,255,0.04)`): the board recessed in its housing.
- **Flap tile** (`0 2px 3px rgba(0,0,0,0.55)`): each tile sits proud of the board.
- **Enamel sign** (`inset 0 0 0 3px <fill>, inset 0 0 0 5px enamel-ink, 0 10px 18px -12px rgba(0,0,0,0.7)`): pressed rim and dark bezel of a platform sign.
- **Screenshot** (`0 24px 48px -24px rgba(18,19,21,0.45)`): the product photo on enamel.

### Named Rules
**The Object Depth Rule.** Only things that exist physically in a station cast shadows. Text blocks, ledgers and sections stay flat.

## Shapes

Small, plate-like corners: tiles 3px, controls and code 4px, plates and notices 6px, the board 10px, platform signs 16px, the screenshot 14px. The platform number is a full circle. Rules are the main structural device: 2px ink rules open each list, 1px rules divide rows.

## Components

### Plate (section titles)
Enamel ink plate with condensed uppercase lettering, 0.06em tracking, 6px radius. Section headings are set as plates. A signal variant carries red.

### Platform Sign (primary download action)
- **Shape:** 16px radius, double inset rim (enamel then ink), soft drop shadow.
- **Content:** circled platform number, OS name in headline type, action line in Barlow 600, muted meta at right (stacks on mobile).
- **Hover:** fill turns flap yellow, lifts 2px. **Active:** inverts to ink with enamel lettering. Motion uses `cubic-bezier(0.16, 1, 0.3, 1)`, 0.2s; removed under reduced motion.

### Split-Flap Tile (signature)
Cell-sized tile (height 1.42 x width), two-leaf gradient, hairline split, condensed 600 character in flap yellow (lit signal when low). On load the board riffles characters row by row (70ms flip per turn); reduced motion shows final values at once.

### Copy Button
Ghost on dark: transparent, flap text, 1px flap-dim border, 4px radius, label type. Hover tints 12% flap; active or done fills flap with housing text.

### Navigation
Header strip in housing: app icon and name in condensed 700 at left; uppercase condensed links in board-muted at right, flap on hover. Below 960px only the last link remains. Footer repeats the link style in board-white.

### Ledger and Notes
Numbered ledger rows (big condensed numeral + title + muted body) and a two-column definition list, both opened with a 2px ink rule and divided with 1px enamel-rule lines.

## Do's and Don'ts

### Do:
- **Do** keep the housing / enamel split: dark for the board, header and footer; enamel for content.
- **Do** set headings as uppercase Barlow Condensed and reading text in Barlow with tabular digits.
- **Do** use flap yellow (`#f2c14e`) for board characters, hover and focus (3px outline, 3px offset).
- **Do** structure lists with ruled ledgers (2px ink top, 1px dividers).
- **Do** honour reduced motion: no flap riffle, no sign lift.

### Don't:
- **Don't** use signal red for anything but a low limit or an alert.
- **Don't** add shadows to text blocks, sections or lists; depth belongs to board objects and signs.
- **Don't** set Barlow reading text in uppercase or condensed type in sentence-case body.
- **Don't** apply this system to the Flutter app in `lib/`.
