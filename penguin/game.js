// ============================================================================
// ¡Pingüi-Sabio! — Saber vs. Conocer (Antarctic Spanish Adventure)
// Complete Interactive HTML5 Canvas + Pedagogical Grammar Engine
// ============================================================================

const QUESTIONS = [
  // ==========================================================================
  // CHAPTER 1: Pesca Glacial — Concept Sorter (SABER vs. CONOCER)
  // ==========================================================================
  {
    id: "c1_1",
    chapter: "chapter1",
    topic: "skills_places",
    verbType: "saber",
    npc: { avatar: "🐧", name: "Capitán Pipo" },
    category: "Habilidad (+ infinitivo)",
    sentenceTemplate: "Los pingüinos emperador ___ nadar hasta 500 metros de profundidad.",
    blankFilled: "saben",
    clueHighlight: "nadar",
    english: "Emperor penguins know how to swim up to 500 meters deep.",
    clue: "Después del hueco hay un verbo en infinitivo («nadar»). ¡Es una habilidad!",
    options: [
      { label: "🧠 SABER (saben)", sub: "Habilidad / cómo hacer algo", value: "saber", theme: "saber" },
      { label: "🤝 CONOCER (conocen)", sub: "Persona / lugar / familiaridad", value: "conocer", theme: "conocer" }
    ],
    correctValue: "saber",
    ruleTag: "SABER + infinitivo = Habilidad (know how to)",
    explanation: "Para expresar que alguien tiene la habilidad de hacer algo («know how to swim»), en español siempre usamos SABER + infinitivo («saben nadar»)."
  },
  {
    id: "c1_2",
    chapter: "chapter1",
    topic: "people_facts",
    verbType: "conocer",
    npc: { avatar: "🧣", name: "Doctora Luna" },
    category: "Persona (con «a» personal)",
    sentenceTemplate: "Yo ___ a todos los pingüinos de esta colonia antártica.",
    blankFilled: "conozco",
    clueHighlight: "a todos los pingüinos",
    english: "I know (am acquainted with) all the penguins in this Antarctic colony.",
    clue: "Fíjate en la «a» personal seguida de seres vivos («a todos los pingüinos»).",
    options: [
      { label: "🧠 SABER (sé)", sub: "Datos / información / habilidades", value: "saber", theme: "saber" },
      { label: "🤝 CONOCER (conozco)", sub: "Personas / lugares / cosas", value: "conocer", theme: "conocer" }
    ],
    correctValue: "conocer",
    ruleTag: "CONOCER + a + persona = Trato / familiaridad",
    explanation: "Cuando estamos familiarizados con personas (o animales/personajes con la «a» personal), siempre usamos CONOCER: «Yo conozco a todos los pingüinos»."
  },
  {
    id: "c1_3",
    chapter: "chapter1",
    topic: "skills_places",
    verbType: "conocer",
    npc: { avatar: "🧭", name: "Explorador Nico" },
    category: "Lugar geográfico",
    sentenceTemplate: "¿Vosotros ___ la ciudad de Ushuaia en el sur de Argentina?",
    blankFilled: "conocéis",
    clueHighlight: "la ciudad de Ushuaia",
    english: "Are you all familiar with (have you been to) the city of Ushuaia in southern Argentina?",
    clue: "«La ciudad de Ushuaia» es un lugar geográfico que se visita.",
    options: [
      { label: "🧠 SABER (sabéis)", sub: "Dato / hecho / habilidad", value: "saber", theme: "saber" },
      { label: "🏔️ CONOCER (conocéis)", sub: "Haber visitado un lugar", value: "conocer", theme: "conocer" }
    ],
    correctValue: "conocer",
    ruleTag: "CONOCER + lugar = Estar familiarizado / haber visitado",
    explanation: "Para lugares, ciudades, países o edificios que hemos visitado o con los que estamos familiarizados, usamos CONOCER: «¿Conocéis la ciudad de Ushuaia?»."
  },
  {
    id: "c1_4",
    chapter: "chapter1",
    topic: "people_facts",
    verbType: "saber",
    npc: { avatar: "🐟", name: "Chef Sardina" },
    category: "Dato con interrogativo",
    sentenceTemplate: "¿Tú ___ a qué hora empieza el festival del pescado fresco?",
    blankFilled: "sabes",
    clueHighlight: "a qué hora",
    english: "Do you know what time the fresh fish festival starts?",
    clue: "Hay una expresión interrogativa («a qué hora») que pide un dato exacto.",
    options: [
      { label: "🧠 SABER (sabes)", sub: "Dato / hora / información", value: "saber", theme: "saber" },
      { label: "🤝 CONOCER (conoces)", sub: "Persona / lugar", value: "conocer", theme: "conocer" }
    ],
    correctValue: "saber",
    ruleTag: "SABER + qué / dónde / cuándo / a qué hora = Dato",
    explanation: "Siempre que sigue una palabra interrogativa (qué, a qué hora, dónde, cuándo, cómo, quién), se trata de información o un dato → usamos SABER."
  },
  {
    id: "c1_5",
    chapter: "chapter1",
    topic: "skills_places",
    verbType: "saber",
    npc: { avatar: "⛸️", name: "Pequeño Toto" },
    category: "Habilidad (+ infinitivo)",
    sentenceTemplate: "Mi hermanito todavía es pequeño y no ___ patinar sobre el hielo.",
    blankFilled: "sabe",
    clueHighlight: "patinar",
    english: "My little brother is still small and doesn't know how to ice skate.",
    clue: "«Patinar» es un verbo en infinitivo (-ar): indica una habilidad.",
    options: [
      { label: "🧠 SABER (sabe)", sub: "Habilidad (+ infinitivo)", value: "saber", theme: "saber" },
      { label: "🏔️ CONOCER (conoce)", sub: "Familiaridad con persona/lugar", value: "conocer", theme: "conocer" }
    ],
    correctValue: "saber",
    ruleTag: "SABER + infinitivo = Habilidad aprendida",
    explanation: "Patinar es una destreza o habilidad. En español se dice «no sabe patinar» (nunca se usa conocer con un infinitivo)."
  },
  {
    id: "c1_6",
    chapter: "chapter1",
    topic: "people_facts",
    verbType: "conocer",
    npc: { avatar: "🎩", name: "Profesor Pico" },
    category: "Persona (con «al» = a + el)",
    sentenceTemplate: "¿Ustedes ___ al nuevo biólogo marino de la estación polar?",
    blankFilled: "conocen",
    clueHighlight: "al nuevo biólogo",
    english: "Do you all know (have you met) the new marine biologist at the polar station?",
    clue: "«Al nuevo biólogo» = «a + el biólogo» (una persona).",
    options: [
      { label: "🧠 SABER (saben)", sub: "Dato / información", value: "saber", theme: "saber" },
      { label: "🤝 CONOCER (conocen)", sub: "Persona (a + el = al)", value: "conocer", theme: "conocer" }
    ],
    correctValue: "conocer",
    ruleTag: "CONOCER + al (a + el) + persona",
    explanation: "El biólogo marino es una persona. Recuerda que «a + el» se contrae en «al»: «¿Conocen al nuevo biólogo?»."
  },
  {
    id: "c1_7",
    chapter: "chapter1",
    topic: "people_facts",
    verbType: "saber",
    npc: { avatar: "🧣", name: "Doctora Luna" },
    category: "Información / Cláusula con «dónde»",
    sentenceTemplate: "Nosotros no ___ dónde escondió Pipo las sardinas doradas.",
    blankFilled: "sabemos",
    clueHighlight: "dónde escondió",
    english: "We don't know where Pipo hid the golden sardines.",
    clue: "Viene seguido de «dónde...» (una pregunta indirecta sobre un hecho).",
    options: [
      { label: "🧠 SABER (sabemos)", sub: "Hecho / pregunta indirecta", value: "saber", theme: "saber" },
      { label: "🏔️ CONOCER (conocemos)", sub: "Persona / lugar directo", value: "conocer", theme: "conocer" }
    ],
    correctValue: "saber",
    ruleTag: "SABER + dónde + verbo = Saber un dato",
    explanation: "Aunque «dónde» se refiere a una ubicación, «dónde escondió...» es un dato o información, no un lugar directo. Por eso usamos SABER."
  },
  {
    id: "c1_8",
    chapter: "chapter1",
    topic: "skills_places",
    verbType: "conocer",
    npc: { avatar: "🐟", name: "Chef Sardina" },
    category: "Lugar / Establecimiento",
    sentenceTemplate: "Ellos ___ un restaurante excelente cerca del glaciar Perito Moreno.",
    blankFilled: "conocen",
    clueHighlight: "un restaurante excelente",
    english: "They know a great restaurant near the Perito Moreno glacier.",
    clue: "«Un restaurante excelente» es un lugar físico con el que están familiarizados.",
    options: [
      { label: "🧠 SABER (saben)", sub: "Dato / habilidad", value: "saber", theme: "saber" },
      { label: "🏔️ CONOCER (conocen)", sub: "Lugar / establecimiento", value: "conocer", theme: "conocer" }
    ],
    correctValue: "conocer",
    ruleTag: "CONOCER + lugar / local",
    explanation: "Estar familiarizado con un restaurante, hotel, tienda o rincón requiere CONOCER."
  },
  {
    id: "c1_9",
    chapter: "chapter1",
    topic: "people_facts",
    verbType: "saber",
    npc: { avatar: "🎩", name: "Profesor Pico" },
    category: "Memoria / Datos exactos",
    sentenceTemplate: "La abuela Nieve ___ el nombre científico de cada especie de pingüino.",
    blankFilled: "sabe",
    clueHighlight: "el nombre científico",
    english: "Grandma Nieve knows the scientific name of every penguin species.",
    clue: "Un nombre científico, un número o una fecha es un dato específico memorizado.",
    options: [
      { label: "🧠 SABER (sabe)", sub: "Dato específico / memoria", value: "saber", theme: "saber" },
      { label: "🤝 CONOCER (conoce)", sub: "Persona / lugar", value: "conocer", theme: "conocer" }
    ],
    correctValue: "saber",
    ruleTag: "SABER + dato exacto (el nombre, la hora, el número)",
    explanation: "Saber el nombre, la dirección, el precio o la respuesta es información concreta en la memoria → SABER."
  },
  {
    id: "c1_10",
    chapter: "chapter1",
    topic: "skills_places",
    verbType: "conocer",
    npc: { avatar: "🎧", name: "DJ Escarcha" },
    category: "Obra / Literatura / Música",
    sentenceTemplate: "¿Tú ___ las canciones clásicas de rock en español?",
    blankFilled: "conoces",
    clueHighlight: "las canciones clásicas",
    english: "Are you familiar with classic Spanish rock songs?",
    clue: "Estar familiarizado con canciones, libros, películas o arte usa CONOCER.",
    options: [
      { label: "🧠 SABER (sabes)", sub: "Hecho / habilidad", value: "saber", theme: "saber" },
      { label: "🎵 CONOCER (conoces)", sub: "Estar familiarizado con obras/cosas", value: "conocer", theme: "conocer" }
    ],
    correctValue: "conocer",
    ruleTag: "CONOCER + obras / películas / canciones (familiaridad)",
    explanation: "Cuando preguntas si alguien ha escuchado o está familiarizado con una canción, libro o película, se usa CONOCER. (Solo se usa «saberse» si la recitas de memoria)."
  },
  {
    id: "c1_11",
    chapter: "chapter1",
    topic: "skills_places",
    verbType: "saber",
    npc: { avatar: "🧭", name: "Explorador Nico" },
    category: "Habilidad (+ infinitivo)",
    sentenceTemplate: "¿Vosotros ___ hablar español y portugués?",
    blankFilled: "sabéis",
    clueHighlight: "hablar español",
    english: "Do you all know how to speak Spanish and Portuguese?",
    clue: "«Hablar» es un infinitivo → habilidad lingüística.",
    options: [
      { label: "🧠 SABER (sabéis)", sub: "Habilidad (+ infinitivo)", value: "saber", theme: "saber" },
      { label: "🤝 CONOCER (conocéis)", sub: "Persona / lugar", value: "conocer", theme: "conocer" }
    ],
    correctValue: "saber",
    ruleTag: "SABER + hablar un idioma",
    explanation: "Hablar un idioma es una habilidad aprendida («saber hablar español»)."
  },

  // ==========================================================================
  // CHAPTER 2: Tobogán del Glaciar — Conjugations & Irregular YO (sé / conozco)
  // ==========================================================================
  {
    id: "c2_1",
    chapter: "chapter2",
    topic: "yo_irregular",
    verbType: "saber",
    npc: { avatar: "🐧", name: "Capitán Pipo" },
    category: "Irregular en «Yo» (SABER)",
    sentenceTemplate: "Yo ___ exactamente cuántos peces hay en esta cubeta.",
    blankFilled: "sé",
    clueHighlight: "cuántos peces hay",
    english: "I know exactly how many fish are in this bucket.",
    clue: "Sujeto «Yo» + dato («cuántos peces hay»). ¡Cuidado con la forma irregular de «yo»!",
    options: [
      { label: "sé", sub: "Yo + SABER (irregular)", value: "sé", theme: "saber" },
      { label: "conozco", sub: "Yo + CONOCER", value: "conozco", theme: "conocer" },
      { label: "sabo", sub: "⚠️ Forma trampa", value: "sabo", theme: "saber" }
    ],
    correctValue: "sé",
    ruleTag: "Yo SÉ (¡nunca «sabo»!) + dato",
    explanation: "«Cuántos peces hay» es un dato → SABER. En primera persona singular (yo), saber es irregular: «yo sé» (con tilde para distinguirlo del pronombre «se»). ¡«Sabo» no existe!"
  },
  {
    id: "c2_2",
    chapter: "chapter2",
    topic: "yo_irregular",
    verbType: "conocer",
    npc: { avatar: "🧣", name: "Doctora Luna" },
    category: "Irregular en «Yo» (CONOCER)",
    sentenceTemplate: "Yo ___ muy bien a la capitana del rompehielos.",
    blankFilled: "conozco",
    clueHighlight: "a la capitana",
    english: "I know the captain of the icebreaker very well.",
    clue: "Sujeto «Yo» + persona con «a» («a la capitana»). ¿Cómo termina «conocer» con «yo»?",
    options: [
      { label: "conozco", sub: "Yo + CONOCER (-zco)", value: "conozco", theme: "conocer" },
      { label: "sé", sub: "Yo + SABER", value: "sé", theme: "saber" },
      { label: "conoco", sub: "⚠️ Forma trampa", value: "conoco", theme: "conocer" }
    ],
    correctValue: "conozco",
    ruleTag: "Yo CONOZCO (-zco) + a + persona",
    explanation: "Con una persona («a la capitana») usamos CONOCER. En la forma «yo», los verbos terminados en -cer/-cir suelen cambiar a -zco: «yo conozco» (¡nunca «conoco»!)."
  },
  {
    id: "c2_3",
    chapter: "chapter2",
    topic: "yo_irregular",
    verbType: "conocer",
    npc: { avatar: "🧭", name: "Explorador Nico" },
    category: "Irregular en «Yo» + Lugar",
    sentenceTemplate: "Yo todavía no ___ las islas Galápagos, pero quiero ir.",
    blankFilled: "conozco",
    clueHighlight: "las islas Galápagos",
    english: "I don't know (haven't been to) the Galápagos Islands yet, but I want to go.",
    clue: "«Las islas Galápagos» es un lugar geográfico y el sujeto es «Yo».",
    options: [
      { label: "sé", sub: "Yo + SABER", value: "sé", theme: "saber" },
      { label: "conozco", sub: "Yo + CONOCER", value: "conozco", theme: "conocer" },
      { label: "conoce", sub: "Él/Ella + CONOCER", value: "conoce", theme: "conocer" }
    ],
    correctValue: "conozco",
    ruleTag: "Yo CONOZCO + lugar (haber visitado)",
    explanation: "En español usamos «conocer un lugar» para decir que ya lo hemos visitado. Con «yo» es «yo conozco»."
  },
  {
    id: "c2_4",
    chapter: "chapter2",
    topic: "yo_irregular",
    verbType: "saber",
    npc: { avatar: "🐟", name: "Chef Sardina" },
    category: "Irregular en «Yo» + Infinitivo",
    sentenceTemplate: "¡Yo ___ preparar el mejor pastel de krill de toda la Antártida!",
    blankFilled: "sé",
    clueHighlight: "preparar",
    english: "I know how to make the best krill pie in all of Antarctica!",
    clue: "Sujeto «Yo» + verbo en infinitivo («preparar»).",
    options: [
      { label: "conozco", sub: "Yo + CONOCER", value: "conozco", theme: "conocer" },
      { label: "sé", sub: "Yo + SABER", value: "sé", theme: "saber" },
      { label: "sabes", sub: "Tú + SABER", value: "sabes", theme: "saber" }
    ],
    correctValue: "sé",
    ruleTag: "Yo SÉ + infinitivo = Sé cómo hacerlo",
    explanation: "«Preparar» es un infinitivo (una habilidad culinaria). Con «yo» usamos «yo sé preparar»."
  },
  {
    id: "c2_5",
    chapter: "chapter2",
    topic: "skills_places",
    verbType: "saber",
    npc: { avatar: "⛸️", name: "Pequeño Toto" },
    category: "Conjugación «Tú»",
    sentenceTemplate: "¿Tú ___ por qué los pingüinos no pueden volar por el aire?",
    blankFilled: "sabes",
    clueHighlight: "por qué",
    english: "Do you know why penguins cannot fly through the air?",
    clue: "Sujeto «Tú» + interrogativo «por qué» (causa / dato científico).",
    options: [
      { label: "sabes", sub: "Tú + SABER", value: "sabes", theme: "saber" },
      { label: "conoces", sub: "Tú + CONOCER", value: "conoces", theme: "conocer" },
      { label: "sabe", sub: "Él/Ella + SABER", value: "sabe", theme: "saber" }
    ],
    correctValue: "sabes",
    ruleTag: "Tú SABES + por qué (información)",
    explanation: "«Por qué...» introduce una pregunta sobre un hecho científico → SABER. Para «tú», la forma correcta es «sabes»."
  },
  {
    id: "c2_6",
    chapter: "chapter2",
    topic: "people_facts",
    verbType: "conocer",
    npc: { avatar: "🎩", name: "Profesor Pico" },
    category: "Conjugación «Nosotros»",
    sentenceTemplate: "Nosotros ___ a una foca leopardo que es muy simpática.",
    blankFilled: "conocemos",
    clueHighlight: "a una foca leopardo",
    english: "We know a leopard seal who is very friendly.",
    clue: "Sujeto «Nosotros» + ser vivo con «a» personal.",
    options: [
      { label: "sabemos", sub: "Nosotros + SABER", value: "sabemos", theme: "saber" },
      { label: "conocemos", sub: "Nosotros + CONOCER", value: "conocemos", theme: "conocer" },
      { label: "conocen", sub: "Ellos + CONOCER", value: "conocen", theme: "conocer" }
    ],
    correctValue: "conocemos",
    ruleTag: "Nosotros CONOCEMOS + a + ser vivo",
    explanation: "Tratar o tener amistad con alguien («a una foca») requiere CONOCER. Con «nosotros» es «conocemos»."
  },
  {
    id: "c2_7",
    chapter: "chapter2",
    topic: "skills_places",
    verbType: "conocer",
    npc: { avatar: "🎧", name: "DJ Escarcha" },
    category: "Conjugación «Ellos»",
    sentenceTemplate: "Mis primos de Chile ___ toda la costa de la Patagonia.",
    blankFilled: "conocen",
    clueHighlight: "toda la costa de la Patagonia",
    english: "My cousins from Chile know the entire coast of Patagonia.",
    clue: "Sujeto «Mis primos» (ellos) + lugar geográfico («toda la costa...»).",
    options: [
      { label: "saben", sub: "Ellos + SABER", value: "saben", theme: "saber" },
      { label: "conocen", sub: "Ellos + CONOCER", value: "conocen", theme: "conocer" },
      { label: "conoce", sub: "Él/Ella + CONOCER", value: "conoce", theme: "conocer" }
    ],
    correctValue: "conocen",
    ruleTag: "Ellos CONOCEN + lugar",
    explanation: "«Mis primos» equivale a «ellos», y «la costa de la Patagonia» es un lugar → «conocen»."
  },
  {
    id: "c2_8",
    chapter: "chapter2",
    topic: "yo_irregular",
    verbType: "saber",
    npc: { avatar: "🧣", name: "Doctora Luna" },
    category: "Irregular «Yo» + cláusula con «si»",
    sentenceTemplate: "Yo no ___ si mañana va a nevar en la bahía.",
    blankFilled: "sé",
    clueHighlight: "si mañana va a nevar",
    english: "I don't know if/whether it's going to snow in the bay tomorrow.",
    clue: "«No ___ si...» (I don't know whether/if...) siempre expresa incertidumbre sobre un hecho.",
    options: [
      { label: "sé", sub: "Yo + SABER", value: "sé", theme: "saber" },
      { label: "conozco", sub: "Yo + CONOCER", value: "conozco", theme: "conocer" },
      { label: "sabe", sub: "Él/Ella + SABER", value: "sabe", theme: "saber" }
    ],
    correctValue: "sé",
    ruleTag: "SABER + si (know whether/if)",
    explanation: "Antes de «si» condicional/interrogativo indirecto («know if...»), siempre se usa SABER: «Yo no sé si va a nevar»."
  },
  {
    id: "c2_9",
    chapter: "chapter2",
    topic: "skills_places",
    verbType: "conocer",
    npc: { avatar: "🐧", name: "Capitán Pipo" },
    category: "Conjugación «Él / Ella»",
    sentenceTemplate: "La capitana Luna ___ cada cueva de hielo de este archipiélago.",
    blankFilled: "conoce",
    clueHighlight: "cada cueva de hielo",
    english: "Captain Luna is familiar with every ice cave in this archipelago.",
    clue: "Sujeto singular («La capitana Luna») + lugares («cada cueva de hielo»).",
    options: [
      { label: "sabe", sub: "Ella + SABER", value: "sabe", theme: "saber" },
      { label: "conoce", sub: "Ella + CONOCER", value: "conoce", theme: "conocer" },
      { label: "conoces", sub: "Tú + CONOCER", value: "conoces", theme: "conocer" }
    ],
    correctValue: "conoce",
    ruleTag: "Ella CONOCE + lugar",
    explanation: "Las cuevas de hielo son lugares físicos con los que ella está familiarizada → «ella conoce»."
  },
  {
    id: "c2_10",
    chapter: "chapter2",
    topic: "people_facts",
    verbType: "saber",
    npc: { avatar: "🎩", name: "Profesor Pico" },
    category: "Conjugación «Nosotros» + «que»",
    sentenceTemplate: "Nosotros ___ que el hielo antártico refleja la luz del sol.",
    blankFilled: "sabemos",
    clueHighlight: "que el hielo antártico refleja",
    english: "We know that Antarctic ice reflects sunlight.",
    clue: "Viene seguido de «que + oración completa» (un hecho científico).",
    options: [
      { label: "sabemos", sub: "Nosotros + SABER", value: "sabemos", theme: "saber" },
      { label: "conocemos", sub: "Nosotros + CONOCER", value: "conocemos", theme: "conocer" },
      { label: "saben", sub: "Ellos + SABER", value: "saben", theme: "saber" }
    ],
    correctValue: "sabemos",
    ruleTag: "SABER + que + cláusula (know that...)",
    explanation: "Cuando «to know that...» va seguido de «que + verbo», siempre expresa un hecho o información → usamos SABER («nosotros sabemos que...»)."
  },
  {
    id: "c2_11",
    chapter: "chapter2",
    topic: "yo_irregular",
    verbType: "conocer",
    npc: { avatar: "🐟", name: "Chef Sardina" },
    category: "Irregular «Yo» + Persona",
    sentenceTemplate: "Yo no ___ a nadie que nade más rápido que Pipo.",
    blankFilled: "conozco",
    clueHighlight: "a nadie",
    english: "I don't know anyone who swims faster than Pipo.",
    clue: "«A nadie» / «a alguien» lleva la «a» personal de personas.",
    options: [
      { label: "conozco", sub: "Yo + CONOCER", value: "conozco", theme: "conocer" },
      { label: "sé", sub: "Yo + SABER", value: "sé", theme: "saber" },
      { label: "conoce", sub: "Él/Ella + CONOCER", value: "conoce", theme: "conocer" }
    ],
    correctValue: "conozco",
    ruleTag: "CONOCER + a alguien / a nadie",
    explanation: "Con «a alguien», «a nadie» o «a todo el mundo» nos referimos a personas → «Yo no conozco a nadie...»."
  },

  // ==========================================================================
  // CHAPTER 3: Café del Iceberg — Twin Contrasts & Personal "a"
  // ==========================================================================
  {
    id: "c3_1",
    chapter: "chapter3",
    topic: "skills_places",
    verbType: "conocer",
    npc: { avatar: "☕", name: "Barista Copo" },
    category: "Par Gemelo 1A (Lugar vs. Dato)",
    sentenceTemplate: "— ¿Tú ___ la cafetería «El Iceberg Caliente»? ¡Tienen chocolate delicioso!",
    blankFilled: "conoces",
    clueHighlight: "la cafetería «El Iceberg Caliente»",
    english: "Do you know (are you familiar with) the café 'El Iceberg Caliente'?",
    clue: "Aquí preguntamos directamente por el lugar («la cafetería»), sin palabra interrogativa.",
    options: [
      { label: "conoces", sub: "CONOCER (familiaridad con el lugar)", value: "conoces", theme: "conocer" },
      { label: "sabes", sub: "SABER (dato / información)", value: "sabes", theme: "saber" }
    ],
    correctValue: "conoces",
    ruleTag: "Par Gemelo: ¿Conoces el lugar? (Familiaridad)",
    explanation: "Cuando el objeto directo es el lugar en sí («la cafetería»), usamos CONOCER: «¿Conoces la cafetería?»."
  },
  {
    id: "c3_2",
    chapter: "chapter3",
    topic: "people_facts",
    verbType: "saber",
    npc: { avatar: "☕", name: "Barista Copo" },
    category: "Par Gemelo 1B (Lugar vs. Dato)",
    sentenceTemplate: "— Sí, la conozco, pero no ___ en qué calle está exactamente.",
    blankFilled: "sé",
    clueHighlight: "en qué calle está",
    english: "Yes, I'm familiar with it, but I don't know what street it's on exactly.",
    clue: "Observa el contraste: «Sí, la conozco (el lugar), pero no ___ en qué calle está (el dato)».",
    options: [
      { label: "sé", sub: "SABER (dato: en qué calle está)", value: "sé", theme: "saber" },
      { label: "conozco", sub: "CONOCER (familiaridad)", value: "conozco", theme: "conocer" }
    ],
    correctValue: "sé",
    ruleTag: "Par Gemelo: Conozco el lugar, pero no SÉ dónde está",
    explanation: "¡Mira las dos mitades juntas! «La conozco» (el lugar) vs. «no sé en qué calle está» (un dato introducido por «en qué»)."
  },
  {
    id: "c3_3",
    chapter: "chapter3",
    topic: "people_facts",
    verbType: "conocer",
    npc: { avatar: "🧣", name: "Doctora Luna" },
    category: "Par Gemelo 2A (Persona vs. Dato)",
    sentenceTemplate: "Nosotros ___ al director del observatorio antártico; es muy amable.",
    blankFilled: "conocemos",
    clueHighlight: "al director",
    english: "We know the director of the Antarctic observatory; he is very kind.",
    clue: "«Al director» (a + el director) es una persona con quien tenemos trato.",
    options: [
      { label: "conocemos", sub: "CONOCER + al (persona)", value: "conocemos", theme: "conocer" },
      { label: "sabemos", sub: "SABER (dato)", value: "sabemos", theme: "saber" }
    ],
    correctValue: "conocemos",
    ruleTag: "Par Gemelo: Conocer a una persona",
    explanation: "Tener trato personal con alguien lleva CONOCER + a: «Conocemos al director»."
  },
  {
    id: "c3_4",
    chapter: "chapter3",
    topic: "people_facts",
    verbType: "saber",
    npc: { avatar: "🧣", name: "Doctora Luna" },
    category: "Par Gemelo 2B (Persona vs. Dato)",
    sentenceTemplate: "Conocemos al director, pero no ___ cómo se apellida.",
    blankFilled: "sabemos",
    clueHighlight: "cómo se apellida",
    english: "We know the director, but we don't know what his last name is.",
    clue: "«Cómo se apellida» es un dato específico sobre esa persona.",
    options: [
      { label: "sabemos", sub: "SABER + cómo se apellida (dato)", value: "sabemos", theme: "saber" },
      { label: "conocemos", sub: "CONOCER (persona)", value: "conocemos", theme: "conocer" }
    ],
    correctValue: "sabemos",
    ruleTag: "Par Gemelo: Conocer a alguien vs. Saber cómo se llama",
    explanation: "Conoces A la persona, pero SABES su nombre o cómo se apellida (porque el nombre es un dato)."
  },
  {
    id: "c3_5",
    chapter: "chapter3",
    topic: "people_facts",
    verbType: "conocer",
    npc: { avatar: "🎩", name: "Profesor Pico" },
    category: "La «a» personal obligatoria",
    sentenceTemplate: "¿Tú ___ ___ la profesora de español de la colonia?",
    blankFilled: "conoces a",
    clueHighlight: "la profesora de español",
    english: "Do you know the colony's Spanish teacher?",
    clue: "«La profesora» es una persona. ¿Necesita la preposición «a» o no?",
    options: [
      { label: "conoces a", sub: "CONOCER + «a» personal (persona)", value: "conoces a", theme: "conocer" },
      { label: "conoces (sin «a»)", sub: "⚠️ Falta la «a» personal", value: "conoces", theme: "conocer" },
      { label: "sabes a", sub: "⚠️ Saber no se usa para personas", value: "sabes a", theme: "saber" }
    ],
    correctValue: "conoces a",
    ruleTag: "Regla de la «a» personal: Conocer A alguien",
    explanation: "En español, cuando el objeto directo de «conocer» es una persona determinada, es obligatorio usar la «a» personal: «¿Conoces a la profesora?». (Además, «saber a» significa 'to taste like'!)."
  },
  {
    id: "c3_6",
    chapter: "chapter3",
    topic: "skills_places",
    verbType: "conocer",
    npc: { avatar: "🧭", name: "Explorador Nico" },
    category: "Lugares SIN «a» personal",
    sentenceTemplate: "Yo ___ ___ Buenos Aires porque viví allí dos inviernos.",
    blankFilled: "conozco",
    clueHighlight: "Buenos Aires",
    english: "I know Buenos Aires because I lived there for two winters.",
    clue: "«Buenos Aires» es una ciudad (no una persona). ¿Lleva «a» o va directo?",
    options: [
      { label: "conozco (sin «a»)", sub: "CONOCER + lugar directo", value: "conozco", theme: "conocer" },
      { label: "conozco a", sub: "⚠️ «a» es solo para personas", value: "conozco a", theme: "conocer" },
      { label: "sé", sub: "⚠️ Ciudad = lugar, no dato", value: "sé", theme: "saber" }
    ],
    correctValue: "conozco",
    ruleTag: "CONOCER + ciudad/país (sin «a» en el uso estándar)",
    explanation: "Con ciudades, países y lugares usamos CONOCER sin la «a» de persona: «Yo conozco Buenos Aires»."
  },
  {
    id: "c3_7",
    chapter: "chapter3",
    topic: "skills_places",
    verbType: "saber",
    npc: { avatar: "🐟", name: "Chef Sardina" },
    category: "¡Cuidado con «cómo + infinitivo»!",
    sentenceTemplate: "En español natural: «Mi pingüino ___ bailar tango sobre el hielo».",
    blankFilled: "sabe",
    clueHighlight: "bailar tango",
    english: "In natural Spanish: 'My penguin knows how to dance tango on the ice.'",
    clue: "En inglés se dice 'knows how to dance', pero en español NO se pone «cómo» antes del infinitivo.",
    options: [
      { label: "sabe (sin «cómo»)", sub: "SABER + infinitivo directo", value: "sabe", theme: "saber" },
      { label: "conoce", sub: "⚠️ Conocer nunca va con infinitivo", value: "conoce", theme: "conocer" },
      { label: "conoce cómo", sub: "⚠️ Calco incorrecto del inglés", value: "conoce cómo", theme: "conocer" }
    ],
    correctValue: "sabe",
    ruleTag: "SABER + infinitivo (sin «cómo»)",
    explanation: "Para traducir «knows how to dance», en español decimos simplemente «sabe bailar» (SABER + infinitivo directo)."
  },
  {
    id: "c3_8",
    chapter: "chapter3",
    topic: "people_facts",
    verbType: "conocer",
    npc: { avatar: "🎧", name: "DJ Escarcha" },
    category: "Par Gemelo 3A (Canción: familiaridad)",
    sentenceTemplate: "— ¡Escucha este ritmo! ¿Tú ___ esta canción del grupo Pingüi-Pop?",
    blankFilled: "conoces",
    clueHighlight: "esta canción",
    english: "Listen to this beat! Are you familiar with this song by the band Pingüi-Pop?",
    clue: "Solo pregunta si te suena o la has oído antes.",
    options: [
      { label: "conoces", sub: "CONOCER (¿la has escuchado antes?)", value: "conoces", theme: "conocer" },
      { label: "sabes", sub: "SABER", value: "sabes", theme: "saber" }
    ],
    correctValue: "conoces",
    ruleTag: "Par Gemelo: ¿Conoces esta canción? (¿Te suena?)",
    explanation: "Para preguntar si alguien ha oído antes una canción o está familiarizado con ella, se usa CONOCER."
  },
  {
    id: "c3_9",
    chapter: "chapter3",
    topic: "people_facts",
    verbType: "saber",
    npc: { avatar: "🎧", name: "DJ Escarcha" },
    category: "Par Gemelo 3B (De memoria)",
    sentenceTemplate: "— ¡Claro que la conozco! De hecho, me ___ toda la letra de memoria.",
    blankFilled: "sé",
    clueHighlight: "de memoria",
    english: "Of course I know it! In fact, I know all the lyrics by heart.",
    clue: "«De memoria» (by heart) indica información memorizada palabra por palabra.",
    options: [
      { label: "sé", sub: "SABER(SE) de memoria (memorizado)", value: "sé", theme: "saber" },
      { label: "conozco", sub: "CONOCER", value: "conozco", theme: "conocer" }
    ],
    correctValue: "sé",
    ruleTag: "SABER(SE) algo de memoria = Know by heart",
    explanation: "Cuando te aprendes una letra, un poema o un teléfono de memoria, siempre se usa SABER (o «saberse»): «Me sé toda la letra de memoria»."
  },
  {
    id: "c3_10",
    chapter: "chapter3",
    topic: "people_facts",
    verbType: "saber",
    npc: { avatar: "🐧", name: "Capitán Pipo" },
    category: "Pregunta indirecta con «quién»",
    sentenceTemplate: "¿Vosotros ___ quién dejó estas huellas en la nieve fresca?",
    blankFilled: "sabéis",
    clueHighlight: "quién dejó",
    english: "Do you all know who left these footprints in the fresh snow?",
    clue: "Aunque «quién» pregunta por un individuo, «quién dejó estas huellas» es una oración interrogativa (un dato).",
    options: [
      { label: "sabéis", sub: "SABER + quién + verbo (dato)", value: "sabéis", theme: "saber" },
      { label: "conocéis", sub: "CONOCER", value: "conocéis", theme: "conocer" }
    ],
    correctValue: "sabéis",
    ruleTag: "SABER + quién + verbo (identificar un hecho)",
    explanation: "¡Trampa clásica! Aunque «quién» se refiere a alguien, toda cláusula con «quién / qué / dónde / cuándo + verbo» busca un dato → SABER («¿Sabéis quién dejó...?»)."
  },
  {
    id: "c3_11",
    chapter: "chapter3",
    topic: "skills_places",
    verbType: "conocer",
    npc: { avatar: "☕", name: "Barista Copo" },
    category: "Experiencia / Camino",
    sentenceTemplate: "Sigue a la exploradora Luna; ella ___ muy bien el camino hacia el refugio.",
    blankFilled: "conoce",
    clueHighlight: "el camino hacia el refugio",
    english: "Follow Explorer Luna; she knows (is very familiar with) the path to the shelter.",
    clue: "«El camino» es una ruta física con la que ella tiene experiencia por haberla recorrido.",
    options: [
      { label: "conoce", sub: "CONOCER el camino (experiencia en la ruta)", value: "conoce", theme: "conocer" },
      { label: "sabe", sub: "SABER", value: "sabe", theme: "saber" }
    ],
    correctValue: "conoce",
    ruleTag: "CONOCER el camino = Estar familiarizado con la ruta",
    explanation: "Estar familiarizado con una ruta o territorio por haberlo recorrido se expresa con «conocer el camino» (mientras que «saber cómo llegar» usa saber + cómo)."
  },

  // ==========================================================================
  // CHAPTER 4: Aurora Austral — Preterite Shift (SUPE vs. CONOCÍ) & Boss Mastery
  // ==========================================================================
  {
    id: "c4_1",
    chapter: "chapter4",
    topic: "preterite",
    verbType: "conocer",
    npc: { avatar: "🌌", name: "Guardián Aurora" },
    category: "Pretérito: CONOCÍ (= I met)",
    sentenceTemplate: "El invierno pasado yo ___ a mi mejor amigo Pipo en una expedición.",
    blankFilled: "conocí",
    clueHighlight: "El invierno pasado ... a mi mejor amigo",
    english: "Last winter I met my best friend Pipo on an expedition.",
    clue: "En pasado (pretérito), ¿qué verbo significa «conocer a alguien por primera vez» (to meet)?",
    options: [
      { label: "conocí", sub: "CONOCER en pretérito = I met for the 1st time", value: "conocí", theme: "conocer" },
      { label: "supe", sub: "SABER en pretérito = I found out", value: "supe", theme: "saber" }
    ],
    correctValue: "conocí",
    ruleTag: "Pretérito de CONOCER (conocí) = Conocer por 1.ª vez (to meet)",
    explanation: "En pretérito indefinido, CONOCER a alguien significa «ver o tratar a alguien por primera vez» (en inglés 'to meet'): «El invierno pasado conocí a Pipo»."
  },
  {
    id: "c4_2",
    chapter: "chapter4",
    topic: "preterite",
    verbType: "saber",
    npc: { avatar: "🌌", name: "Guardián Aurora" },
    category: "Pretérito: SUPE (= I found out)",
    sentenceTemplate: "Ayer por la noche yo ___ que ganamos el concurso de escultura en hielo.",
    blankFilled: "supe",
    clueHighlight: "Ayer ... que ganamos",
    english: "Last night I found out (learned) that we won the ice sculpture contest.",
    clue: "En pasado (pretérito), ¿qué verbo significa «enterarse de una noticia o dato» (to find out)?",
    options: [
      { label: "supe", sub: "SABER en pretérito = Me enteré (I found out)", value: "supe", theme: "saber" },
      { label: "conocí", sub: "CONOCER en pretérito = I met", value: "conocí", theme: "conocer" }
    ],
    correctValue: "supe",
    ruleTag: "Pretérito de SABER (supe) = Enterarse de algo (to find out)",
    explanation: "En pretérito indefinido, SABER cambia de matiz a «enterarse de un dato o noticia por primera vez» ('I found out / heard'): «Ayer supe que ganamos»."
  },
  {
    id: "c4_3",
    chapter: "chapter4",
    topic: "preterite",
    verbType: "conocer",
    npc: { avatar: "🧭", name: "Explorador Nico" },
    category: "Pretérito: Conocer un lugar por 1.ª vez",
    sentenceTemplate: "En nuestro viaje de 2025, nosotros ___ la Antártida por primera vez.",
    blankFilled: "conocimos",
    clueHighlight: "la Antártida por primera vez",
    english: "On our 2025 trip, we visited/experienced Antarctica for the first time.",
    clue: "Visitar un lugar por primera vez en el pasado usa el pretérito de CONOCER.",
    options: [
      { label: "conocimos", sub: "Nosotros + CONOCER (pretérito)", value: "conocimos", theme: "conocer" },
      { label: "supimos", sub: "Nosotros + SABER (pretérito)", value: "supimos", theme: "saber" }
    ],
    correctValue: "conocimos",
    ruleTag: "Pretérito CONOCIMOS + lugar = Visitar por 1.ª vez",
    explanation: "En español es muy común decir «conocí / conocimos la Antártida» para expresar la primera vez que visitaste un lugar."
  },
  {
    id: "c4_4",
    chapter: "chapter4",
    topic: "preterite",
    verbType: "saber",
    npc: { avatar: "🧣", name: "Doctora Luna" },
    category: "Pretérito: Enterarse de la verdad",
    sentenceTemplate: "Cuando leí el mapa antiguo, ___ inmediatamente dónde estaba el tesoro polar.",
    blankFilled: "supe",
    clueHighlight: "dónde estaba el tesoro",
    english: "When I read the old map, I immediately found out / knew where the polar treasure was.",
    clue: "Descubrir un dato («dónde estaba el tesoro») en un instante del pasado.",
    options: [
      { label: "supe", sub: "Yo + SABER (pretérito: descubrí el dato)", value: "supe", theme: "saber" },
      { label: "conocí", sub: "Yo + CONOCER (pretérito)", value: "conocí", theme: "conocer" }
    ],
    correctValue: "supe",
    ruleTag: "SUPE + dónde/qué = Descubrir o enterarse en el pasado",
    explanation: "Al leer el mapa te enteraste de un dato («dónde estaba el tesoro») → «supe inmediatamente dónde estaba»."
  },
  {
    id: "c4_5",
    chapter: "chapter4",
    topic: "preterite",
    verbType: "conocer",
    npc: { avatar: "🐟", name: "Chef Sardina" },
    category: "Pretérito: ¿Dónde se conocieron?",
    sentenceTemplate: "¿En qué fiesta se ___ tus abuelos pingüinos?",
    blankFilled: "conocieron",
    clueHighlight: "tus abuelos pingüinos",
    english: "At what party did your penguin grandparents meet each other?",
    clue: "«To meet each other» en pasado recíproco es «conocerse» en pretérito.",
    options: [
      { label: "conocieron", sub: "Se conocieron = They met each other", value: "conocieron", theme: "conocer" },
      { label: "supieron", sub: "Supieron = They found out", value: "supieron", theme: "saber" }
    ],
    correctValue: "conocieron",
    ruleTag: "CONOCERSE en pretérito = To meet each other",
    explanation: "«¿Dónde se conocieron?» significa 'Where did they meet each other?'."
  },
  {
    id: "c4_6",
    chapter: "chapter4",
    topic: "yo_irregular",
    verbType: "saber",
    npc: { avatar: "🎩", name: "Profesor Pico" },
    category: "Curiosidad: «Saber a» (= To taste like)",
    sentenceTemplate: "¡Mmmm! Este helado de nieve polar ___ a vainilla y caramelo.",
    blankFilled: "sabe",
    clueHighlight: "a vainilla y caramelo",
    english: "Mmmm! This polar snow ice cream tastes like vanilla and caramel.",
    clue: "Expresión especial: «___ a + sabor/comida» significa 'to taste like'!",
    options: [
      { label: "sabe", sub: "SABER A + sabor = Tener sabor a (taste like)", value: "sabe", theme: "saber" },
      { label: "conoce", sub: "CONOCER", value: "conoce", theme: "conocer" }
    ],
    correctValue: "sabe",
    ruleTag: "Modismo útil: SABER A + comida = To taste like",
    explanation: "¡Bonus de nivel experto! «Saber a + algo» significa tener ese sabor ('to taste like'): «Este helado sabe a vainilla»."
  },
  {
    id: "c4_7",
    chapter: "chapter4",
    topic: "yo_irregular",
    verbType: "saber",
    npc: { avatar: "🐧", name: "Capitán Pipo" },
    category: "Reto Final: Yo + Habilidad",
    sentenceTemplate: "Yo ___ bucear entre los témpanos, pero todavía no ___ el polo sur.",
    blankFilled: "sé / conozco",
    clueHighlight: "bucear ... el polo sur",
    english: "I know how to dive among the ice floes, but I haven't been to (don't know) the South Pole yet.",
    clue: "Primera parte: «bucear» (infinitivo/habilidad). Segunda parte: «el polo sur» (lugar).",
    options: [
      { label: "sé ... conozco", sub: "1.º Habilidad (sé) / 2.º Lugar (conozco)", value: "sé / conozco", theme: "saber" },
      { label: "conozco ... sé", sub: "1.º Conozco / 2.º Sé", value: "conozco / sé", theme: "conocer" },
      { label: "sé ... sé", sub: "Ambos con saber", value: "sé / sé", theme: "saber" }
    ],
    correctValue: "sé / conozco",
    ruleTag: "Doble Reto: Yo SÉ + infinitivo / Yo CONOZCO + lugar",
    explanation: "«Bucear» es una habilidad en infinitivo → «yo sé bucear». «El polo sur» es un lugar geográfico → «todavía no conozco el polo sur»."
  },
  {
    id: "c4_8",
    chapter: "chapter4",
    topic: "people_facts",
    verbType: "conocer",
    npc: { avatar: "🧣", name: "Doctora Luna" },
    category: "Reto Final: Persona vs. Dato",
    sentenceTemplate: "Yo ___ a tu hermano, pero no ___ cuántos años tiene.",
    blankFilled: "conozco / sé",
    clueHighlight: "a tu hermano ... cuántos años tiene",
    english: "I know your brother, but I don't know how old he is.",
    clue: "Primera parte: «a tu hermano» (persona con «a»). Segunda parte: «cuántos años tiene» (dato).",
    options: [
      { label: "conozco ... sé", sub: "1.º Persona (conozco) / 2.º Dato (sé)", value: "conozco / sé", theme: "conocer" },
      { label: "sé ... conozco", sub: "1.º Sé / 2.º Conozco", value: "sé / conozco", theme: "saber" },
      { label: "conozco ... conozco", sub: "Ambos con conocer", value: "conozco / conozco", theme: "conocer" }
    ],
    correctValue: "conozco / sé",
    ruleTag: "Doble Reto: Yo CONOZCO a + persona / Yo SÉ + cuánto",
    explanation: "«A tu hermano» es una persona → «conozco». «Cuántos años tiene» es un dato numérico → «no sé»."
  },
  {
    id: "c4_9",
    chapter: "chapter4",
    topic: "skills_places",
    verbType: "saber",
    npc: { avatar: "🧭", name: "Explorador Nico" },
    category: "Reto Final:Tú + Dato vs. Lugar",
    sentenceTemplate: "¿Tú ___ a qué distancia está la base o tampoco ___ esa zona?",
    blankFilled: "sabes / conoces",
    clueHighlight: "a qué distancia está ... esa zona",
    english: "Do you know how far away the base is, or are you not familiar with that area either?",
    clue: "Primera parte: «a qué distancia está» (dato). Segunda parte: «esa zona» (lugar).",
    options: [
      { label: "sabes ... conoces", sub: "1.º Dato (sabes) / 2.º Lugar (conoces)", value: "sabes / conoces", theme: "saber" },
      { label: "conoces ... sabes", sub: "1.º Conoces / 2.º Sabes", value: "conoces / sabes", theme: "conocer" },
      { label: "sabes ... sabes", sub: "Ambos con saber", value: "sabes / sabes", theme: "saber" }
    ],
    correctValue: "sabes / conoces",
    ruleTag: "Doble Reto: ¿SABES a qué distancia...? / ¿CONOCES esa zona?",
    explanation: "«A qué distancia está» es un dato medible → «sabes». «Esa zona» es un lugar geográfico → «conoces»."
  },
  {
    id: "c4_10",
    chapter: "chapter4",
    topic: "preterite",
    verbType: "saber",
    npc: { avatar: "🌌", name: "Guardián Aurora" },
    category: "Reto Final: Pretérito Doble",
    sentenceTemplate: "Ayer ellos ___ que el barco llegó cuando ___ al nuevo capitán.",
    blankFilled: "supieron / conocieron",
    clueHighlight: "que el barco llegó ... al nuevo capitán",
    english: "Yesterday they found out that the ship arrived when they met the new captain.",
    clue: "1.º Enterarse de que el barco llegó («que + verbo»). 2.º Ver por primera vez «al nuevo capitán».",
    options: [
      { label: "supieron ... conocieron", sub: "1.º Se enteraron (supieron) / 2.º Vieron por 1.ª vez (conocieron)", value: "supieron / conocieron", theme: "saber" },
      { label: "conocieron ... supieron", sub: "1.º Conocieron / 2.º Supieron", value: "conocieron / supieron", theme: "conocer" }
    ],
    correctValue: "supieron / conocieron",
    ruleTag: "Pretérito Maestro: SUPIERON que... vs. CONOCIERON al...",
    explanation: "«Supieron que el barco llegó» = se enteraron del hecho. «Conocieron al nuevo capitán» = lo trataron por primera vez."
  },
  {
    id: "c4_11",
    chapter: "chapter4",
    topic: "yo_irregular",
    verbType: "saber",
    npc: { avatar: "👑", name: "Rey Emperador Antártico" },
    category: "Gran Final del Pingüi-Sabio",
    sentenceTemplate: "¡Ahora yo ___ cuándo usar «saber» y «conocer» porque ___ el secreto de los pingüinos!",
    blankFilled: "sé / conozco",
    clueHighlight: "cuándo usar ... el secreto",
    english: "Now I know when to use 'saber' and 'conocer' because I am familiar with the penguins' secret!",
    clue: "1.º «Cuándo usar...» (interrogativo + infinitivo). 2.º Estar familiarizado con un misterio/cosa.",
    options: [
      { label: "sé ... conozco", sub: "1.º Cuándo usar (sé) / 2.º El secreto (conozco)", value: "sé / conozco", theme: "saber" },
      { label: "sabo ... conoco", sub: "⚠️ Formas que no existen", value: "sabo / conoco", theme: "conocer" }
    ],
    correctValue: "sé / conozco",
    ruleTag: "🎓 ¡Graduado con Honores de la Academia Pingüi-Sabio!",
    explanation: "«Sé cuándo usar» (interrogativo + habilidad) y «conozco el secreto» (estar familiarizado con algo). ¡Felicidades, eres un auténtico Pingüi-Sabio!"
  }
];

