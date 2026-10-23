// Pasa el volcado de las MeshParts de un modelo subido (lo que devuelve en Studio el código de docs/sistemas/arte.md:
// una línea por malla "Nombre;MeshId;tamaño X;Y;Z;CFrame en 12 números") a un .rbxmx que Rojo mete en el juego.
// Uso: node tools/blender/volcar.mjs <volcado.txt> <salida.rbxmx> <nombre del modelo>
import fs from "node:fs";

const [input, output, name] = process.argv.slice(2);
const xml = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
const lines = fs.readFileSync(input, "utf8").split(/\r?\n/).filter((line) => line.includes(";"));
let ref = 1;
const items = lines.map((line) => {
	const [part, mesh, ...n] = line.split(";");
	const [sx, sy, sz, x, y, z, ...r] = n;
	const size = `<X>${sx}</X><Y>${sy}</Y><Z>${sz}</Z>`;
	const rot = ["R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"].map((k, i) => `<${k}>${r[i]}</${k}>`).join("");
	return `<Item class="MeshPart" referent="RBX${ref++}"><Properties><string name="Name">${xml(part)}</string>`
		+ `<Content name="MeshId"><url>${xml(mesh)}</url></Content><Vector3 name="size">${size}</Vector3>`
		+ `<Vector3 name="InitialSize">${size}</Vector3><CoordinateFrame name="CFrame"><X>${x}</X><Y>${y}</Y><Z>${z}</Z>${rot}`
		+ `</CoordinateFrame><bool name="Anchored">true</bool><bool name="CanCollide">false</bool>`
		+ `<bool name="DoubleSided">false</bool><token name="Material">256</token></Properties></Item>`;
});
fs.writeFileSync(output, `<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4">
<Item class="Model" referent="RBX0"><Properties><string name="Name">${xml(name)}</string></Properties>
${items.join("\n")}
</Item>
</roblox>
`);
console.log(`${items.length} mallas en ${output}`);
