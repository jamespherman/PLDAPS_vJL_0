# Analyse comportementale SRS_Task_Smooth

Ce dossier contient une chaine d'analyse MATLAB autonome pour les fichiers `trialXXXX.mat` produits par `SRS_Task_Smooth`. Elle ne depend pas de `pds.loadP` et ne modifie jamais les donnees originales.

## Demarrage recommande

1. Extraire tout le dossier `SRS_behavior_analysis` dans un emplacement permanent.
2. Ouvrir MATLAB et placer le **Current Folder** dans ce dossier.
3. Ouvrir puis executer `SELF_TEST_UPLOADED_SESSION.m` sur la session de reference.
4. Ouvrir `RUN_ONE_SRS_SESSION.m`, verifier `sessionFolder`, puis cliquer sur **Run**.
5. Pour plusieurs sessions, modifier la liste de dossiers dans `RUN_ALL_SRS_SESSIONS.m`, puis l'executer.

Le script principal cree par defaut un sous-dossier :

```text
<dossier_de_session>/offline_behavior_analysis
```

Une autre destination peut etre imposee avec `options.outputRoot` dans le script de lancement.

## Fichiers MATLAB

### `RUN_ONE_SRS_SESSION.m`

Point d'entree pour une session. C'est le fichier a modifier au quotidien. Les options principales y sont commentees : nombre de permutations, fenetre glissante, creation des figures et dossier de sortie.

### `RUN_ALL_SRS_SESSIONS.m`

Analyse plusieurs sessions separement, puis construit une analyse concatenee. Les dependances sequentielles restent calculees a l'interieur de chaque session afin de ne pas creer artificiellement une transition entre deux jours.

### `SELF_TEST_UPLOADED_SESSION.m`

Test de non-regression de la session `20260720_t1112_srsSmooth_training`. Il verifie les comptes attendus, les variables derivees, les statistiques principales et l'ecriture des fichiers de sortie. Il desactive seulement les figures pendant le test afin de pouvoir tourner sur une machine sans affichage.

### `srs_load_session.m`

Charge tous les `trialXXXX.mat`, construit une table avec une ligne par tentative et ajoute notamment :

- succes ou echec de l'essai
- instruction, conflit ou congruent
- identite et cote de T1/T2
- cible riche et cible tres saillante
- choix identitaire et spatial
- choix riche, choix saillant, perseveration et changement
- recompenses, differences de teinte et de luminance
- RT saccadique, latence de fixation, duree de saccade et duree d'essai
- intervalle entre essais, ordre dans le bloc et informations de debug

Un choix n'entre dans l'inference comportementale que si `RealEyeChoice=1`, donc avec `passEye=0` et `mouseEyeSim=0`.

### `srs_compute_statistics.m`

Effectue les analyses suivantes :

- qualite et completion de la session
- controle du contrebalancement
- biais droite/gauche et T1/T2
- preference pour la cible riche ou tres saillante
- perseveration identitaire et spatiale
- comparaison de 16 strategies candidates
- associations conditionnelles par tables 2 x 2
- evolution entre le premier et le dernier tiers
- psychometrie binee de la saillance continue
- reproduction statistique des online plots
- temps de reaction conflit versus congruent
- exploration, stay/switch et effet de la recompense precedente
- analyse par bloc
- indices operationnels de desengagement
- regressions logistiques multivariees lorsque `fitglm` est disponible

### `srs_make_figures.m`

Produit quatre ensembles de figures :

1. reproduction et extension des online plots
2. diagnostic des strategies spatiales, identitaires, de valeur et de saillance
3. qualite, engagement et point d'arret
4. psychometrie, evolution debut-fin, associations et tendances temporelles

### `srs_write_report.m`

Ecrit `analysis_report.txt`, qui rassemble les resultats principaux et les limites d'interpretation dans un format lisible sans manipuler les tables MATLAB.

## Fichiers de sortie principaux

