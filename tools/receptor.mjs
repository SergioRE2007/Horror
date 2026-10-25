// Recibe una vez lo que Studio manda con HttpService:PostAsync a http://localhost:8766 y lo escribe en un archivo.
// Uso: node tools/receptor.mjs <archivo> [--base64] [--puerto 8767]   (con --base64 decodifica el cuerpo: así llegan
// los .rbxm; cada copia de sala usa su puerto para no chocar con otro chat: plan-paralelo.md)
// Ejemplo en docs/sistemas/polyhaven.md (guardar ServerStorage.Muebles en src/muebles/Muebles.rbxm).
import fs from "node:fs";
import http from "node:http";
import zlib from "node:zlib";

const argumentos = process.argv.slice(2);
const iPuerto = argumentos.indexOf("--puerto");
const puerto = iPuerto >= 0 ? Number(argumentos.splice(iPuerto, 2)[1]) : 8766;
const [archivo, modo] = argumentos;
// Lo que pasa de 1024 KB aun comprimido (Muebles.rbxm, desde la cocina) llega en varios envíos con la cabecera
// X-Trozo: "k/n" (el texto partido, de 1 a n); se juntan en orden y se escribe al llegar el último.
const recibidos = [];
const servidor = http.createServer((peticion, respuesta) => {
	const trozos = [];
	peticion.on("data", (trozo) => trozos.push(trozo));
	peticion.on("end", () => {
		const trozo = (peticion.headers["x-trozo"] || "1/1").split("/").map(Number);
		// Un trozo mal numerado dejaría un hueco y un archivo roto: se rechaza.
		const [k, n] = trozo;
		if (!Number.isInteger(k) || !Number.isInteger(n) || k < 1 || k > n || (recibidos.total && recibidos.total !== n)) {
			respuesta.statusCode = 400;
			respuesta.end("trozo mal numerado");
			return;
		}
		recibidos.total = n;
		recibidos[k - 1] = Buffer.concat(trozos);
		if (recibidos.filter(Boolean).length < trozo[1]) {
			respuesta.end("trozo " + trozo[0]);
			return;
		}
		const cuerpo = Buffer.concat(recibidos);
		let datos = modo === "--base64" ? Buffer.from(cuerpo.toString("utf8"), "base64") : cuerpo;
		// Studio solo deja mandar 1024 KB (mira el tamaño antes de su Gzip): lo grande (Muebles.rbxm, desde el comedor)
		// llega comprimido con EncodingService:CompressBuffer (Zstd) y la cabecera X-Comprimido.
		if (peticion.headers["x-comprimido"] === "zstd") datos = zlib.zstdDecompressSync(datos);
		// A un temporal y luego renombrar: un envío cortado no deja el archivo a medias.
		fs.writeFileSync(archivo + ".tmp", datos);
		fs.renameSync(archivo + ".tmp", archivo);
		// Cerrar cuando la respuesta ya ha salido (si no, Studio podría recibir un error aunque el archivo esté bien).
		respuesta.on("finish", () => {
			servidor.close();
			servidor.closeAllConnections();
		});
		respuesta.end("ok " + datos.length);
		console.log(`${archivo}: ${datos.length} bytes`);
	});
});
// Solo desde este equipo: nadie de la red puede mandarle nada.
servidor.listen(puerto, "127.0.0.1", () => console.log(`Esperando en http://localhost:${puerto}`));