const CHAPTER_META = {
  chapter1: {
    title: "Bahía del Hielo Azul · Capítulo 1: Pesca Glacial",
    subtitle: "Clasifica cada frase entre la poza SABER (datos/habilidades) y la poza CONOCER (personas/lugares).",
    nextMode: "chapter2"
  },
  chapter2: {
    title: "Glaciar Relámpago · Capítulo 2: Tobogán de Conjugaciones",
    subtitle: "Deslízate por el carril correcto eligiendo la forma verbal exacta (¡atención a «yo sé» y «yo conozco»!).",
    nextMode: "chapter3"
  },
  chapter3: {
    title: "Plaza del Iceberg · Capítulo 3: Pares Gemelos y la «a» Personal",
    subtitle: "Resuelve los pares de oraciones parecidas en el Café del Iceberg.",
    nextMode: "chapter4"
  },
  chapter4: {
    title: "Cima de la Aurora Austral · Capítulo 4: Pretérito (Supe vs. Conocí) y Reto Maestro",
    subtitle: "Domina el cambio de significado en pasado (supe = me enteré / conocí = vi por 1.ª vez) y los retos dobles.",
    nextMode: "chapter1"
  }
};

// ============================================================================
// Game State
// ============================================================================
const state = {
  currentMode: "chapter1",
  filterTopic: "chapter",
  questionPool: [],
  currentIndex: 0,
  score: 0,
  streak: 0,
  bestStreak: 0,
  totalAnswered: 0,
  totalCorrect: 0,
  chapterCorrect: 0,
  chapterTotal: 0,
  answeredCurrent: false,
  lastWasCorrect: null,
  hintsEnabled: true,
  soundEnabled: true,
  mistakeIds: new Set(),
  skillStats: {
    saber: { correct: 0, total: 0 },
    conocer: { correct: 0, total: 0 },
    yo_irregular: { correct: 0, total: 0 },
    preterite: { correct: 0, total: 0 }
  },
  // Canvas Penguin Animation State
  penguin: {
    x: 540,
    targetX: 540,
    y: 230,
    vy: 0,
    facing: 1,
    waddlePhase: 0,
    isSliding: false,
    celebratingTimer: 0,
    dizzyTimer: 0,
    speechBubble: "¡Hola! ¿Listo para pescar verbos?",
    speechTimer: 180
  },
  canvasTargets: [],
  particles: [],
  snowflakes: [],
  floatingFish: []
};

