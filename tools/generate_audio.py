#!/usr/bin/env python3
"""
Neural French Voiceover & Procedural SFX Generator for FRANC-TIREUR : Opération Écho (Édition Complète CEFR A1–B1)
Uses edge-tts (fr-FR-HenriNeural & fr-FR-DeniseNeural) + numpy + ffmpeg to produce compact Ogg Vorbis files.
Skips any .ogg file already generated on disk for fast incremental builds.
"""

import asyncio
import os
import subprocess
import tempfile
import wave
import numpy as np
import edge_tts

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "audio"))
VOICE_DIR = os.path.join(BASE_DIR, "voice")
SFX_DIR = os.path.join(BASE_DIR, "sfx")
os.makedirs(VOICE_DIR, exist_ok=True)
os.makedirs(SFX_DIR, exist_ok=True)

VOICE_M = "fr-FR-HenriNeural"
VOICE_F = "fr-FR-DeniseNeural"

VOCAB_AUDIO = [
    # === SECTORS 1–4 (CEFR A1 / A1+) ===
    {
        "id": "pomme",
        "word": "Une pomme. La pomme.",
        "cmd_m": "Tirez sur la pomme !",
        "cmd_f": "Ciblez la pomme !",
        "slow": "La pomme. Une pomme.",
        "desc": "C'est un fruit rouge et croquant qui pousse dans un arbre.",
        "inhibit": "Attention ! Ne tirez pas sur le fromage — tirez sur la pomme !",
    },
    {
        "id": "fromage",
        "word": "Un fromage. Le fromage.",
        "cmd_m": "Abattez le fromage !",
        "cmd_f": "Visez le fromage !",
        "slow": "Le fromage. Un fromage.",
        "desc": "C'est un aliment jaune fait avec du lait, plein de petits trous.",
        "inhibit": "Ne touchez pas au pain — visez le fromage !",
    },
    {
        "id": "pain",
        "word": "Un pain. Le pain.",
        "cmd_m": "Visez le pain !",
        "cmd_f": "Tirez sur le pain !",
        "slow": "Le pain. Un pain.",
        "desc": "C'est une baguette dorée qu'on achète à la boulangerie.",
        "inhibit": "Attention ! Ne tirez pas sur le poisson — abattez le pain !",
    },
    {
        "id": "bouteille",
        "word": "Une bouteille. La bouteille.",
        "cmd_m": "Détruisez la bouteille !",
        "cmd_f": "Ciblez la bouteille !",
        "slow": "La bouteille. Une bouteille.",
        "desc": "C'est un récipient vert en verre, fermé par un bouchon.",
        "inhibit": "Ne tirez pas sur la tasse — détruisez la bouteille !",
    },
    {
        "id": "tasse",
        "word": "Une tasse. La tasse.",
        "cmd_m": "Ciblez la tasse !",
        "cmd_f": "Abattez la tasse !",
        "slow": "La tasse. Une tasse.",
        "desc": "On la tient par l'anse le matin pour boire du café chaud.",
        "inhibit": "Ne visez pas la bouteille — tirez sur la tasse !",
    },
    {
        "id": "livre",
        "word": "Un livre. Le livre.",
        "cmd_m": "Tirez sur le livre !",
        "cmd_f": "Visez le livre !",
        "slow": "Le livre. Un livre.",
        "desc": "Il a beaucoup de pages blanches et on l'ouvre pour lire une histoire.",
        "inhibit": "Ne touchez pas à la clé — ciblez le livre !",
    },
    {
        "id": "cle",
        "word": "Une clé. La clé.",
        "cmd_m": "Abattez la clé !",
        "cmd_f": "Tirez sur la clé !",
        "slow": "La clé. Une clé.",
        "desc": "C'est un petit objet en métal doré qui ouvre une serrure.",
        "inhibit": "Attention ! Ne tirez pas sur l'horloge — visez la clé !",
    },
    {
        "id": "horloge",
        "word": "Une horloge. L'horloge.",
        "cmd_m": "Visez l'horloge !",
        "cmd_f": "Détruisez l'horloge !",
        "slow": "L'horloge. Une horloge.",
        "desc": "Elle a deux aiguilles qui tournent pour indiquer l'heure.",
        "inhibit": "Ne tirez pas sur la lanterne — abattez l'horloge !",
    },
    {
        "id": "lanterne",
        "word": "Une lanterne. La lanterne.",
        "cmd_m": "Neutralisez la lanterne !",
        "cmd_f": "Ciblez la lanterne !",
        "slow": "La lanterne. Une lanterne.",
        "desc": "Elle brille d'une flamme chaude pour éclairer dans l'obscurité.",
        "inhibit": "Ne visez pas les lunettes — tirez sur la lanterne !",
    },
    {
        "id": "lunettes",
        "word": "Des lunettes. Les lunettes.",
        "cmd_m": "Ciblez les lunettes !",
        "cmd_f": "Tirez sur les lunettes !",
        "slow": "Les lunettes. Des lunettes.",
        "desc": "On les pose sur le nez avec deux verres pour mieux voir.",
        "inhibit": "Ne touchez pas au livre — visez les lunettes !",
    },
    {
        "id": "epee",
        "word": "Une épée. L'épée.",
        "cmd_m": "Tirez sur l'épée !",
        "cmd_f": "Abattez l'épée !",
        "slow": "L'épée. Une épée.",
        "desc": "C'est une longue lame tranchante utilisée par un chevalier.",
        "inhibit": "Attention ! Ne tirez pas sur le bouclier — visez l'épée !",
    },
    {
        "id": "bouclier",
        "word": "Un bouclier. Le bouclier.",
        "cmd_m": "Abattez le bouclier !",
        "cmd_f": "Visez le bouclier !",
        "slow": "Le bouclier. Un bouclier.",
        "desc": "On le tient devant soi au combat pour se protéger des coups.",
        "inhibit": "Ne tirez pas sur l'épée — ciblez le bouclier !",
    },
    {
        "id": "couronne",
        "word": "Une couronne. La couronne.",
        "cmd_m": "Visez la couronne !",
        "cmd_f": "Ciblez la couronne !",
        "slow": "La couronne. Une couronne.",
        "desc": "C'est un cercle d'or orné de joyaux que porte un roi sur la tête.",
        "inhibit": "Ne touchez pas au chapeau — tirez sur la couronne !",
    },
    {
        "id": "chapeau",
        "word": "Un chapeau. Le chapeau.",
        "cmd_m": "Ciblez le chapeau !",
        "cmd_f": "Tirez sur le chapeau !",
        "slow": "Le chapeau. Un chapeau.",
        "desc": "C'est un accessoire à bord large qu'on met sur la tête.",
        "inhibit": "Attention ! Ne tirez pas sur le marteau — visez le chapeau !",
    },
    {
        "id": "marteau",
        "word": "Un marteau. Le marteau.",
        "cmd_m": "Détruisez le marteau !",
        "cmd_f": "Abattez le marteau !",
        "slow": "Le marteau. Un marteau.",
        "desc": "C'est un outil lourd avec un manche en bois pour enfoncer des clous.",
        "inhibit": "Attention ! Ne tirez pas sur le chapeau — détruisez le marteau !",
    },
    {
        "id": "fleur",
        "word": "Une fleur. La fleur.",
        "cmd_m": "Visez la fleur !",
        "cmd_f": "Ciblez la fleur !",
        "slow": "La fleur. Une fleur.",
        "desc": "C'est une plante aux pétales roses qui pousse dans un jardin.",
        "inhibit": "Attention ! Ne tirez pas sur le cœur — visez la fleur !",
    },
    {
        "id": "coeur",
        "word": "Un cœur. Le cœur.",
        "cmd_m": "Tirez sur le cœur !",
        "cmd_f": "Abattez le cœur !",
        "slow": "Le cœur. Un cœur.",
        "desc": "C'est le symbole rouge de l'amour qui bat dans la poitrine.",
        "inhibit": "Attention ! Ne tirez pas sur la fleur — ciblez le cœur !",
    },
    {
        "id": "poisson",
        "word": "Un poisson. Le poisson.",
        "cmd_m": "Abattez le poisson !",
        "cmd_f": "Tirez sur le poisson !",
        "slow": "Le poisson. Un poisson.",
        "desc": "C'est un animal orange avec des nageoires qui nage sous l'eau.",
        "inhibit": "Ne visez pas le pain — tirez sur le poisson !",
    },
    {
        "id": "etoile",
        "word": "Une étoile. L'étoile.",
        "cmd_m": "Ciblez l'étoile !",
        "cmd_f": "Visez l'étoile !",
        "slow": "L'étoile. Une étoile.",
        "desc": "Elle a cinq branches dorées et elle brille dans le ciel la nuit.",
        "inhibit": "Ne touchez pas à la fusée — abattez l'étoile !",
    },
    {
        "id": "fusee",
        "word": "Une fusée. La fusée.",
        "cmd_m": "Neutralisez la fusée !",
        "cmd_f": "Détruisez la fusée !",
        "slow": "La fusée. Une fusée.",
        "desc": "C'est un vaisseau blanc et rouge qui décolle vers l'espace.",
        "inhibit": "Ne tirez pas sur l'étoile — neutralisez la fusée !",
    },

    # === SECTOR 5 (CEFR A2) — VOYAGES & TRANSPORTS ===
    {
        "id": "avion",
        "word": "Un avion. L'avion.",
        "cmd_m": "Tirez sur l'avion !",
        "cmd_f": "Ciblez l'avion !",
        "slow": "L'avion. Un avion.",
        "desc": "C'est un grand appareil à deux ailes qui vole au-dessus des nuages.",
        "inhibit": "Attention ! Ne tirez pas sur le train — visez l'avion !",
    },
    {
        "id": "train",
        "word": "Un train. Le train.",
        "cmd_m": "Abattez le train !",
        "cmd_f": "Visez le train !",
        "slow": "Le train. Un train.",
        "desc": "Il roule à grande vitesse sur des rails entre deux gares.",
        "inhibit": "Ne touchez pas à la voiture — abattez le train !",
    },
    {
        "id": "voiture",
        "word": "Une voiture. La voiture.",
        "cmd_m": "Visez la voiture !",
        "cmd_f": "Tirez sur la voiture !",
        "slow": "La voiture. Une voiture.",
        "desc": "C'est un véhicule rouge à quatre roues qu'on conduit sur la route.",
        "inhibit": "Ne tirez pas sur le vélo — ciblez la voiture !",
    },
    {
        "id": "velo",
        "word": "Un vélo. Le vélo.",
        "cmd_m": "Ciblez le vélo !",
        "cmd_f": "Abattez le vélo !",
        "slow": "Le vélo. Un vélo.",
        "desc": "Il a deux roues, un guidon et des pédales pour avancer sans moteur.",
        "inhibit": "Attention ! Ne visez pas la voiture — tirez sur le vélo !",
    },
    {
        "id": "valise",
        "word": "Une valise. La valise.",
        "cmd_m": "Détruisez la valise !",
        "cmd_f": "Ciblez la valise !",
        "slow": "La valise. Une valise.",
        "desc": "C'est un bagage rectangulaire à roulettes où l'on range ses vêtements de voyage.",
        "inhibit": "Ne tirez pas sur le sac — détruisez la valise !",
    },

    # === SECTOR 6 (CEFR A2) — MAISON & QUOTIDIEN ===
    {
        "id": "chaise",
        "word": "Une chaise. La chaise.",
        "cmd_m": "Tirez sur la chaise !",
        "cmd_f": "Visez la chaise !",
        "slow": "La chaise. Une chaise.",
        "desc": "C'est un meuble en bois avec quatre pieds et un dossier pour s'asseoir.",
        "inhibit": "Ne touchez pas au lit — ciblez la chaise !",
    },
    {
        "id": "lit",
        "word": "Un lit. Le lit.",
        "cmd_m": "Abattez le lit !",
        "cmd_f": "Tirez sur le lit !",
        "slow": "Le lit. Un lit.",
        "desc": "C'est le meuble avec un matelas, un oreiller et une couette où l'on dort la nuit.",
        "inhibit": "Attention ! Ne tirez pas sur la chaise — visez le lit !",
    },
    {
        "id": "lampe",
        "word": "Une lampe. La lampe.",
        "cmd_m": "Visez la lampe !",
        "cmd_f": "Ciblez la lampe !",
        "slow": "La lampe. Une lampe.",
        "desc": "On la pose sur le bureau ou la table de chevet pour éclairer la chambre.",
        "inhibit": "Ne tirez pas sur la lanterne — abattez la lampe !",
    },
    {
        "id": "parapluie",
        "word": "Un parapluie. Le parapluie.",
        "cmd_m": "Ciblez le parapluie !",
        "cmd_f": "Abattez le parapluie !",
        "slow": "Le parapluie. Un parapluie.",
        "desc": "On l'ouvre au-dessus de sa tête quand il pleut pour ne pas être mouillé.",
        "inhibit": "Ne visez pas le chapeau — tirez sur le parapluie !",
    },
    {
        "id": "sac",
        "word": "Un sac. Le sac.",
        "cmd_m": "Neutralisez le sac !",
        "cmd_f": "Tirez sur le sac !",
        "slow": "Le sac. Un sac.",
        "desc": "On le porte sur le dos avec deux bretelles pour transporter ses affaires.",
        "inhibit": "Ne touchez pas à la valise — neutralisez le sac !",
    },

    # === SECTOR 7 (CEFR A2+) — TECHNOLOGIE & MÉDIAS ===
    {
        "id": "ordinateur",
        "word": "Un ordinateur. L'ordinateur.",
        "cmd_m": "Tirez sur l'ordinateur !",
        "cmd_f": "Ciblez l'ordinateur !",
        "slow": "L'ordinateur. Un ordinateur.",
        "desc": "C'est une machine portable avec un clavier et un écran lumineux pour travailler.",
        "inhibit": "Attention ! Ne tirez pas sur le téléphone — visez l'ordinateur !",
    },
    {
        "id": "telephone",
        "word": "Un téléphone. Le téléphone.",
        "cmd_m": "Abattez le téléphone !",
        "cmd_f": "Visez le téléphone !",
        "slow": "Le téléphone. Un téléphone.",
        "desc": "On le garde dans sa poche pour appeler ses amis ou envoyer des messages.",
        "inhibit": "Ne touchez pas à l'ordinateur — ciblez le téléphone !",
    },
    {
        "id": "appareil",
        "word": "Un appareil photo. L'appareil photo.",
        "cmd_m": "Visez l'appareil photo !",
        "cmd_f": "Tirez sur l'appareil photo !",
        "slow": "L'appareil photo. Un appareil photo.",
        "desc": "Il possède un objectif en verre et un bouton pour prendre des photographies.",
        "inhibit": "Ne tirez pas sur le téléphone — abattez l'appareil photo !",
    },
    {
        "id": "microphone",
        "word": "Un microphone. Le microphone.",
        "cmd_m": "Ciblez le microphone !",
        "cmd_f": "Abattez le microphone !",
        "slow": "Le microphone. Un microphone.",
        "desc": "On parle ou on chante dedans pour amplifier sa voix sur scène.",
        "inhibit": "Attention ! Ne visez pas la guitare — tirez sur le microphone !",
    },
    {
        "id": "guitare",
        "word": "Une guitare. La guitare.",
        "cmd_m": "Détruisez la guitare !",
        "cmd_f": "Ciblez la guitare !",
        "slow": "La guitare. Une guitare.",
        "desc": "C'est un instrument de musique en bois avec six cordes qu'on pince avec les doigts.",
        "inhibit": "Ne tirez pas sur le microphone — détruisez la guitare !",
    },

    # === SECTOR 8 (CEFR B1) — SANTÉ, URGENCES & SOCIÉTÉ ===
    {
        "id": "medicament",
        "word": "Un médicament. Le médicament.",
        "cmd_m": "Tirez sur le médicament !",
        "cmd_f": "Visez le médicament !",
        "slow": "Le médicament. Un médicament.",
        "desc": "C'est une gélule rouge et blanche prescrite par le médecin pour guérir une maladie.",
        "inhibit": "Ne touchez pas à l'ambulance — ciblez le médicament !",
    },
    {
        "id": "ambulance",
        "word": "Une ambulance. L'ambulance.",
        "cmd_m": "Abattez l'ambulance !",
        "cmd_f": "Ciblez l'ambulance !",
        "slow": "L'ambulance. Une ambulance.",
        "desc": "C'est un véhicule blanc d'urgence avec une sirène bleue qui transporte les blessés à l'hôpital.",
        "inhibit": "Attention ! Ne tirez pas sur la voiture — visez l'ambulance !",
    },
    {
        "id": "lettre",
        "word": "Une lettre. La lettre.",
        "cmd_m": "Visez la lettre !",
        "cmd_f": "Tirez sur la lettre !",
        "slow": "La lettre. Une lettre.",
        "desc": "C'est un message écrit glissé dans une enveloppe fermée avec un timbre.",
        "inhibit": "Ne tirez pas sur le journal — abattez la lettre !",
    },
    {
        "id": "journal",
        "word": "Un journal. Le journal.",
        "cmd_m": "Ciblez le journal !",
        "cmd_f": "Abattez le journal !",
        "slow": "Le journal. Un journal.",
        "desc": "C'est une publication imprimée chaque matin qui raconte les actualités du monde.",
        "inhibit": "Ne visez pas le livre — tirez sur le journal !",
    },
    {
        "id": "cadeau",
        "word": "Un cadeau. Le cadeau.",
        "cmd_m": "Détruisez le cadeau !",
        "cmd_f": "Visez le cadeau !",
        "slow": "Le cadeau. Un cadeau.",
        "desc": "C'est une boîte entourée d'un ruban rouge qu'on offre pour faire plaisir à quelqu'un.",
        "inhibit": "Attention ! Ne tirez pas sur le chapeau — ciblez le cadeau !",
    },

    # === SECTOR 9 (CEFR B1) — ENVIRONNEMENT, MÉTÉO & MONDE ===
    {
        "id": "arbre",
        "word": "Un arbre. L'arbre.",
        "cmd_m": "Tirez sur l'arbre !",
        "cmd_f": "Ciblez l'arbre !",
        "slow": "L'arbre. Un arbre.",
        "desc": "Il a un tronc solide en bois et un grand feuillage vert qui produit de l'oxygène.",
        "inhibit": "Ne touchez pas à la fleur — abattez l'arbre !",
    },
    {
        "id": "soleil",
        "word": "Un soleil. Le soleil.",
        "cmd_m": "Abattez le soleil !",
        "cmd_f": "Visez le soleil !",
        "slow": "Le soleil. Un soleil.",
        "desc": "C'est l'astre doré qui réchauffe la Terre et brille en plein jour.",
        "inhibit": "Attention ! Ne tirez pas sur l'étoile — visez le soleil !",
    },
    {
        "id": "nuage",
        "word": "Un nuage. Le nuage.",
        "cmd_m": "Visez le nuage !",
        "cmd_f": "Tirez sur le nuage !",
        "slow": "Le nuage. Un nuage.",
        "desc": "C'est une masse blanche ou grise qui flotte dans le ciel et apporte la pluie.",
        "inhibit": "Ne tirez pas sur le soleil — ciblez le nuage !",
    },
    {
        "id": "usine",
        "word": "Une usine. L'usine.",
        "cmd_m": "Ciblez l'usine !",
        "cmd_f": "Détruisez l'usine !",
        "slow": "L'usine. Une usine.",
        "desc": "C'est un grand bâtiment industriel avec deux hautes cheminées qui fabrique des produits.",
        "inhibit": "Attention ! Ne visez pas l'arbre — neutralisez l'usine !",
    },
    {
        "id": "globe",
        "word": "Un globe terrestre. Le globe.",
        "cmd_m": "Neutralisez le globe !",
        "cmd_f": "Abattez le globe !",
        "slow": "Le globe. Un globe terrestre.",
        "desc": "C'est une sphère bleue et verte montée sur un pied qui représente toute notre planète.",
        "inhibit": "Ne touchez pas au soleil — tirez sur le globe !",
    },
]

