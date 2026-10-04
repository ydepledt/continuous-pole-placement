# Continuous Pole Placement

Mod Factorio 2.0 : couverture électrique continue lors du placement de poteaux en déplacement. Anglais et français inclus. Aucun poteau vanilla ou moddé n'est modifié.

[Télécharger sur le portail Factorio](https://mods.factorio.com/mod/continuous-pole-placement) · [Sources GitHub](https://github.com/ydepledt/continuous-pole-placement) · [Signaler un problème](https://github.com/ydepledt/continuous-pole-placement/issues)

## Installation et utilisation

Copier `continuous-pole-placement_0.1.0.zip` dans le dossier `mods` de Factorio, activer le mod et redémarrer le jeu. Sous Windows : `%APPDATA%/Factorio/mods`.

1. Prendre un poteau électrique en main.
2. Activer **Couverture continue des poteaux** dans la barre de raccourcis, ou appuyer sur **Alt + P**.
3. Maintenir la construction et se déplacer, comme en vanilla.
4. Cliquer à nouveau sur le bouton ou réutiliser la touche pour revenir au placement vanilla.

Le bouton surligné indique **ON**. Une indication locale confirme chaque bascule. La touche se configure dans **Settings / Controls / Mods**. Le bouton peut être ajouté ou retiré via la configuration habituelle de la barre de raccourcis. Le mode est désactivé par défaut et mémorisé séparément pour chaque joueur dans la sauvegarde. Éviter un raccourci contenant Maj si l'on veut basculer pendant le drag : Maj est aussi le modificateur vanilla de construction de ghosts.

## Fonctionnement

Le mod observe `on_pre_build`, y compris les positions que le drag natif parcourt sans y construire. Quand la prochaine limite de couverture est atteinte, il utilise `can_build_from_cursor` puis `build_from_cursor`. Le moteur consomme l'objet tenu et met à jour sa propre ancre de drag. Une garde empêche la récursion des événements générés par cette construction.

Ce comportement a été vérifié expérimentalement dans Factorio 2.0.77 avec les commandes natives de construction maintenue de `LuaSimulation`. Il ne repose pas sur un événement d'annulation fictif ou sur un état inventé du bouton de souris.

Le mode OFF quitte immédiatement le gestionnaire : aucune construction scriptée, aucun remplacement d'objet, aucune modification de prototype. Il n'y a aucun abonnement `on_tick` ni balayage de surface dans le mod distribué. Seul le clic initial effectue une recherche ponctuelle pour reconnaître le poteau existant à prolonger. Les scénarios de test ont leurs propres boucles de simulation, séparées du mod.

### Géométrie

La couverture est un carré centré sur le poteau, de demi-côté `prototype.get_supply_area_distance(quality)`. Elle n'est pas agrandie par la boîte de collision. La portée du câble vient de `prototype.get_max_wire_distance(quality)`.

Pour deux positions séparées par `(dx, dy)`, les contraintes sont :

```
abs(dx) <= r1 + r2
abs(dy) <= r1 + r2
dx*dx + dy*dy <= min(w1, w2)^2
```

Sur une direction unitaire `(ux, uy)`, la borne avant arrondi vaut :

```
min((r1+r2) / max(abs(ux), abs(uy)), min(w1, w2))
```

La grille vient de `building_grid_bit_shift`. **Particularité vérifiée dans Factorio 2.0.77 : cette propriété renvoie la taille 1 ou 2, malgré sa description « log2 » dans la documentation.** Des prototypes de test imposant chacune des deux tailles contrôlent cette convention ; il ne faut pas exponentier la valeur. Sa phase est celle de la position réellement construite : cela conserve les centres entiers/demi-entiers choisis par le moteur pour les dimensions du prototype. Le module parcourt les cellules arrondies de la trajectoire près de la borne, vérifie de nouveau les deux contraintes, puis essaie la position la plus avancée. Il ne classe pas la trajectoire en quelques angles prédéfinis.

Les limites sont mises en cache par nom de prototype et qualité, après les modifications des autres mods. Elles sont recalculées au chargement et lors d'un changement de configuration. Les valeurs vanilla ne sont présentes que dans les tests, jamais dans le code de placement.

### Obstacles et inventaire

Chaque construction passe par la validation native du curseur : collision, portée de construction du joueur, terrain, conditions de surface et disponibilité de l'objet. Si le meilleur emplacement est bloqué, le mod essaie un petit recul sur la même trajectoire arrondie, limité à trois tuiles et douze candidats. Il ne cherche pas de détour.

Si aucun candidat ne convient, Factorio conserve la main et un message local signale l'interruption. **La continuité ne peut pas être garantie à travers un obstacle infranchissable, un saut important du curseur, une zone hors de portée ou une rupture de stock.** Aucun poteau gratuit n'est créé.

## Limites et compatibilité

- L'API ne permet pas de remplacer directement l'algorithme interne du drag ni de lire en permanence le bouton maintenu. L'insertion anticipée par l'API normale est le contournement utilisé.
- La construction manuelle normale est prise en charge. **Ghosts, blueprints et modes de construction forcée restent vanilla**, même si le bouton est ON. Leur espacement n'est pas garanti par ce mod.
- Un clic indépendant démarre une nouvelle ligne. Changer de type ou de qualité du poteau, de surface ou de contrôleur démarre également une nouvelle ligne.
- Les prototypes sans couverture positive, sans portée de câble positive, hors grille ou avec placement à huit directions utilisent le fallback vanilla, accompagné d'une indication locale.
- L'espacement maximal est celui de la **trajectoire arrondie sur la grille**, avec les contraintes électriques et physiques. Un changement réel d'angle peut changer le résultat d'une tuile. Le mod ne sacrifie pas la continuité pour masquer ces transitions.
- En diagonale, deux carrés peuvent se toucher uniquement par un coin : cela assure leur continuité, mais pas une bande de largeur constante. Les machines doivent rester dans les zones bleues.
- Factorio peut encore placer un poteau plus tôt pour alimenter un consommateur non desservi. Cette logique native est conservée.
- Pour les poteaux dont l'auto-connexion est désactivée, le mod demande explicitement une connexion cuivre entre les deux poteaux successifs, avec contrôle natif de portée. Si les règles de connexion l'empêchent, un message le signale ; aucun fil existant n'est supprimé.
- La compatibilité avec des scripts qui remplacent ou suppriment les poteaux au cours des mêmes événements dépend de leurs propres comportements. Les références d'entités sont vérifiées avant chaque utilisation.

## Architecture

| Fichier | Responsabilité |
| --- | --- |
| `data.lua` | Raccourci configurable et bouton natif |
| `control.lua` | Abonnements aux événements et cycle de vie |
| `scripts/state.lua` | État par joueur et synchronisation ON/OFF |
| `scripts/poles.lua` | Détection générique et cache par prototype/qualité |
| `scripts/geometry.lua` | Calculs purs, grille et candidats bornés |
| `scripts/placement.lua` | Drag, validation moteur, construction et réentrance |
| `locale/en`, `locale/fr` | Traductions |
| `tests/geometry_spec.lua` | Tests déterministes de la géométrie |

Les tests moteur et de drag sont dans le dossier voisin `continuous-pole-placement-tests`, afin de ne pas distribuer de commandes de test ou d'interface de debug avec le mod. Voir `TESTING.md` pour les résultats réellement exécutés.

## English quick start

Enable the mod, hold an electric pole, press **Alt + P** (configurable under Controls / Mods), then hold your normal build control and move. The native shortcut button is highlighted when ON. Each player has their own saved setting; OFF uses native placement. The mod reads runtime prototypes and item quality, validates grid-snapped square coverage and wire reach, and builds through the normal cursor API. Ghosts and blueprints remain native. Impassable obstacles or insufficient reach/items can interrupt continuous coverage.

## Développement

Le dépôt contient les sources Lua, les traductions, les icônes, les captures en jeu, la documentation et l'outil de création de l'archive installable.

Depuis la racine du dépôt :

```sh
lua tests/geometry_spec.lua
python tools/package.py
```

Les tests purs nécessitent Lua 5.2 ou plus récent. La création de l'archive nécessite Python 3 et utilise uniquement sa bibliothèque standard. L'archive est créée dans `dist/`, qui est exclu de Git. Le banc de tests Factorio complet reste séparé ; `TESTING.md` précise les résultats et les limites de la validation.

La version 0.1.0 publiée sur le portail correspond au code Lua initial. Les modifications de documentation et les liens GitHub ne nécessitent pas de nouvelle version du mod.

La description publique est conservée dans `PORTAL.md`. Pour prévisualiser sa synchronisation et le lien vers les sources :

```sh
python tools/update_portal.py --source-url https://github.com/ydepledt/continuous-pole-placement
```

L'envoi effectif exige `--apply` et une clé Factorio disposant du droit **ModPortal: Edit Mods**, fournie par la variable d'environnement `MOD_EDIT_API_KEY` ou par `--api-key-file` avec un fichier local externe au dépôt. L'outil ne publie pas de nouvelle archive et ne modifie ni la catégorie ni la licence. Ne jamais ajouter une clé API aux fichiers suivis par Git.

## Sources API

- [ElectricPolePrototype](https://lua-api.factorio.com/2.0.77/prototypes/ElectricPolePrototype.html)
- [LuaEntityPrototype](https://lua-api.factorio.com/2.0.77/classes/LuaEntityPrototype.html)
- [LuaPlayer : construction depuis le curseur](https://lua-api.factorio.com/2.0.77/classes/LuaPlayer.html#build_from_cursor)
- [on_pre_build](https://lua-api.factorio.com/2.0.77/events.html#on_pre_build)
- [Explication officielle des événements de drag](https://forums.factorio.com/viewtopic.php?t=95189)

Licence MIT.