// ============================================================================
// Sound Effects & Spanish TTS (Web Audio API + SpeechSynthesis)
// ============================================================================
let audioCtx = null;

function ensureAudioCtx() {
  if (!audioCtx && typeof window !== "undefined") {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (AudioContextClass) {
      audioCtx = new AudioContextClass();
    }
  }
  if (audioCtx && audioCtx.state === "suspended") {
    audioCtx.resume().catch(() => {});
  }
}

function playSfx(type) {
  if (!state.soundEnabled) return;
  try {
    ensureAudioCtx();
    if (!audioCtx) return;
    const now = audioCtx.currentTime;

    if (type === "correct") {
      const notes = [523.25, 659.25, 783.99, 1046.5];
      notes.forEach((freq, idx) => {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.type = "triangle";
        osc.frequency.setValueAtTime(freq, now + idx * 0.065);
        gain.gain.setValueAtTime(0.14, now + idx * 0.065);
        gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.065 + 0.24);
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.start(now + idx * 0.065);
        osc.stop(now + idx * 0.065 + 0.25);
      });
    } else if (type === "wrong") {
      const notes = [280, 210];
      notes.forEach((freq, idx) => {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.type = "sawtooth";
        osc.frequency.setValueAtTime(freq, now + idx * 0.11);
        gain.gain.setValueAtTime(0.1, now + idx * 0.11);
        gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.11 + 0.22);
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.start(now + idx * 0.11);
        osc.stop(now + idx * 0.11 + 0.24);
      });
    } else if (type === "slide") {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(340, now);
      osc.frequency.exponentialRampToValueAtTime(620, now + 0.12);
      gain.gain.setValueAtTime(0.07, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.13);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start(now);
      osc.stop(now + 0.14);
    } else if (type === "fanfare") {
      const notes = [523.25, 659.25, 783.99, 1046.5, 1318.5];
      notes.forEach((freq, idx) => {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.type = "triangle";
        osc.frequency.setValueAtTime(freq, now + idx * 0.09);
        gain.gain.setValueAtTime(0.16, now + idx * 0.09);
        gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.09 + 0.35);
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.start(now + idx * 0.09);
        osc.stop(now + idx * 0.09 + 0.36);
      });
    }
  } catch (e) {
    // Ignore audio context errors on restricted autoplay
  }
}

