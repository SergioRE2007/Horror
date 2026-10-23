// Genera candidatos de efectos de sonido con ElevenLabs y, por tanda, una página para escucharlos.
// Uso: node tools/sonidos/generar.mjs <carpeta base> [tanda...]   (sin tandas, todas)
// Cada tanda va a <carpeta base>/<tanda>/<nombre>_<versión>.mp3; lo que ya existe no se repite.
// La clave sale de ELEVENLABS_API_KEY o de la configuración del MCP "elevenlabs" de Claude Code.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const [base, ...wanted] = process.argv.slice(2);

function apiKey() {
	if (process.env.ELEVENLABS_API_KEY) return process.env.ELEVENLABS_API_KEY;
	const config = JSON.parse(fs.readFileSync(path.join(os.homedir(), ".claude.json"), "utf8"));
	for (const project of Object.values(config.projects ?? {})) {
		const key = project.mcpServers?.elevenlabs?.env?.ELEVENLABS_API_KEY;
		if (key) return key;
	}
	throw new Error("No encuentro la clave de ElevenLabs");
}

// Un sonido: nombre (su clave en Config.Sonidos), segundos, descripción para la página, texto para ElevenLabs,
// cuántas versiones y si es un bucle (ambiente que se repite sin corte).
const s = (name, seconds, label, text, versions = 3, loop = false) => ({ name, seconds, label, text, versions, loop });
const DRY = "horror game sound effect, realistic, dry, no reverb, no music";
const LOOP = "seamless ambient loop";