| Fichier | Contenu |
|---|---|
| `trial_table.csv` | Une ligne par tentative avec variables brutes et derivees |
| `summary_statistics.csv` | Resume general et qualite des donnees |
| `balance_checks.csv` | Contrebalancement du plan |
| `bias_statistics.csv` | Biais droite, T1, riche, saillance et perseveration |
| `strategy_comparison.csv` | Precision de chaque strategie candidate et confusions entre strategies |
| `conditional_associations.csv` | Effets conditionnels valeur, saillance, identite, cote et choix precedent |
| `choice_evolution_early_late.csv` | Comparaison premier versus dernier tiers |
| `psychometric_binned.csv` | P(T1) selon l'evidence de saillance |
| `online_choice_statistics.csv` | Statistiques correspondant aux choix des online plots |
| `online_timeseries_statistics.csv` | Resume et tendance des variables continues |
| `reaction_time_statistics.csv` | RT globaux, conflit et congruent |
| `engagement_early_vs_late.csv` | Comparaison de l'engagement au debut et a la fin |
| `block_completion.csv` | Completion et essais manquants par bloc |
| `logistic_models.csv` | Modeles multivaries optionnels |
| `analysis_report.txt` | Rapport texte complet |
| `analysis_results.mat` | Table et structures MATLAB sauvegardees |

## Interpretation des statistiques

Les proportions binaires sont comparees a 0.5 avec un test binomial exact bilateral et un intervalle de Wilson a 95 %. Les associations conditionnelles utilisent un test exact bilateral de Fisher et un odds ratio avec correction de Haldane-Anscombe. Les differences de RT, les comparaisons debut-fin et les correlations temporelles sont testees par permutation.

Les p-values sont exploratoires. Comme de nombreuses mesures sont examinees, une conclusion confirmatoire doit reposer sur une hypothese definie a l'avance, une correction des comparaisons multiples ou une replication sur plusieurs sessions.

La comparaison de strategies ne suffit pas a identifier une politique lorsque plusieurs strategies font exactement les memes predictions. Le fichier `strategy_comparison.csv` indique ces confusions dans `IndistinguishableFrom`. Par exemple, dans un bloc ou T2 est toujours riche, `Toujours T2` et `Choisit la cible riche` ne peuvent pas etre separees. Il faut alterner l'identite riche entre plusieurs blocs.

## Desengagement et ennui

Le code ne mesure pas l'ennui subjectif. Il cherche seulement des indices operationnels :

- hausse des echecs
- intervalles entre essais plus longs
- RT plus longs
- acquisition de fixation plus lente
- serie d'au moins trois echecs consecutifs
- bloc interrompu avant son nombre d'essais attendu

Une estimation de desengagement est retenue uniquement lorsque plusieurs indices concordent, ou lorsqu'une serie explicite d'echecs apparait. Elle est automatiquement neutralisee pour les sessions `passEye` ou simulees.

## Resultat de la session transmise

La session `20260720_t1112_srsSmooth_training` est une session de debug, pas une mesure du comportement de Newton :

- 99 tentatives sauvegardees sur 100 programmees
- 99 succes, dont 20 instructions et 79 choix a deux cibles
- 39 choix congruents et 40 choix en conflit
- `passEye=1` et `passJoy=1` sur toutes les tentatives
- `mouseEyeSim=0`
- T2 est la cible riche pendant le bloc
- les 79 choix a deux cibles vont vers T2, donc vers la cible riche
- 40 choix sont a droite et 39 a gauche selon le cote occupe par T2
- en congruent, 39/39 choix vont vers la cible tres saillante
- en conflit, 0/40 choix vont vers la cible tres saillante
- aucun RT saccadique valide selon `fixOff -> saccadeOnset`
- aucune incoherence entre identite choisie et cote choisi
- duree approximative : 3.99 minutes

Dans le code de cette version de la tache, `passEye` choisit automatiquement la cible riche sur les essais a deux cibles. Les resultats parfaits pour T2 et la cible riche sont donc generes par le programme. Le ratio 40 droite contre 39 gauche ne constitue pas un biais de Newton. Il reflète simplement l'alternance du cote de T2 dans le plan.

Pour une vraie session comportementale, verifier avant le lancement :

```matlab
passEye    = 0;
passJoy    = 0;
mouseEyeSim = 0;
```

## Compatibilite et validation

Le code utilise les tables et strings MATLAB et vise MATLAB R2019b ou plus recent. Les analyses principales n'exigent que MATLAB de base. `fitglm` ajoute les regressions logistiques si la Statistics and Machine Learning Toolbox est installee.

La session transmise a ete relue independamment avec SciPy afin de verifier les comptes de reference. Un environnement MATLAB n'etait pas disponible lors de la construction du dossier, donc l'execution native finale doit etre confirmee sur la machine du laboratoire avec `SELF_TEST_UPLOADED_SESSION.m`.