# === A2 3D SPATIAL, SCALE & MOTION MODIFIER DRILLS ===
MODIFIER_AUDIO = [
    ("mod_plus_grand.ogg", VOICE_M, "-2%", "Tirez sur la cible la plus grande !"),
    ("mod_plus_petit.ogg", VOICE_F, "-2%", "Visez l'objet le plus petit !"),
    ("mod_plus_rapide.ogg", VOICE_M, "-2%", "Abattez le drone qui bouge le plus vite !"),
    ("mod_immobile.ogg", VOICE_F, "-2%", "Ciblez uniquement l'objet qui reste complètement immobile !"),
    ("mod_plus_haut.ogg", VOICE_M, "-2%", "Tirez sur la cible qui vole le plus haut !"),
    ("mod_plus_bas.ogg", VOICE_F, "-2%", "Visez le drone qui se trouve le plus bas, près du sol !"),
    ("mod_tout_gauche.ogg", VOICE_M, "-2%", "Abattez l'objet situé tout à gauche de l'arène !"),
    ("mod_tout_droite.ogg", VOICE_F, "-2%", "Ciblez l'objet qui se trouve tout à droite !"),
    ("mod_au_milieu.ogg", VOICE_M, "-2%", "Tirez sur la cible placée exactement au milieu, entre les deux autres !"),
    ("mod_plus_proche.ogg", VOICE_F, "-2%", "Neutralisez d'abord le drone le plus proche de vous !"),
    ("mod_plus_loin.ogg", VOICE_M, "-2%", "Visez la cible la plus éloignée au fond de l'arène !"),
    ("mod_grand_immobile.ogg", VOICE_F, "-4%", "Attention : tirez sur celui qui est à la fois grand et immobile !"),
]

