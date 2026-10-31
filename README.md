# Franc-Tireur : Opération Écho (CEFR A1 – A2 – B1)

A 3D First-Person Tactical Sharpshooter built in **Godot 4.7.2** and **Blender 4.2 LTS** specifically engineered to take English speakers from **CEFR A1** through **CEFR A2 and B1** in French listening comprehension, spatial/comparative reasoning, and intermediate grammar.

---

## ✨ CEFR A1 → A2 → B1 Curriculum Overview

1. **45 Sculpted 3D Vocabulary Models Across 9 Thematic Sectors**:
   - **Secteurs 1–4 (A1 / A1+)**: *Ravitaillement* (`la pomme`, `le fromage`, `le pain`, `la bouteille`, `la tasse`), *Quartiers & Mobilier* (`le livre`, `la clé`, `l'horloge`, `la lanterne`, `les lunettes`), *Armurerie Historique* (`l'épée`, `le bouclier`, `la couronne`, `le chapeau`, `le marteau`), *Biosphère & Cosmos* (`la fleur`, `le cœur`, `le poisson`, `l'étoile`, `la fusée`).
   - **Secteurs 5–7 (A2)**: *Voyages & Transports* (`l'avion`, `le train`, `la voiture`, `le vélo`, `la valise`), *Technologie & Médias* (`l'ordinateur`, `le téléphone`, `l'appareil photo`, `le microphone`, `la batterie`), *Ville & Quotidien* (`le parapluie`, `le sac à dos`, `la chaussure`, `la chaise`, `la guitare`).
   - **Secteurs 8–9 (B1)**: *Santé, Urgences & Société* (`le médicament`, `l'ambulance`, `la lettre`, `le journal`, `le cadeau`), *Environnement, Énergie & Travail* (`l'arbre`, `le nuage`, `le soleil`, `l'usine`, `le globe terrestre`).
2. **A2 3D Spatial, Comparative & Motion Drills (`MODIFIER` Mode)**:
   - Evaluates real 3D physical properties of spawned drones: **superlative scale** (*le plus grand*, *le plus petit*), **comparative speed** (*le plus rapide*, *le plus lent*, *immobile*), **vertical elevation** (*le plus haut*, *le plus bas*), and **lateral positioning** (*à gauche*, *à droite*, *au milieu*).
3. **DELF A2–B1 Situational Listening Dialogues (`SCENARIO` Mode)**:
   - 16 multi-clause situational announcements, weather forecasts, travel disruptions, and emergency dispatches requiring inference of the correct 3D target without hearing its name in isolation.
4. **A2–B1 Holographic Data-Crystal Grammar & Phonetic Breaches (`GRAMMAR` Mode)**:
   - 16 grammar and phonetic discrimination challenges using glowing `holo_crystal.blend` targets:
     - *Passé composé* (*être* vs *avoir* & past participle agreement) vs *Imparfait*
     - Direct & indirect object pronouns (*le, la, les, lui, leur*) and adverbial pronouns (*y, en*)
     - Conditional & *Si*-clauses (*Si + présent → futur*, *Si + imparfait → conditionnel présent*)
     - *Subjonctif présent* after expressions of necessity, emotion, and concession (*il faut que*, *bien que*, *craindre que*)
     - Temporal connectors (*depuis*, *pendant*, *dans*) and oral phonetic traps (*ils ont* `/il.zɔ̃/` vs *ils sont* `/il.sɔ̃/`, silent plural `-ent` vs pronounced `-ant`).

---

## 🚀 Play Immediately

### 1. In Your Browser (WebGL2 / WebAssembly Build)
The exported web build is located in `build/web/` and served via `/home/jovyan/GAME/serve_web.py` on port **8081**:
```bash
python3 /home/jovyan/GAME/serve_web.py 8081 /home/jovyan/GAME/franc_tireur/build/web
```
Open `http://localhost:8081` (or your port-forwarded URL on port `8081`) and click **▶ LANCER LA MISSION** to unlock browser audio & mouse look.

### 2. Native Linux x86_64 Executable
```bash
/home/jovyan/GAME/franc_tireur/build/linux/franc_tireur.x86_64
```

### 3. Open in Godot 4 Editor
```bash
godot --editor --path /home/jovyan/GAME/franc_tireur
```

---

## 🎮 Controls

| Input | Action |
| :--- | :--- |
| **WASD / ZQSD / Arrows** | Move (uses physical keycodes — works on both QWERTY & French AZERTY!) |
| **Mouse / Q & E** | Aim camera (Q/E provides smooth keyboard horizontal turn on trackpads) |
| **Left-Click / F** | Fire Acoustic Carbine (`blaster.blend`) |
| **Right-Click / V** | Aim-Down-Sights (ADS Zoom) to inspect distant 3D Blender silhouettes |
| **E** | Replay current French radio order at normal native speed |
| **R** | **Slow Articulated Replay (-28%)** + IPA & English-speaker phonics/grammar rule |
| **H** | **Progressive Scaffolding Hint** (1st press: French transcript • 2nd press: English L1 / Grammar Rule) |
| **Tab** | Open **Live SRS Mastery Matrix** (filter by `Tous (45)`, `A1`, `A2`, `B1`, or `Grammaire A2–B1 (16)`) |
| **G** | Enter **Galerie de Reconnaissance** (`[1]`–`[9]` switches sectors 1–9, `[M]` resumes combat) |
| **Esc** | Return to Mission Menu / Release Mouse |

---

## ⚙️ Automated GitHub Actions Build & Release Pipeline

This repository includes [`.github/workflows/build-and-publish.yml`](.github/workflows/build-and-publish.yml), which automatically:
1. Installs **Blender 4.2.23 LTS** and **Godot 4.7.2-stable** + official export templates in CI.
2. Imports all 49 `.blend` 3D models and 329 `.ogg` neural French audio assets headlessly.
3. Builds and packages **4 ready-to-play distributions**:
   - 🌐 **GitHub Pages Live WebGL2 Build** (deployed automatically via `actions/deploy-pages@v4`)
   - 🪟 **`FrancTireur-Windows-x86_64.zip`** (`FrancTireur.exe` + `.pck`)
   - 🐧 **`FrancTireur-Linux-x86_64.zip`** (`franc_tireur.x86_64` + `play-franc-tireur.sh`)
   - 🍎 **`FrancTireur-macOS-Universal.zip`** (`Franc-Tireur.app` for Apple Silicon & Intel)
4. Publishes the downloadable desktop archives directly to **GitHub Releases** on every push to `main` or `v*` tag.

---

## 🛠️ Regenerating Assets from Scratch

- **Regenerate all 49 custom 3D `.blend` models via headless Blender 4.2:**
  ```bash
  blender --background --python tools/generate_blender_assets.py
  ```
- **Regenerate all 322 native French neural voice clips & 7 procedural SFX:**
  ```bash
  python3 tools/generate_audio.py
  ```
- **Run automated headless SRS + 8-screenshot visual verification:**
  ```bash
  xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . -- --verify-screenshots
  ```
