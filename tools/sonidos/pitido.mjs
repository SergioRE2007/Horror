// Añade a un sonido un pitido agudo que se va apagando, como el oído que vuelve a la normalidad tras un fogonazo
// (pedido por el usuario para el flash). El pitido se hace por código: dos tonos muy agudos casi iguales (laten un
// poco), que entran justo después del golpe y se apagan en unos segundos.
// Uso: node tools/sonidos/pitido.mjs <entrada.mp3> <salida.wav> [segundos del pitido] [volumen] [hercios]
import fs from "node:fs";
import { MPEGDecoder } from "mpg123-decoder";

const [input, output, secondsText = "3.2", levelText = "0.22", hzText = "7200"] = process.argv.slice(2);
const hz = Number(hzText);
const RATE = 44100;
const ring = Number(secondsText);
const level = Number(levelText);

const decoder = new MPEGDecoder();
await decoder.ready;
const { channelData, samplesDecoded, sampleRate } = decoder.decode(new Uint8Array(fs.readFileSync(input)));
if (sampleRate !== RATE) throw new Error(`Se esperaba ${RATE} Hz y es ${sampleRate}`);

// Dónde está el golpe: el pico del sonido. El pitido empieza un poco después.
let peakAt = 0;
let peak = 0;
for (let i = 0; i < samplesDecoded; i++) {
	const v = Math.abs(channelData[0][i]);
	if (v > peak) {
		peak = v;
		peakAt = i;
	}
}
const start = peakAt + Math.round(0.06 * RATE);
const length = Math.max(samplesDecoded, start + Math.round(ring * RATE));
const out = [new Float32Array(length), new Float32Array(length)];
for (let c = 0; c < 2; c++) {
	const src = channelData[Math.min(c, channelData.length - 1)];
	for (let i = 0; i < samplesDecoded; i++) out[c][i] = src[i] * (0.95 / peak);
}
for (let i = start; i < length; i++) {
	const t = (i - start) / RATE;
	const attack = Math.min(1, t / 0.04);
	const decay = Math.exp(-t * 1.6) * Math.max(0, 1 - t / ring); // se apaga del todo al final
	const wobble = 1 + 0.002 * Math.sin(2 * Math.PI * 5 * t);
	const v = level * attack * decay * (0.6 * Math.sin(2 * Math.PI * hz * wobble * t) + 0.4 * Math.sin(2 * Math.PI * (hz + 30) * t));
	out[0][i] += v;
	out[1][i] += v;
}

// WAV de 16 bits.
const data = Buffer.alloc(length * 4);
for (let i = 0; i < length; i++) {
	for (let c = 0; c < 2; c++) {
		const v = Math.max(-1, Math.min(1, out[c][i]));
		data.writeInt16LE(Math.round(v * 32767), i * 4 + c * 2);
	}
}
const header = Buffer.alloc(44);
header.write("RIFF", 0);
header.writeUInt32LE(36 + data.length, 4);
header.write("WAVEfmt ", 8);
header.writeUInt32LE(16, 16);
header.writeUInt16LE(1, 20);
header.writeUInt16LE(2, 22);
header.writeUInt32LE(RATE, 24);
header.writeUInt32LE(RATE * 4, 28);
header.writeUInt16LE(4, 32);
header.writeUInt16LE(16, 34);
header.write("data", 36);
header.writeUInt32LE(data.length, 40);
fs.writeFileSync(output, Buffer.concat([header, data]));
console.log(`${output}: ${(length / RATE).toFixed(2)} s, pitido desde ${(start / RATE).toFixed(2)} s`);