function speakSpanish(text) {
  if (!state.soundEnabled || !("speechSynthesis" in window)) return;
  try {
    window.speechSynthesis.cancel();
    const cleanText = text.replace(/___+/g, " ").replace(/\s+/g, " ").trim();
    const utter = new SpeechSynthesisUtterance(cleanText);
    utter.lang = "es-ES";
    utter.rate = 0.96;
    const voices = window.speechSynthesis.getVoices();
    const esVoice =
      voices.find((v) => v.lang && v.lang.toLowerCase().startsWith("es") && v.name.includes("Natural")) ||
      voices.find((v) => v.lang && v.lang.toLowerCase().startsWith("es"));
    if (esVoice) utter.voice = esVoice;
    window.speechSynthesis.speak(utter);
  } catch (e) {
    // Ignore speech synthesis errors
  }
}

// ============================================================================
// Question Pool & UI Rendering
// ============================================================================
function buildQuestionPool() {
  if (state.filterTopic === "chapter") {
    state.questionPool = QUESTIONS.filter((q) => q.chapter === state.currentMode);
  } else if (state.filterTopic === "all") {
    state.questionPool = [...QUESTIONS];
  } else if (state.filterTopic === "mistakes") {
    const mistakes = QUESTIONS.filter((q) => state.mistakeIds.has(q.id));
    state.questionPool = mistakes.length > 0 ? mistakes : QUESTIONS.filter((q) => q.chapter === state.currentMode);
  } else {
    state.questionPool = QUESTIONS.filter((q) => q.topic === state.filterTopic);
  }
  state.currentIndex = 0;
  state.chapterCorrect = 0;
  state.chapterTotal = state.questionPool.length;
  renderCurrentQuestion();
}

