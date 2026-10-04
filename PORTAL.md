# Continuous Pole Placement

Drag a line of electric poles with **continuous electric coverage**. Each new pole is placed as far along the build path as its supply area, wire reach and placement grid allow.

Vanilla dragging primarily follows wire reach. This mod adds an optional mode that keeps successive blue supply squares touching or overlapping, so you can quickly cover a wall, production line or long construction route.

## How to use

1. Hold any supported electric pole.
2. Press **Alt + P**, or click **Continuous pole coverage** in the shortcut bar.
3. Hold your normal build control and move.
4. Toggle OFF to return to vanilla placement.

The highlighted shortcut means ON. The key binding is configurable in **Settings → Controls → Mods**. The mode is OFF by default and saved separately for each player.

## Features

- Small poles, medium poles, big poles and substations.
- Generic support for modded poles and modified prototypes: no hardcoded pole names or vanilla spacing values.
- Quality-aware supply areas and wire reach.
- Horizontal, vertical, diagonal and gently curving routes.
- Normal item consumption, collision checks and player build reach.
- A small backward adjustment along the path when the optimal position is obstructed.
- English and French translations.
- Event-driven implementation: no permanent tick handler, surface scans or replacement pole items.

## Compatibility and limits

Requires **Factorio 2.0.77 or newer within the 2.0 release series**. Tested on Factorio **2.0.77**, with and without Quality. Space Age is not required.

The mode applies to normal manual construction. **Ghosts, blueprints and forced building retain vanilla behavior.** Off-grid poles and unsupported prototypes fall back to vanilla.

Obstacles, insufficient reach, empty inventory or large jumps of the cursor can interrupt coverage. The mod does not create free poles or place them through buildings. If native drag builds earlier to supply an existing consumer, that behavior is retained.

In diagonal lines, supply squares may touch at a corner. This is continuous coverage, but it does not create a corridor of constant width.

Each player has an independent setting. Two-player state isolation was tested using Factorio's simulation engine; a live multi-client network session has not been tested.

## Validation

Validated with 40 native-drag scenarios, 4,056 geometry assertions, engine checks for electrical coverage and placement, all five qualities, atypical modded poles, obstacles, inventory exhaustion and save/reload. The initial release was also tested in game by its author.

The source is included in the mod archive and available on [GitHub](https://github.com/ydepledt/continuous-pole-placement). Report bugs or suggest improvements through [GitHub Issues](https://github.com/ydepledt/continuous-pole-placement/issues). Licensed under **MIT**.

---

## Français

**Placez des poteaux à la distance maximale compatible avec une couverture électrique continue.**

Prenez un poteau en main, activez le bouton **Couverture continue des poteaux** ou utilisez **Alt + P**, puis maintenez la construction en vous déplaçant. Le bouton surligné indique ON. Le raccourci est configurable dans les contrôles des mods ; chaque joueur possède son propre état sauvegardé.

Le calcul utilise les propriétés réelles du prototype et la qualité : couverture carrée, portée du câble et grille de placement. Le mode OFF restitue le comportement vanilla. Les poteaux moddés compatibles sont reconnus automatiquement.

La construction manuelle normale est prise en charge. Les ghosts, blueprints et constructions forcées restent vanilla. Les obstacles infranchissables, la portée de construction et le manque de poteaux peuvent interrompre la continuité. En diagonale, les zones peuvent se toucher uniquement par un coin.

Testé sous Factorio 2.0.77. Anglais et français inclus. Licence MIT.

[Code source sur GitHub](https://github.com/ydepledt/continuous-pole-placement) · [Signaler un problème ou proposer une amélioration](https://github.com/ydepledt/continuous-pole-placement/issues).
