# Validation — Factorio 2.0.77, Windows, 3 octobre 2026

Les tests utilisent l'installation réelle de Factorio, avec des profils, mods, surfaces et sauvegardes isolés. La partie ouverte de l'utilisateur n'est pas utilisée par les tests.

## Géométrie et moteur

Suites exécutées avec le jeu de base, puis avec le mod officiel Quality :

- **4 056 assertions Lua** : axes, diagonales, huit orientations, 360 angles comparés à une recherche exhaustive indépendante, coordonnées négatives, phases entières/demi-entières, grilles de 1 et 2 tuiles, rayons fractionnaires, très grandes couvertures, petites portées de câble et repli borné.
- **200 contrôles moteur de couverture** : petits/moyens/grands poteaux, sous-station et prototype atypique avec sélection décalée. Des consommateurs électriques de taille 1/128 tuile sondent les frontières à la précision de 1/256 tuile. Vérification de la connexion électrique effective.
- **132 contrôles moteur de placement** : emplacement autorisé, position réellement arrondie, portée des câbles, appartenance au même réseau et obstacle.
- **90 contrôles des descripteurs et espacements maximaux** sans Quality ; **450 avec Quality**, sur des prototypes vanilla et atypiques, les cinq qualités et huit orientations.
- Chargement du mod distribué, sauvegarde et rechargement dans les deux configurations : aucune erreur Lua/API.
- Test supplémentaire de persistance dans le vrai `storage` du mod : deux entrées ON/OFF indépendantes et une référence de poteau valide sont conservées après sauvegarde/rechargement. Ces entrées de test sont créées explicitement par console dans le profil isolé ; elles ne représentent pas deux clients réseau.

Les tests ont décelé une erreur de la description API : dans 2.0.77, `building_grid_bit_shift` expose directement 1 ou 2, et non leur logarithme. Les fixtures imposent explicitement ces deux grilles pour prévenir une régression.

## Drag natif — 40 scénarios, 0 échec

La dernière passe complète a réussi les **40 scénarios**. L'utilisateur a également confirmé le bon fonctionnement lors de son propre essai en jeu.

Le banc `simulation-probe/production` charge **le véritable control.lua du mod**. Il maintient le contrôle de construction via `LuaSimulation.control_down`, déplace le curseur via `move_cursor`, puis relâche via `control_up`. Les événements observés proviennent du moteur ; ce ne sont pas des événements de construction fabriqués par le test.

La matrice couvre :

- Les quatre poteaux vanilla en horizontal, vertical, diagonale, courbe progressive et trajectoire légèrement oscillante.
- Les distances maximales exactes sur axes/diagonales et les contraintes de couverture/câble entre chaque paire.
- Mode OFF, bascule ON/OFF en gardant le poteau sélectionné, état indépendant d'un second joueur simulé.
- Prolongement d'une ligne depuis un poteau existant.
- Inventaire limité à trois objets avec consommation exacte, curseur vide ensuite.
- Four bloquant la trajectoire : obstacle conservé, aucun chevauchement illégal.
- Ghosts : maintien du comportement vanilla.
- Sous-station légendaire.
- Poteaux moddés : couverture 64 avec câble court, rayon fractionnaire, empreinte 5×5, sélection décalée, rectangle 2×1, grilles explicites 1/2 et auto-connexion cuivre désactivée.
- Fallbacks : couverture nulle, hors grille et empreinte empêchant une chaîne continue.
- Personnage qui marche réellement avec portée de construction normale, petits et grands poteaux.

Le contrôle natif simulé du raccourci est vérifié séparément du mouvement. `LuaSimulation.control_press` remplace le contrôle actuellement maintenu : le test réaffirme donc `build` après la bascule, en conservant le curseur et ses objets. Il ne prouve pas un maintien simultané de deux périphériques physiques.

Les captures sont rendues par Factorio avec son aperçu natif des zones électriques. Elles permettent de contrôler visuellement les jonctions, y compris les carrés se touchant par un coin en diagonale.

## Reproduire avec le banc développeur

Le banc moteur complet est conservé dans l'environnement de développement et n'est pas inclus dans l'archive du portail. Les tests purs `tests/geometry_spec.lua` sont inclus dans cette archive. Les commandes suivantes supposent que l'on dispose aussi du dossier développeur `continuous-pole-placement-tests`.

Depuis le dossier parent du projet, avec Factorio installé au chemin configuré dans les lanceurs :

```powershell
python .\continuous-pole-placement-tests\run-headless.py
python .\continuous-pole-placement-tests\run-headless.py --quality
& .\continuous-pole-placement-tests\simulation-probe\production\launch.ps1
```

Le dernier lanceur conserve l'identifiant de **son propre processus** dans `process-id.txt`. Ses résultats sont dans `runtime/script-output/cpp-production/results.json`, ses événements dans `events.jsonl`, et les PNG dans le même dossier. Arrêter uniquement ce processus après le test. Ne pas lancer deux instances utilisant le même profil simultanément.

Les rapports base/Quality et empreintes des sources sont dans `continuous-pole-placement-tests/reports`. Le code du banc et ses prototypes artificiels ne sont pas nécessaires au fonctionnement du mod.

## Périmètre non vérifié

Pas de session réseau avec deux ordinateurs/clients réels, ni de test exhaustif de tous les mods tiers. L'indépendance de deux joueurs est contrôlée dans le moteur de simulation. Aucun test sur une autre version binaire que **2.0.77**. Les ghosts restent intentionnellement vanilla. Les obstacles infranchissables, la portée du joueur et la rupture de stock peuvent interrompre la continuité ; ils ne sont pas contournés artificiellement.