function getFullResolvedSentence(q) {
  if (q.blankFilled.includes("/")) {
    const parts = q.blankFilled.split("/").map((s) => s.trim());
    let sentence = q.sentenceTemplate;
    parts.forEach((p) => {
      sentence = sentence.replace("___", p);
    });
    return sentence;
  }
  return q.sentenceTemplate.replace(/___(\s*___)?/, q.blankFilled);
}

function formatSentenceHTML(q, filledText = null) {
  let html = q.sentenceTemplate;

  // Highlight clue phrase if hints are enabled
  if (state.hintsEnabled && q.clueHighlight) {
    const subParts = q.clueHighlight.split("...");
    subParts.forEach((part) => {
      const trimmed = part.trim();
      if (trimmed && html.includes(trimmed)) {
        html = html.replace(trimmed, `<span class="clue-highlight">${trimmed}</span>`);
      }
    });
  }

  const slotClass = filledText
    ? q.verbType === "saber"
      ? "blank-slot filled-saber"
      : "blank-slot filled-conocer"
    : "blank-slot";

  if (filledText && filledText.includes("/")) {
    const parts = filledText.split("/").map((s) => s.trim());
    parts.forEach((p) => {
      html = html.replace("___", `<span class="${slotClass}">${p}</span>`);
    });
    return html;
  }

  const displaySlot = filledText ? filledText : "_____";
  html = html.replace(/___(\s*___)?/, `<span class="${slotClass}">${displaySlot}</span>`);
  return html;
}