const BATCHES = {
	// Los bichos y lo que hacen a la casa.
	bichos: [
		s("Golpe", 1.2, "Golpeador: puñetazo contra la persiana", `Single heavy fist pounding hard on a wooden window shutter from outside, deep violent thud with wood rattle, ${DRY}`),
		s("Grieta", 1.0, "La madera se agrieta", `Wooden board cracking under strain, sharp splintering crack, ${DRY}`),
		s("Cristal", 1.5, "Se rompe el cristal de una ventana", `Window glass shattering violently, shards falling on a wooden floor, ${DRY}`),
		s("Rugido", 2.5, "Rugido de un bicho", "Deep guttural monster roar, wet throaty growl, terrifying creature, horror game sound effect"),
		s("Paso", 0.8, "Paso pesado de un bicho", `Single heavy monster footstep on dirt, deep thud with a wet squelch, ${DRY}`),
		s("Raspado", 4, "Raspador arañando el cristal (bucle)", `Long fingernails slowly scraping across a glass window, high screeching scratch, creepy, ${LOOP}`, 2, true),
		s("Chillido", 1.5, "Chillido del Raspador al recibir el flash", "Creature shrieking in pain, piercing inhuman scream, horror monster sound effect"),
		s("Crujido", 2, "Trepador andando por el tejado", `Old wooden roof creaking under heavy weight, slow strained creak, ${DRY}`),
		s("Hollin", 3, "Algo se arrastra por dentro de la chimenea", "Something crawling and scraping inside a brick chimney, soot and debris falling, muffled, horror sound effect"),
		s("Llamar", 2, "El Imitador llama a la puerta", `Three calm knocks on a wooden front door, friendly knocking, ${DRY}`),
		s("Rama", 1, "Acechador: rama que cruje en el bosque", `Single dry branch snapping under a footstep in a dark forest, sharp crack, ${DRY}`),
		s("Susto", 1.5, "Susto al morir", "Horror jumpscare stinger, sudden loud dissonant orchestral hit with a screech"),
		s("Latido", 3, "Latido escondido (bucle)", `Slow heavy human heartbeat, deep muffled thumps, tense, ${LOOP}`, 2, true),
	],
	// La casa, el equipo y los trabajos.
	casa: [
		s("Persiana", 1.2, "Persiana que sube o baja", `Old metal roller shutter rolling down quickly, rattling slats, ${DRY}`),
		s("Puerta", 1.5, "Puerta que se abre", `Old wooden door creaking open slowly, ${DRY}`),
		s("Linterna", 0.5, "Encender o apagar la linterna", `Flashlight switch click, small plastic button, very short, ${DRY}`, 2),
		s("Flash", 1.0, "Flash de la cámara", `Old camera flash firing, shutter click with a short electronic pop and rising whine, ${DRY}`),
		s("Hachazo", 0.6, "Hachazo en un árbol", `Single axe chop into a tree trunk, solid wood thunk, ${DRY}`),
		s("Caida", 3, "Árbol que cae", "Large tree falling and crashing to the forest ground, wood cracking then heavy impact with branches"),
		s("Serrar", 3, "Serrar un tronco (bucle)", `Hand saw cutting through a wooden log, rhythmic sawing, ${LOOP}`, 2, true),
		s("Martillo", 0.5, "Martillazo en un clavo", `Single hammer hitting a nail into wood, sharp knock, ${DRY}`),
		s("Motor", 4, "Generador encendido (bucle)", `Small gasoline generator engine running, steady rumble, ${LOOP}`, 2, true),
		s("Verter", 2, "Echar gasolina", `Pouring gasoline from a jerry can into a tank, liquid glugging, ${DRY}`, 2),
		s("Fuego", 4, "Chimenea encendida (bucle)", `Fireplace fire crackling, warm wood burning, ${LOOP}`, 2, true),
		s("Cruje", 2, "La casa cruje sola (de ambiente)", `Old wooden house settling at night, single slow floorboard creak, distant, ${DRY}`, 4),
	],
	// Tus pasos según el suelo: todas las versiones se usan, alternadas.
	pasos: [
		s("PasoMadera", 0.5, "Paso en suelo de madera", `Single footstep on an old wooden floor, shoe on creaky boards, ${DRY}`, 4),
		s("PasoTierra", 0.5, "Paso en tierra", `Single footstep on a dirt path, soft crunch, ${DRY}`, 4),
		s("PasoHierba", 0.5, "Paso en hierba y hojas", `Single footstep on dry grass and leaves, soft rustle, ${DRY}`, 4),
	],
	// Lo que hubo que rehacer: el flash (los primeros no gustaron) y la cortina (pedido por el usuario: cortinas en vez
	// de persianas).
	rehacer: [
		s("FlashA", 0.8, "Flash: chasquido de cámara vieja y destello", `Vintage film camera taking a photo, sharp mechanical shutter clack with a bright electric flash pop, short, no whine, ${DRY}`, 2),
		s("FlashB", 1.2, "Flash: cámara instantánea", `Old instant camera taking a picture, loud shutter click followed by a short motor whirr, ${DRY}`, 2),
		s("FlashC", 0.6, "Flash: bombilla de flash que estalla", `Old magnesium flash bulb firing, a single sharp bright pop and crackle, very short, ${DRY}`, 2),
		// El que le gustó al usuario: foto con un flash muy fuerte y luego un pitido agudo que se apaga (como el oído
		// volviendo a la normalidad). Aquí solo el chasquido; el pitido lo añade tools/sonidos/pitido.mjs.
		s("FlashPop", 0.6, "Flash: chasquido fuerte de foto (sin el pitido)", `Loud camera flash going off, a very sharp punchy shutter snap with a bright electric flash burst, very short, ${DRY}`, 3),
		s("Cortina", 1.2, "Cortina que se corre", `Heavy fabric curtain being pulled closed quickly, metal rings sliding along a curtain rod, ${DRY}`, 3),
	],
	// Muchas ideas distintas de flash para que el usuario elija (los anteriores no le gustaron).
	flash: [
		s("F1Movil", 0.6, "Cámara de móvil: clic de obturador digital y fogonazo", `Smartphone camera shutter click with a sharp digital flash burst, crisp and loud, ${DRY}`, 2),
		s("F2Carrete", 0.9, "Cámara de carrete antigua: clac mecánico y arrastre del carrete", `Old film camera shutter clack followed by the film advance lever winding, mechanical, ${DRY}`, 2),
		s("F3Carga", 1.6, "Flash que se carga con un silbido que sube y estalla", `Camera flash charging with a rising high pitched electronic whine, then a loud sharp flash pop, ${DRY}`, 2),
		s("F4Polvora", 1.0, "Flash de magnesio antiguo: fogonazo con soplido", `Old magnesium flash powder igniting, a bright whoosh and a sharp crackling poof, ${DRY}`, 2),
		s("F5Aturdidor", 1.5, "Fogonazo de película: golpe fuerte y zumbido", "Cinematic blinding camera flash, a loud punchy snap with a deep impact and a short electric hum tail, horror movie sound effect", 2),
		s("F6Instantanea", 1.3, "Polaroid: clic y la foto saliendo", `Instant camera taking a picture, click then the photo ejecting with a short motor buzz, ${DRY}`, 2),
		s("F7Descarga", 0.7, "Descarga eléctrica: chasquido de condensador", `High voltage capacitor discharge, a sharp electric crack and zap, very short and loud, ${DRY}`, 2),
		s("F8Terror", 1.4, "Flash de terror: chasquido seco con eco", "Horror game camera flash, a dry loud shutter snap with a cold metallic ring and a short dark reverb tail", 2),
	],
	// Piezas sueltas para componer el ambiente del bosque por capas (componer.mjs): pedido entero sale mudo.
	ambiente: [
		s("viento", 4, "Racha de viento", "Cold wind gust blowing through forest trees at night, rises and fades, clean, no music", 3),
		s("grillo", 2, "Grillo", "Single cricket chirping at night, close, clean, no other sounds", 2),
		s("buho", 2, "Búho lejano", "Owl hooting once in a distant forest at night, clean", 2),
		s("lobo", 4, "Aullido lejano", "Distant wolf howl at night, very far away, eerie", 2),
		s("ramita", 1, "Ramita lejana", "Distant twig snapping in a forest, far away, quiet", 2),
		s("hojas", 3, "Hojas con la brisa", "Leaves rustling in a light breeze, soft, clean", 2),
	],
};