# === DELF A2 & B1 SITUATIONAL LISTENING DIALOGUES / SCENARIOS ===
SCENARIO_AUDIO = [
    ("scen_01.ogg", VOICE_M, "-3%", "J'allais prendre ma voiture, mais comme il y a des embouteillages, je prends finalement le train."),
    ("scen_02.ogg", VOICE_F, "-3%", "On annonçait du beau soleil ce matin, pourtant il pleut déjà : n'oubliez surtout pas votre parapluie !"),
    ("scen_03.ogg", VOICE_M, "-3%", "Mon sac à dos est beaucoup trop petit pour une semaine de vacances ; il me faut ma grande valise."),
    ("scen_04.ogg", VOICE_F, "-3%", "Mon téléphone n'a plus de batterie, alors j'utilise mon ordinateur portable pour travailler."),
    ("scen_05.ogg", VOICE_M, "-3%", "Je ne mange plus de pain le matin, mais je bois toujours une tasse de café bien chaud."),
    ("scen_06.ogg", VOICE_F, "-3%", "Elle a posé sa guitare parce que son microphone ne fonctionnait plus sur scène."),
    ("scen_07.ogg", VOICE_M, "-3%", "Le train était complet ; nous avons donc réservé deux billets d'avion pour partir à Nice."),
    ("scen_08.ogg", VOICE_F, "-3%", "Avant de te coucher dans ton lit, éteins la lampe qui est restée allumée !"),
    ("scen_09.ogg", VOICE_M, "-4%", "Bien qu'il ait déjà pris son médicament, son état s'est aggravé : appelez immédiatement une ambulance !"),
    ("scen_10.ogg", VOICE_F, "-4%", "Au lieu de lire le journal comme d'habitude, il rédige une lettre urgente qu'il doit poster avant midi."),
    ("scen_11.ogg", VOICE_M, "-4%", "Si j'avais su que c'était son anniversaire hier, je lui aurais offert un beau cadeau au lieu d'une simple fleur."),
    ("scen_12.ogg", VOICE_F, "-4%", "Les habitants souhaitent qu'on plante un arbre devant la mairie plutôt que de construire une nouvelle usine."),
    ("scen_13.ogg", VOICE_M, "-4%", "Puisque le centre-ville est désormais interdit aux voitures, je me déplace uniquement à vélo."),
    ("scen_14.ogg", VOICE_F, "-4%", "J'aurais bien pris des photos avec mon téléphone, mais un véritable appareil photo donne une meilleure image."),
    ("scen_15.ogg", VOICE_M, "-4%", "Le professeur utilise un globe terrestre pour expliquer comment la pollution des usines réchauffe la planète."),
    ("scen_16.ogg", VOICE_F, "-4%", "Avant que ce gros nuage noir n'apporte l'orage, rentrez vite les chaises du jardin !"),
]