function renderCurrentQuestion() {
  const q = state.questionPool[state.currentIndex];
  if (!q) return;

  state.answeredCurrent = false;
  state.lastWasCorrect = null;

  // Update stage header
  const meta = CHAPTER_META[state.currentMode] || CHAPTER_META.chapter1;
  document.getElementById("stageLocationText").textContent = meta.title;

  // Update speaker & category pills
  document.getElementById("npcAvatar").textContent = q.npc.avatar;
  document.getElementById("npcName").textContent = q.npc.name;
  document.getElementById("questionCategoryPill").textContent = q.category;
  document.getElementById("questionCounterPill").textContent = `Reto ${state.currentIndex + 1} / ${state.questionPool.length}`;

  // Update sentence & hints
  document.getElementById("spanishSentenceDisplay").innerHTML = formatSentenceHTML(q, null);
  const engEl = document.getElementById("englishHintDisplay");
  const clueBanner = document.getElementById("grammarClueBanner");
  if (state.hintsEnabled) {
    engEl.style.display = "block";
    engEl.textContent = `🇬🇧 "${q.english}"`;
    clueBanner.style.display = "flex";
    document.getElementById("grammarClueText").textContent = q.clue;
  } else {
    engEl.style.display = "none";
    clueBanner.style.display = "none";
  }

  // Render choice buttons & synchronize Canvas Interactive Targets
  const container = document.getElementById("choicesContainer");
  container.innerHTML = "";
  const canvasWidth = 1080;
  const count = q.options.length;
  state.canvasTargets = [];

  q.options.forEach((opt, idx) => {
    const btn = document.createElement("button");
    btn.className = `choice-btn ${opt.theme === "saber" ? "saber-theme" : "conocer-theme"}`;
    btn.dataset.value = opt.value;
    btn.innerHTML = `
      <span class="key-hint">Tecla ${idx + 1}</span>
      <span>${opt.label}</span>
      <span class="choice-sub">${opt.sub}</span>
    `;
    btn.addEventListener("click", () => handleSelectAnswer(opt.value, idx));
    container.appendChild(btn);

    // Position corresponding target on the Canvas
    const spacing = canvasWidth / (count + 1);
    const targetX = spacing * (idx + 1);
    state.canvasTargets.push({
      index: idx,
      x: targetX,
      y: 235,
      width: 210,
      height: 74,
      label: opt.label,
      sub: opt.sub,
      value: opt.value,
      theme: opt.theme
    });
  });

  // Hide feedback drawer
  const feedbackDrawer = document.getElementById("feedbackDrawer");
  feedbackDrawer.className = "feedback-card";

  // Update progress bar
  updateProgressHUD();

  // Set penguin speech bubble
  state.penguin.speechBubble = `¿${q.options.map((o) => o.label.replace(/^[^\w¿¡]+/, "")).join(" o ")}?`;
  state.penguin.speechTimer = 200;
}

function handleSelectAnswer(selectedValue, optionIndex = 0) {
  if (state.answeredCurrent) return;
  const q = state.questionPool[state.currentIndex];
  if (!q) return;

  state.answeredCurrent = true;
  const isCorrect = selectedValue === q.correctValue;
  state.lastWasCorrect = isCorrect;
  state.totalAnswered++;

  // Move Pipo to the selected canvas target!
  if (state.canvasTargets[optionIndex]) {
    state.penguin.targetX = state.canvasTargets[optionIndex].x;
    state.penguin.isSliding = true;
    playSfx("slide");
  }

  // Track skill stats
  const verbBucket = q.verbType === "saber" ? "saber" : "conocer";
  state.skillStats[verbBucket].total++;
  if (q.topic === "yo_irregular") state.skillStats.yo_irregular.total++;
  if (q.topic === "preterite") state.skillStats.preterite.total++;

  if (isCorrect) {
    state.totalCorrect++;
    state.chapterCorrect++;
    state.streak++;
    if (state.streak > state.bestStreak) state.bestStreak = state.streak;
    const bonus = state.streak >= 3 ? 15 : 10;
    state.score += bonus;
    state.mistakeIds.delete(q.id);

    state.skillStats[verbBucket].correct++;
    if (q.topic === "yo_irregular") state.skillStats.yo_irregular.correct++;
    if (q.topic === "preterite") state.skillStats.preterite.correct++;

    state.penguin.celebratingTimer = 95;
    state.penguin.vy = -7.5;
    state.penguin.speechBubble = state.streak >= 3 ? `¡Racha x${state.streak}! 🐟✨` : "¡Sardina atrapada! 🐟";
    state.penguin.speechTimer = 180;
    spawnCelebrationParticles(state.penguin.targetX, 200, q.verbType === "saber" ? "#38bdf8" : "#fbbf24");
    playSfx("correct");
  } else {
    state.streak = 0;
    state.mistakeIds.add(q.id);
    state.penguin.dizzyTimer = 85;
    state.penguin.speechBubble = "¡Uy, resbalón en el hielo! ❄️";
    state.penguin.speechTimer = 180;
    spawnSnowPuff(state.penguin.targetX, 220);
    playSfx("wrong");
  }

  // Fill in the blank in the sentence display
  document.getElementById("spanishSentenceDisplay").innerHTML = formatSentenceHTML(q, q.blankFilled);

  // Style choice buttons
  const buttons = document.querySelectorAll("#choicesContainer .choice-btn");
  buttons.forEach((btn) => {
    btn.disabled = true;
    if (btn.dataset.value === q.correctValue) {
      btn.classList.add("correct-choice");
    } else if (btn.dataset.value === selectedValue && !isCorrect) {
      btn.classList.add("wrong-choice");
    }
  });

  // Show pedagogical feedback drawer
  const feedbackDrawer = document.getElementById("feedbackDrawer");
  const feedbackTitle = document.getElementById("feedbackTitle");
  const feedbackExplanation = document.getElementById("feedbackExplanation");
  const feedbackRuleTag = document.getElementById("feedbackRuleTag");

  feedbackDrawer.className = `feedback-card show ${isCorrect ? "correct" : "wrong"}`;
  feedbackTitle.innerHTML = isCorrect
    ? `✅ ¡Correcto! Se usa «${q.blankFilled}» (${q.verbType.toUpperCase()})`
    : `❌ ¡Casi! La respuesta correcta es «${q.blankFilled}» (${q.verbType.toUpperCase()})`;
  feedbackExplanation.textContent = q.explanation;
  feedbackRuleTag.textContent = `📌 Regla: ${q.ruleTag}`;

  // Speak the resolved Spanish sentence aloud
  speakSpanish(getFullResolvedSentence(q));

  updateProgressHUD();
}

function nextQuestion() {
  if (!state.answeredCurrent) return;
  if (state.currentIndex + 1 < state.questionPool.length) {
    state.currentIndex++;
    renderCurrentQuestion();
  } else {
    showChapterSummaryModal();
  }
}

function updateProgressHUD() {
  document.getElementById("scoreValue").textContent = state.score;
  document.getElementById("streakValue").textContent = state.streak;
  const acc = state.totalAnswered > 0 ? Math.round((state.totalCorrect / state.totalAnswered) * 100) : 100;
  document.getElementById("accuracyValue").textContent = `${acc}%`;

  const completed = state.currentIndex + (state.answeredCurrent ? 1 : 0);
  const total = state.questionPool.length || 1;
  const pct = Math.round((completed / total) * 100);
  document.getElementById("chapterProgressLabel").textContent = `Progreso: ${completed} / ${total} (${pct}%)`;
  document.getElementById("chapterProgressBar").style.width = `${pct}%`;
}

