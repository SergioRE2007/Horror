// Recibe una vez lo que Studio manda con HttpService:PostAsync a http://localhost:8766 y lo escribe en un archivo.
// Uso: node tools/receptor.mjs <archivo> [--base64]   (con --base64 decodifica el cuerpo: así llegan los .rbxm)
// Ejemplo en docs/sistemas/polyhaven.md (guardar ServerStorage.Muebles en src/muebles/Muebles.rbxm).
import fs from "node:fs";
import http from "node:http";

const [archivo, modo] = process.argv.slice(2);
const servidor = http.createServer((peticion, respuesta) => {
	const trozos = [];
	peticion.on("data", (trozo) => trozos.push(trozo));
	peticion.on("end", () => {
		const cuerpo = Buffer.concat(trozos);
		const datos = modo === "--base64" ? Buffer.from(cuerpo.toString("utf8"), "base64") : cuerpo;
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
servidor.listen(8766, "127.0.0.1", () => console.log("Esperando en http://localhost:8766"));
