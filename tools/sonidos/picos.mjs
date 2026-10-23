// Pico de cada mp3 de las carpetas (para igualar volúmenes: ganancia = 1 / pico). Uso: node picos.mjs <carpeta>...
import fs from "node:fs";
import path from "node:path";
import { MPEGDecoder } from "mpg123-decoder";

const decoder = new MPEGDecoder();
await decoder.ready;
for (const folder of process.argv.slice(2)) {
	for (const file of fs.readdirSync(folder).filter((n) => n.endsWith(".mp3")).sort()) {
		await decoder.reset();
		const { channelData, samplesDecoded } = decoder.decode(new Uint8Array(fs.readFileSync(path.join(folder, file))));
		let peak = 0;
		for (const ch of channelData) for (let i = 0; i < samplesDecoded; i++) peak = Math.max(peak, Math.abs(ch[i]));
		console.log(`${path.basename(folder)}/${file.replace(".mp3", "")} ${peak.toFixed(3)}`);
	}
}