# === A2 & B1 GRAMMAR & PHONETIC BREACHES (SPOKEN SENTENCES) ===
GRAMMAR_AUDIO = [
    ("gram_01.ogg", VOICE_F, "-4%", "Hier soir, Marie est arrivée à la gare à vingt heures."),
    ("gram_02.ogg", VOICE_M, "-4%", "Je dormais tranquillement quand le téléphone a sonné."),
    ("gram_03.ogg", VOICE_F, "-4%", "Ces bagages sont lourds ; je les prends tout de suite."),
    ("gram_04.ogg", VOICE_M, "-4%", "Tu vas à la pharmacie ? Oui, j'y vais maintenant."),
    ("gram_05.ogg", VOICE_F, "-4%", "Il reste du fromage ? Oui, j'en voudrais un morceau."),
    ("gram_06.ogg", VOICE_M, "-5%", "Écoutez bien la liaison : Ils ont fini leur travail."),
    ("gram_07.ogg", VOICE_F, "-4%", "Demain, si tout va bien, nous partirons à l'aube."),
    ("gram_08.ogg", VOICE_M, "-4%", "Si j'avais plus de temps libre, je ferais le tour du monde."),
    ("gram_09.ogg", VOICE_F, "-4%", "Il faut absolument que vous soyez à l'heure pour le train."),
    ("gram_10.ogg", VOICE_M, "-4%", "Bien qu'il fasse froid dehors, nous sortons à vélo."),
    ("gram_11.ogg", VOICE_F, "-4%", "Voici le médicament dont le médecin m'a parlé hier."),
    ("gram_12.ogg", VOICE_M, "-4%", "C'est le jour où nous avons visité Paris pour la première fois."),
    ("gram_13.ogg", VOICE_F, "-4%", "Mes parents m'ont écrit ; je dois leur répondre ce soir."),
    ("gram_14.ogg", VOICE_M, "-4%", "Il pleut très fort, pourtant il est sorti sans son parapluie."),
    ("gram_15.ogg", VOICE_F, "-4%", "Quand je suis arrivé à la gare, le train était déjà parti."),
    ("gram_16.ogg", VOICE_M, "-4%", "Je doute qu'il puisse venir avec nous ce week-end."),
]