function showChapterSummaryModal() {
  playSfx("fanfare");
  const modal = document.getElementById("summaryModal");
  const pct = state.chapterTotal > 0 ? Math.round((state.chapterCorrect / state.chapterTotal) * 100) : 100;

  document.getElementById("modalEmoji").textContent = pct >= 85 ? "👑🐧🐟" : "🐧❄️✨";
  document.getElementById("modalTitle").textContent =
    pct >= 85 ? "¡Expedición Antártica Dominada!" : "¡Buen Entrenamiento en el Hielo!";
  document.getElementById("modalSubtitle").textContent =
    `Acertaste ${state.chapterCorrect} de ${state.chapterTotal} retos (${pct}%) · Sardinas totales: ${state.score} 🐟 · Mejor racha: ${state.bestStreak} 🔥`;

  const statsGrid = document.getElementById("modalStatsGrid");
  const formatStat = (obj) => (obj.total > 0 ? `${obj.correct}/${obj.total} (${Math.round((obj.correct / obj.total) * 100)}%)` : "—");
  statsGrid.innerHTML = `
    <div class="skill-box">🧠 <strong>SABER (Datos y Habilidades):</strong><br/>${formatStat(state.skillStats.saber)}</div>
    <div class="skill-box">🤝 <strong>CONOCER (Personas y Lugares):</strong><br/>${formatStat(state.skillStats.conocer)}</div>
    <div class="skill-box">⚠️ <strong>Yo Irregular (sé vs. conozco):</strong><br/>${formatStat(state.skillStats.yo_irregular)}</div>
    <div class="skill-box">⏳ <strong>Pretérito (supe vs. conocí):</strong><br/>${formatStat(state.skillStats.preterite)}</div>
  `;

  const reviewBtn = document.getElementById("btnModalReviewMistakes");
  reviewBtn.style.display = state.mistakeIds.size > 0 ? "inline-flex" : "none";
  reviewBtn.textContent = `🩹 Repasar Errores (${state.mistakeIds.size})`;

  modal.classList.add("show");
}

// ============================================================================
// Mode & Navigation Switching
// ============================================================================
function switchMode(mode) {
  document.querySelectorAll(".mode-tab").forEach((tab) => {
    tab.classList.toggle("active", tab.dataset.mode === mode);
  });

  const gameStage = document.getElementById("gameStageSection");
  const questionDeck = document.getElementById("questionDeck");
  const guideSection = document.getElementById("guideSection");

  if (mode === "guide") {
    gameStage.style.display = "none";
    questionDeck.style.display = "none";
    guideSection.classList.add("show");
    return;
  }

  guideSection.classList.remove("show");
  gameStage.style.display = "block";
  questionDeck.style.display = "block";

  state.currentMode = mode;
  state.filterTopic = "chapter";
  document.getElementById("topicFilterSelect").value = "chapter";
  buildQuestionPool();
}

// ============================================================================
// Interactive 60fps HTML5 Canvas Penguin World
// ============================================================================
const canvas = document.getElementById("penguinCanvas");
const ctx = canvas.getContext("2d");

function initCanvasParticles() {
  state.snowflakes = [];
  for (let i = 0; i < 65; i++) {
    state.snowflakes.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      r: 1.2 + Math.random() * 2.6,
      vy: 0.4 + Math.random() * 1.1,
      vx: (Math.random() - 0.5) * 0.5
    });
  }
}

function spawnCelebrationParticles(x, y, mainColor) {
  const colors = [mainColor, "#fde047", "#34d399", "#ffffff", "#f472b6"];
  for (let i = 0; i < 32; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 2 + Math.random() * 5.5;
    state.particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed - 2.5,
      r: 3 + Math.random() * 4,
      color: colors[i % colors.length],
      alpha: 1,
      isFish: i < 3
    });
  }
}

function spawnSnowPuff(x, y) {
  for (let i = 0; i < 18; i++) {
    const angle = Math.random() * Math.PI * 2;
    const speed = 1 + Math.random() * 3.5;
    state.particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed - 1,
      r: 3 + Math.random() * 4,
      color: "#e2e8f0",
      alpha: 0.9,
      isFish: false
    });
  }
}

function drawAuroraSky(time) {
  // Deep night polar sky gradient
  const skyGrad = ctx.createLinearGradient(0, 0, 0, 210);
  if (state.currentMode === "chapter4") {
    skyGrad.addColorStop(0, "#050b1a");
    skyGrad.addColorStop(0.5, "#112244");
    skyGrad.addColorStop(1, "#1e3a6d");
  } else {
    skyGrad.addColorStop(0, "#07162c");
    skyGrad.addColorStop(0.6, "#0f2e5a");
    skyGrad.addColorStop(1, "#1e4e8c");
  }
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, canvas.width, 210);

  // Shimmering Aurora Australis ribbons
  ctx.save();
  for (let band = 0; band < 2; band++) {
    ctx.beginPath();
    ctx.moveTo(0, 80 + band * 25);
    for (let x = 0; x <= canvas.width; x += 40) {
      const wave = Math.sin(x * 0.006 + time * 0.0018 + band * 1.5) * 22 +
                   Math.cos(x * 0.012 - time * 0.0012) * 10;
      ctx.lineTo(x, 68 + band * 28 + wave);
    }
    ctx.lineTo(canvas.width, 160);
    ctx.lineTo(0, 160);
    ctx.closePath();

    const auroraGrad = ctx.createLinearGradient(0, 40, 0, 160);
    if (band === 0) {
      auroraGrad.addColorStop(0, "rgba(52, 211, 153, 0.28)");
      auroraGrad.addColorStop(1, "rgba(52, 211, 153, 0)");
    } else {
      auroraGrad.addColorStop(0, "rgba(167, 139, 250, 0.24)");
      auroraGrad.addColorStop(1, "rgba(56, 189, 248, 0)");
    }
    ctx.fillStyle = auroraGrad;
    ctx.fill();
  }
  ctx.restore();

  // Distant Icebergs & Glacial Mountains
  ctx.fillStyle = "#173c68";
  ctx.beginPath();
  ctx.moveTo(0, 195);
  ctx.lineTo(90, 120);
  ctx.lineTo(185, 165);
  ctx.lineTo(290, 105);
  ctx.lineTo(410, 180);
  ctx.lineTo(560, 125);
  ctx.lineTo(690, 175);
  ctx.lineTo(820, 110);
  ctx.lineTo(950, 165);
  ctx.lineTo(1080, 125);
  ctx.lineTo(1080, 205);
  ctx.lineTo(0, 205);
  ctx.closePath();
  ctx.fill();

  // Snow caps on peaks
  ctx.fillStyle = "rgba(224, 242, 254, 0.35)";
  [[90, 120], [290, 105], [560, 125], [820, 110]].forEach(([px, py]) => {
    ctx.beginPath();
    ctx.moveTo(px, py);
    ctx.lineTo(px - 32, py + 28);
    ctx.lineTo(px + 32, py + 28);
    ctx.closePath();
    ctx.fill();
  });

  // Main Ice Floe Deck & Antarctic Water
  const waterGrad = ctx.createLinearGradient(0, 190, 0, canvas.height);
  waterGrad.addColorStop(0, "#0b2948");
  waterGrad.addColorStop(1, "#061529");
  ctx.fillStyle = waterGrad;
  ctx.fillRect(0, 190, canvas.width, canvas.height - 190);

  // Sculpted Ice Platform
  const iceGrad = ctx.createLinearGradient(0, 185, 0, 295);
  iceGrad.addColorStop(0, "#e0f2fe");
  iceGrad.addColorStop(0.75, "#bae6fd");
  iceGrad.addColorStop(1, "#7dd3fc");
  ctx.fillStyle = iceGrad;
  ctx.beginPath();
  ctx.roundRect(35, 185, canvas.width - 70, 102, 26);
  ctx.fill();

  // Ice platform bottom thickness
  ctx.fillStyle = "#38bdf8";
  ctx.beginPath();
  ctx.roundRect(35, 275, canvas.width - 70, 18, [0, 0, 22, 22]);
  ctx.fill();
}

