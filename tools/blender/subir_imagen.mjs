// Sube imágenes .png a Roblox como calcomanías (Decal) del grupo por Open Cloud y escribe el id de cada una.
// Uso: node tools/blender/subir_imagen.mjs <clave> <imagen.png> [más .png...]
// El id es el de la calcomanía: en Studio, game:GetObjects("rbxassetid://<id>")[1].Texture da el de la imagen,
// que es el que se pone en SurfaceAppearance o ImageLabel.
import fs from "node:fs";
import path from "node:path";

const [keyFile, ...files] = process.argv.slice(2);
const key = fs.readFileSync(keyFile, "utf8").trim();
const group = "1002188803";
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

for (const file of files) {
	const form = new FormData();
	form.append("request", JSON.stringify({
		assetType: "Decal",
		displayName: path.basename(file, ".png"),
		description: "Textura del juego",
		creationContext: { creator: { groupId: group } },
	}));
	form.append("fileContent", new Blob([fs.readFileSync(file)], { type: "image/png" }), path.basename(file));
	const response = await fetch("https://apis.roblox.com/assets/v1/assets", { method: "POST", headers: { "x-api-key": key }, body: form });
	if (!response.ok) {
		console.log(`FALLO ${path.basename(file)}: ${response.status} ${(await response.text()).slice(0, 300)}`);
		continue;
	}
	let operation = await response.json();
	for (let attempt = 0; attempt < 40 && !operation.done; attempt++) {
		await sleep(2000);
		const poll = await fetch(`https://apis.roblox.com/assets/v1/operations/${operation.operationId ?? operation.path.split("/").pop()}`, { headers: { "x-api-key": key } });
		if (poll.ok) operation = await poll.json();
	}
	console.log(`${path.basename(file)} = ${operation.response?.assetId ?? "sin id"}  (${operation.response?.moderationResult?.moderationState ?? "?"})`);
}