RADIO_CLIPS = [
    ("radio_welcome.ogg", VOICE_M, "+0%", "Bienvenue dans l'Opération Écho, agent. Écoutez les ordres et visez juste !"),
    ("radio_calibrate.ogg", VOICE_F, "+0%", "Phase de reconnaissance. Scannez les nouvelles cibles pour mémoriser leur nom."),
    ("radio_wave_start.ogg", VOICE_M, "+0%", "Attention, déploiement des drones ! Ouvrez grand les oreilles !"),
    ("radio_pure_audio.ogg", VOICE_F, "+0%", "Mode écoute pure. Fiez-vous uniquement à votre oreille !"),
    ("radio_bravo_1.ogg", VOICE_M, "+5%", "Excellent tir !"),
    ("radio_bravo_2.ogg", VOICE_F, "+5%", "Parfait, continuez !"),
    ("radio_bravo_3.ogg", VOICE_M, "+5%", "Cible neutralisée, bien joué !"),
    ("radio_wrong.ogg", VOICE_F, "+0%", "Erreur de cible ! Écoutez bien et corrigez le tir !"),
]


async def synth_one(sem: asyncio.Semaphore, out_path: str, voice: str, rate: str, text: str):
    if os.path.exists(out_path) and os.path.getsize(out_path) > 1000:
        return
    async with sem:
        for attempt in range(4):
            tmp_mp3 = ""
            try:
                with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tf:
                    tmp_mp3 = tf.name
                comm = edge_tts.Communicate(text=text, voice=voice, rate=rate)
                await comm.save(tmp_mp3)
                subprocess.run(
                    [
                        "ffmpeg", "-y", "-loglevel", "error",
                        "-i", tmp_mp3,
                        "-af", "silenceremove=start_periods=1:start_silence=0.04:start_threshold=-48dB, loudnorm=I=-16:TP=-1.5:LRA=11",
                        "-c:a", "libvorbis", "-q:a", "4",
                        out_path,
                    ],
                    check=True,
                )
                os.remove(tmp_mp3)
                return
            except Exception as exc:
                if tmp_mp3 and os.path.exists(tmp_mp3):
                    os.remove(tmp_mp3)
                if attempt == 3:
                    raise RuntimeError(f"Failed TTS for {out_path}: {exc}") from exc
                await asyncio.sleep(1.0 * (attempt + 1))