function drawCanvasTargets(time) {
  state.canvasTargets.forEach((t, idx) => {
    const isSaber = t.theme === "saber";
    const pulse = Math.sin(time * 0.004 + idx) * 2;

    ctx.save();
    ctx.translate(t.x, t.y);

    // Draw Ice Fishing Hole or Glacier Gate
    ctx.fillStyle = isSaber ? "rgba(3, 105, 161, 0.9)" : "rgba(180, 83, 9, 0.9)";
    ctx.strokeStyle = isSaber ? "#38bdf8" : "#fbbf24";
    ctx.lineWidth = 3;

    ctx.beginPath();
    ctx.ellipse(0, 22, 92 + pulse, 22, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    // Inner water shimmer
    ctx.fillStyle = isSaber ? "rgba(56, 189, 248, 0.35)" : "rgba(251, 191, 36, 0.35)";
    ctx.beginPath();
    ctx.ellipse(0, 22, 68, 12, 0, 0, Math.PI * 2);
    ctx.fill();

    // Signpost banner above the hole
    ctx.fillStyle = isSaber ? "rgba(7, 34, 62, 0.92)" : "rgba(60, 26, 8, 0.92)";
    ctx.strokeStyle = isSaber ? "#38bdf8" : "#f59e0b";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.roundRect(-96, -34, 192, 42, 10);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 14px 'Segoe UI', sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(`[${idx + 1}] ${t.label}`, 0, -14);

    ctx.fillStyle = isSaber ? "#bae6fd" : "#fde68a";
    ctx.font = "11px 'Segoe UI', sans-serif";
    ctx.fillText(t.sub.slice(0, 30), 0, 1);

    ctx.restore();
  });
}

function drawPenguinCharacter(time) {
  const p = state.penguin;

  // Smooth horizontal movement
  const dx = p.targetX - p.x;
  if (Math.abs(dx) > 1.5) {
    p.x += dx * 0.14;
    p.facing = dx > 0 ? 1 : -1;
    p.waddlePhase += 0.28;
  } else {
    p.isSliding = false;
    p.waddlePhase *= 0.85;
  }

  // Vertical hop physics
  p.y += p.vy;
  if (p.y < 212) {
    p.vy += 0.48;
  } else {
    p.y = 212;
    p.vy = 0;
  }

  if (p.celebratingTimer > 0) p.celebratingTimer--;
  if (p.dizzyTimer > 0) p.dizzyTimer--;
  if (p.speechTimer > 0) p.speechTimer--;

  ctx.save();
  ctx.translate(p.x, p.y);

  // Shadow on ice
  ctx.fillStyle = "rgba(7, 19, 36, 0.28)";
  ctx.beginPath();
  ctx.ellipse(0, 30, 28, 8, 0, 0, Math.PI * 2);
  ctx.fill();

  // Waddle tilt or dizzy shake
  let tilt = Math.sin(p.waddlePhase) * 0.09;
  if (p.dizzyTimer > 0) {
    tilt = Math.sin(time * 0.04) * 0.22;
  } else if (p.isSliding && Math.abs(dx) > 18) {
    tilt = p.facing * 0.35;
  }
  ctx.rotate(tilt);

  // Orange Feet
  ctx.fillStyle = "#f97316";
  ctx.beginPath();
  ctx.ellipse(-12, 26, 10, 5, -0.2, 0, Math.PI * 2);
  ctx.ellipse(12, 26, 10, 5, 0.2, 0, Math.PI * 2);
  ctx.fill();

  // Penguin Torso (Dark Navy-Black outer plumage)
  ctx.fillStyle = "#0f172a";
  ctx.beginPath();
  ctx.ellipse(0, 0, 26, 30, 0, 0, Math.PI * 2);
  ctx.fill();

  // White Belly
  ctx.fillStyle = "#f8fafc";
  ctx.beginPath();
  ctx.ellipse(0, 4, 18, 22, 0, 0, Math.PI * 2);
  ctx.fill();

  // Flippers / Wings
  const wingFlap = p.celebratingTimer > 0 ? Math.sin(time * 0.035) * 0.65 - 0.5 : Math.sin(time * 0.005) * 0.08;
  ctx.fillStyle = "#0f172a";
  ctx.save();
  ctx.translate(-24, -2);
  ctx.rotate(0.25 - wingFlap);
  ctx.beginPath();
  ctx.ellipse(0, 8, 6, 16, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();

  ctx.save();
  ctx.translate(24, -2);
  ctx.rotate(-0.25 + wingFlap);
  ctx.beginPath();
  ctx.ellipse(0, 8, 6, 16, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();

  // Cozy Red & Gold Explorer Scarf
  ctx.fillStyle = "#ef4444";
  ctx.beginPath();
  ctx.roundRect(-21, -13, 42, 9, 5);
  ctx.fill();
  ctx.fillStyle = "#fbbf24";
  ctx.fillRect(-10, -13, 6, 9);
  ctx.fillRect(6, -13, 6, 9);
  // Scarf tail
  ctx.fillStyle = "#dc2626";
  ctx.beginPath();
  ctx.roundRect(10, -8, 9, 16, 3);
  ctx.fill();

  // Eyes
  ctx.fillStyle = "#ffffff";
  ctx.beginPath();
  ctx.arc(-8, -19, 5.5, 0, Math.PI * 2);
  ctx.arc(8, -19, 5.5, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = "#0f172a";
  const pupilOffset = p.facing * 1.2;
  ctx.beginPath();
  ctx.arc(-8 + pupilOffset, -19, 2.7, 0, Math.PI * 2);
  ctx.arc(8 + pupilOffset, -19, 2.7, 0, Math.PI * 2);
  ctx.fill();

  // Eye sparkle
  ctx.fillStyle = "#ffffff";
  ctx.beginPath();
  ctx.arc(-9 + pupilOffset, -20.5, 1.1, 0, Math.PI * 2);
  ctx.arc(7 + pupilOffset, -20.5, 1.1, 0, Math.PI * 2);
  ctx.fill();

  // Rosy Cheeks
  ctx.fillStyle = "rgba(244, 114, 182, 0.55)";
  ctx.beginPath();
  ctx.ellipse(-14, -14, 4, 2.5, 0, 0, Math.PI * 2);
  ctx.ellipse(14, -14, 4, 2.5, 0, 0, Math.PI * 2);
  ctx.fill();

  // Beak
  ctx.fillStyle = "#fb923c";
  ctx.beginPath();
  ctx.moveTo(-6, -15);
  ctx.lineTo(6, -15);
  ctx.lineTo(0, -8);
  ctx.closePath();
  ctx.fill();

  // Explorer Captain Hat
  ctx.fillStyle = "#0284c7";
  ctx.beginPath();
  ctx.roundRect(-16, -36, 32, 9, 4);
  ctx.fill();
  ctx.fillStyle = "#fde047";
  ctx.beginPath();
  ctx.arc(0, -37, 4, 0, Math.PI * 2);
  ctx.fill();

  // Golden Fish in beak/flipper when celebrating!
  if (p.celebratingTimer > 0) {
    ctx.save();
    ctx.translate(0, -48 - Math.sin(time * 0.02) * 5);
    ctx.fillStyle = "#fbbf24";
    ctx.beginPath();
    ctx.ellipse(0, 0, 14, 7, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(12, 0);
    ctx.lineTo(20, -6);
    ctx.lineTo(20, 6);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  ctx.restore();

  // Speech Bubble above Pipo
  if (p.speechBubble && p.speechTimer > 0) {
    ctx.save();
    ctx.font = "bold 13px 'Segoe UI', sans-serif";
    const textWidth = Math.min(340, ctx.measureText(p.speechBubble).width + 24);
    const bx = Math.max(20, Math.min(canvas.width - textWidth - 20, p.x - textWidth / 2));
    const by = p.y - 82;

    ctx.fillStyle = "rgba(255, 255, 255, 0.94)";
    ctx.strokeStyle = "#0284c7";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.roundRect(bx, by, textWidth, 30, 10);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = "#0f172a";
    ctx.textAlign = "center";
    ctx.fillText(p.speechBubble, bx + textWidth / 2, by + 19);
    ctx.restore();
  }
}

function drawParticlesAndSnow() {
  // Falling snow
  ctx.fillStyle = "rgba(255, 255, 255, 0.72)";
  state.snowflakes.forEach((f) => {
    f.y += f.vy;
    f.x += f.vx;
    if (f.y > canvas.height) {
      f.y = -5;
      f.x = Math.random() * canvas.width;
    }
    ctx.beginPath();
    ctx.arc(f.x, f.y, f.r, 0, Math.PI * 2);
    ctx.fill();
  });

  // Burst particles
  for (let i = state.particles.length - 1; i >= 0; i--) {
    const pt = state.particles[i];
    pt.x += pt.vx;
    pt.y += pt.vy;
    pt.vy += 0.16;
    pt.alpha -= 0.018;

    if (pt.alpha <= 0) {
      state.particles.splice(i, 1);
      continue;
    }

    ctx.save();
    ctx.globalAlpha = Math.max(0, pt.alpha);
    ctx.fillStyle = pt.color;
    ctx.beginPath();
    ctx.arc(pt.x, pt.y, pt.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

function animateCanvas(time) {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  drawAuroraSky(time);
  drawCanvasTargets(time);
  drawPenguinCharacter(time);
  drawParticlesAndSnow();
  requestAnimationFrame(animateCanvas);
}

// ============================================================================
// Event Listeners (Canvas Click, Keyboard Controls, UI Buttons)
// ============================================================================
function setupEventListeners() {
  // Click directly on Canvas targets to move Pipo and answer!
  canvas.addEventListener("click", (e) => {
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;
    const cx = (e.clientX - rect.left) * scaleX;
    const cy = (e.clientY - rect.top) * scaleY;

    // Check if user clicked near a canvas target
    for (let i = 0; i < state.canvasTargets.length; i++) {
      const t = state.canvasTargets[i];
      if (Math.abs(cx - t.x) <= 105 && Math.abs(cy - t.y) <= 55) {
        if (!state.answeredCurrent) {
          handleSelectAnswer(t.value, i);
        } else {
          nextQuestion();
        }
        return;
      }
    }

    // Otherwise waddle Pipo to clicked X coordinate
    state.penguin.targetX = Math.max(80, Math.min(canvas.width - 80, cx));
  });

  // Keyboard shortcuts: 1/2/3 to pick option, Left/Right to move Pipo, Enter/Space for Next
  window.addEventListener("keydown", (e) => {
    if (document.getElementById("guideSection").classList.contains("show")) return;
    const modal = document.getElementById("summaryModal");
    if (modal.classList.contains("show")) {
      if (e.key === "Enter") {
        document.getElementById("btnModalNextChapter").click();
      }
      return;
    }

    if (!state.answeredCurrent) {
      if (e.key === "1" && state.canvasTargets[0]) {
        handleSelectAnswer(state.canvasTargets[0].value, 0);
      } else if (e.key === "2" && state.canvasTargets[1]) {
        handleSelectAnswer(state.canvasTargets[1].value, 1);
      } else if (e.key === "3" && state.canvasTargets[2]) {
        handleSelectAnswer(state.canvasTargets[2].value, 2);
      } else if (e.key === "ArrowLeft" || e.key.toLowerCase() === "a") {
        state.penguin.targetX = Math.max(100, state.penguin.targetX - 90);
      } else if (e.key === "ArrowRight" || e.key.toLowerCase() === "d") {
        state.penguin.targetX = Math.min(canvas.width - 100, state.penguin.targetX + 90);
      }
    } else if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      nextQuestion();
    }
  });

  // Mode Tabs
  document.querySelectorAll(".mode-tab").forEach((tab) => {
    tab.addEventListener("click", () => switchMode(tab.dataset.mode));
  });

  // Next Question Button
  document.getElementById("btnNextQuestion").addEventListener("click", nextQuestion);

  // Top Bar Controls
  document.getElementById("brandHome").addEventListener("click", () => switchMode("chapter1"));

  document.getElementById("btnHintToggle").addEventListener("click", (e) => {
    state.hintsEnabled = !state.hintsEnabled;
    const btn = e.currentTarget;
    btn.classList.toggle("active", state.hintsEnabled);
    btn.innerHTML = `<span>🔍 Pistas: ${state.hintsEnabled ? "ON" : "OFF"}</span>`;
    renderCurrentQuestion();
  });

  document.getElementById("btnSoundToggle").addEventListener("click", (e) => {
    state.soundEnabled = !state.soundEnabled;
    const btn = e.currentTarget;
    btn.classList.toggle("active", state.soundEnabled);
    btn.innerHTML = `<span>🎵 Audio: ${state.soundEnabled ? "ON" : "OFF"}</span>`;
  });

  document.getElementById("btnSpeakCurrent").addEventListener("click", () => {
    const q = state.questionPool[state.currentIndex];
    if (q) speakSpanish(getFullResolvedSentence(q));
  });

  document.getElementById("btnOpenGuide").addEventListener("click", () => switchMode("guide"));
  document.getElementById("btnBackToGame").addEventListener("click", () => switchMode(state.currentMode));

  // Clickable audio examples in Polar Guide
  document.querySelectorAll(".rule-example").forEach((el) => {
    el.addEventListener("click", () => {
      const tts = el.dataset.tts;
      if (tts) speakSpanish(tts);
    });
  });

  // Topic Filter Select
  document.getElementById("topicFilterSelect").addEventListener("change", (e) => {
    state.filterTopic = e.target.value;
    buildQuestionPool();
  });

  // Summary Modal Buttons
  document.getElementById("btnModalReplay").addEventListener("click", () => {
    document.getElementById("summaryModal").classList.remove("show");
    buildQuestionPool();
  });

  document.getElementById("btnModalNextChapter").addEventListener("click", () => {
    document.getElementById("summaryModal").classList.remove("show");
    const nextMode = CHAPTER_META[state.currentMode]?.nextMode || "chapter1";
    switchMode(nextMode);
  });

  document.getElementById("btnModalReviewMistakes").addEventListener("click", () => {
    document.getElementById("summaryModal").classList.remove("show");
    state.filterTopic = "mistakes";
    document.getElementById("topicFilterSelect").value = "mistakes";
    buildQuestionPool();
  });
}

// ============================================================================
// Initialize Game
// ============================================================================
initCanvasParticles();
setupEventListeners();
buildQuestionPool();
requestAnimationFrame(animateCanvas);