const key = apiKey();
try {
	const info = await (await fetch("https://api.elevenlabs.io/v1/user/subscription", { headers: { "xi-api-key": key } })).json();
	console.log(`Créditos: usados ${info.character_count} de ${info.character_limit} (plan ${info.tier})`);
} catch {
	console.log("No he podido leer los créditos");
}

let made = 0;
let failed = 0;
let stop = false;
for (const batch of wanted.length > 0 ? wanted : Object.keys(BATCHES)) {
	const sounds = BATCHES[batch];
	if (!sounds) {
		console.log(`No existe la tanda ${batch}`);
		continue;
	}
	const out = path.join(base, batch);
	fs.mkdirSync(out, { recursive: true });
	for (const sound of sounds) {
		for (let version = 1; version <= sound.versions && !stop; version++) {
			const file = path.join(out, `${sound.name}_${version}.mp3`);
			if (fs.existsSync(file)) continue;
			const body = { text: sound.text, duration_seconds: sound.seconds, prompt_influence: 0.6 };
			if (sound.loop) body.loop = true;
			const response = await fetch("https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128", {
				method: "POST",
				headers: { "xi-api-key": key, "Content-Type": "application/json" },
				body: JSON.stringify(body),
			});
			if (!response.ok) {
				failed++;
				console.log(`FALLO ${batch}/${sound.name}_${version}: ${response.status} ${(await response.text()).slice(0, 300)}`);
				stop = response.status === 401 || response.status === 402; // clave o créditos: no seguir
				continue;
			}
			fs.writeFileSync(file, Buffer.from(await response.arrayBuffer()));
			made++;
			console.log(`${batch}/${sound.name}_${version}.mp3`);
		}
	}

	// Página para escucharlos: un botón por versión, una fila por sonido.
	const rows = sounds.map((sound) => {
		const buttons = [];
		for (let version = 1; fs.existsSync(path.join(out, `${sound.name}_${version}.mp3`)); version++) {
			buttons.push(`<button data-src="${sound.name}_${version}.mp3">${version}</button>`);
		}
		return `<tr><td><b>${sound.label}</b><br><code>${sound.name}</code></td><td>${buttons.join(" ")}</td></tr>`;
	}).join("\n");
	fs.writeFileSync(path.join(out, "escuchar.html"), `<!doctype html>
<html lang="es"><meta charset="utf-8"><title>Sonidos: ${batch}</title>
<style>
body { font-family: system-ui, sans-serif; background: #1b1d24; color: #eee; max-width: 760px; margin: 24px auto; padding: 0 16px; }
td { padding: 8px 12px; border-bottom: 1px solid #333; vertical-align: middle; }
code { color: #8ab; font-size: 12px; }
button { font-size: 18px; width: 52px; height: 44px; margin-right: 6px; border-radius: 8px; border: 2px solid #000; background: #3a7bd5; color: #fff; cursor: pointer; }
button.last { background: #e2a03f; }
p { color: #aab; }
</style>
<h2>Sonidos del juego: ${batch}</h2>
<p>Pulsa un número para oír esa versión (el último que has pulsado se queda en naranja; al pulsar otro se corta el anterior).</p>
<table>
${rows}
</table>
<script>
let last, audio;
for (const button of document.querySelectorAll("button")) {
	button.onclick = () => {
		if (audio) audio.pause();
		audio = new Audio(button.dataset.src);
		audio.play();
		if (last) last.classList.remove("last");
		last = button;
		button.classList.add("last");
	};
}
</script>
</html>
`);
}
console.log(`Hechos ${made}, fallos ${failed}. Carpeta: ${base}`);