def save_wav_to_ogg(samples: np.ndarray, out_ogg: str, sr: int = 44100):
    if os.path.exists(out_ogg) and os.path.getsize(out_ogg) > 500:
        return
    peak = np.max(np.abs(samples))
    if peak > 0:
        samples = samples / peak * 0.85
    pcm = (samples * 32767.0).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        tmp_wav = tf.name
    with wave.open(tmp_wav, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(pcm.tobytes())
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", tmp_wav, "-c:a", "libvorbis", "-q:a", "5", out_ogg],
        check=True,
    )
    os.remove(tmp_wav)


def generate_sfx():
    sr = 44100
    t = np.linspace(0, 0.22, int(sr * 0.22), endpoint=False)
    freq = 1250.0 * np.exp(-t * 13.0) + 140.0
    phase = 2 * np.pi * np.cumsum(freq) / sr
    env = np.exp(-t * 14.0)
    noise = np.random.default_rng(42).normal(0, 0.18, len(t)) * np.exp(-t * 38.0)
    laser = (0.75 * np.sin(phase) + 0.30 * np.sin(2.0 * phase) + noise) * env
    save_wav_to_ogg(laser, os.path.join(SFX_DIR, "laser.ogg"), sr)

    t = np.linspace(0, 0.38, int(sr * 0.38), endpoint=False)
    notes = [(0.0, 523.25), (0.08, 659.25), (0.16, 783.99), (0.24, 1046.50)]
    ok = np.zeros_like(t)
    for start, f in notes:
        mask = t >= start
        dt = t[mask] - start
        ok[mask] += (np.sin(2 * np.pi * f * dt) + 0.35 * np.sin(4 * np.pi * f * dt)) * np.exp(-dt * 11.0)
    save_wav_to_ogg(ok, os.path.join(SFX_DIR, "hit_ok.ogg"), sr)

    t = np.linspace(0, 0.34, int(sr * 0.34), endpoint=False)
    f_err = np.where(t < 0.16, 250.0, 185.0)
    ph = 2 * np.pi * np.cumsum(f_err) / sr
    err = (0.65 * np.sin(ph) + 0.35 * np.sign(np.sin(ph)) * 0.4) * np.exp(-t * 5.5)
    save_wav_to_ogg(err, os.path.join(SFX_DIR, "hit_err.ogg"), sr)

    t = np.linspace(0, 0.28, int(sr * 0.28), endpoint=False)
    scan = (np.sin(2 * np.pi * 880.0 * t) + 0.5 * np.sin(2 * np.pi * 1318.5 * t)) * np.exp(-t * 10.0)
    save_wav_to_ogg(scan, os.path.join(SFX_DIR, "scan.ogg"), sr)

    t = np.linspace(0, 0.30, int(sr * 0.30), endpoint=False)
    rng = np.random.default_rng(7)
    sh = (0.6 * np.sin(2 * np.pi * 95.0 * t) + 0.4 * rng.normal(0, 0.5, len(t))) * np.exp(-t * 10.0)
    save_wav_to_ogg(sh, os.path.join(SFX_DIR, "shield_hit.ogg"), sr)

    t = np.linspace(0, 0.65, int(sr * 0.65), endpoint=False)
    chord = [(0.0, 440.0), (0.10, 554.37), (0.20, 659.25), (0.30, 880.0)]
    wv = np.zeros_like(t)
    for st, f in chord:
        m = t >= st
        dt = t[m] - st
        wv[m] += (np.sin(2 * np.pi * f * dt) + 0.3 * np.sin(4 * np.pi * f * dt)) * np.exp(-dt * 5.5)
    save_wav_to_ogg(wv, os.path.join(SFX_DIR, "wave_up.ogg"), sr)

    t = np.linspace(0, 0.045, int(sr * 0.045), endpoint=False)
    clk = np.sin(2 * np.pi * 1400.0 * t) * np.exp(-t * 85.0)
    save_wav_to_ogg(clk, os.path.join(SFX_DIR, "click.ogg"), sr)


