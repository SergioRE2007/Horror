// Sirve una carpeta (texturas para upload_image de Studio, el .json de ids…) en http://localhost:8777 hasta cerrarlo.
// Uso: node tools/servir.mjs <carpeta> [--puerto 8778]   (cada copia de sala usa su puerto: plan-paralelo.md)
import fs from "node:fs";
import http from "node:http";
import path from "node:path";

const argumentos = process.argv.slice(2);
const iPuerto = argumentos.indexOf("--puerto");
const puerto = iPuerto >= 0 ? Number(argumentos.splice(iPuerto, 2)[1]) : 8777;
const carpeta = path.resolve(argumentos[0] || ".");
const TIPOS = { ".png": "image/png", ".jpg": "image/jpeg", ".json": "application/json", ".txt": "text/plain" };

http
	.createServer((peticion, respuesta) => {
		let archivo = "";
		try {
			archivo = path.join(carpeta, decodeURIComponent(new URL(peticion.url, "http://x").pathname));
		} catch {
			// Una dirección mal escrita no tumba el servidor: cae en el 404 de abajo.
		}
		// Nada fuera de la carpeta servida.
		if (!archivo.startsWith(carpeta + path.sep) || !fs.existsSync(archivo) || !fs.statSync(archivo).isFile()) {
			respuesta.statusCode = 404;
			respuesta.end("no está");
			return;
		}
		respuesta.setHeader("Content-Type", TIPOS[path.extname(archivo).toLowerCase()] || "application/octet-stream");
		fs.createReadStream(archivo).pipe(respuesta);
	})
	// Solo desde este equipo.
	.listen(puerto, "127.0.0.1", () => console.log(`Sirviendo ${carpeta} en http://localhost:${puerto}`));