async def main():
    generate_sfx()
    print("Verified 7 procedural SFX clips.")

    sem = asyncio.Semaphore(12)
    tasks = []
    for idx, item in enumerate(VOCAB_AUDIO):
        vid = item["id"]
        desc_voice = VOICE_M if idx % 2 == 0 else VOICE_F
        inh_voice = VOICE_F if idx % 2 == 0 else VOICE_M
        tasks.append(synth_one(sem, os.path.join(VOICE_DIR, f"word_{vid}.ogg"), VOICE_F, "+0%", item["word"]))
        tasks.append(synth_one(sem, os.path.join(VOICE_DIR, f"cmd_{vid}_m.ogg"), VOICE_M, "+0%", item["cmd_m"]))
        tasks.append(synth_one(sem, os.path.join(VOICE_DIR, f"cmd_{vid}_f.ogg"), VOICE_F, "+0%", item["cmd_f"]))
        tasks.append(synth_one(sem, os.path.join(VOICE_DIR, f"slow_{vid}.ogg"), VOICE_F, "-28%", item["slow"]))
        tasks.append(synth_one(sem, os.path.join(VOICE_DIR, f"desc_{vid}.ogg"), desc_voice, "-5%", item["desc"]))
        tasks.append(synth_one(sem, os.path.join(VOICE_DIR, f"inhibit_{vid}.ogg"), inh_voice, "-4%", item["inhibit"]))

    for fname, voice, rate, txt in MODIFIER_AUDIO + SCENARIO_AUDIO + GRAMMAR_AUDIO + RADIO_CLIPS:
        tasks.append(synth_one(sem, os.path.join(VOICE_DIR, fname), voice, rate, txt))

    await asyncio.gather(*tasks)
    print(f"SUCCESS: Verified/Synthesized {len(tasks)} French neural voice files in {VOICE_DIR}")


if __name__ == "__main__":
    asyncio.run(main())
