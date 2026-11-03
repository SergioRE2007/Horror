export const meta = {
  name: 'revisar-lobby',
  description: 'Revisa el lobby nuevo con el agente reviewer, verifica cada hallazgo y arregla lo GRAVE y MEDIO',
  phases: [
    { title: 'Revisar', detail: 'agente reviewer por grupo de archivos' },
    { title: 'Verificar', detail: 'escéptico que relee el código' },
    { title: 'Arreglar', detail: 'arreglos pequeños en los mismos archivos' },
  ],
}

// Vale en local (Windows, Rokit: selene y lune en el PATH) y en la nube (pasar args.nube = true tras
// bash tools/nube/herramientas.sh, que los deja en /tmp/herramientas/bin).
const NUBE = !!(args && !Array.isArray(args) && args.nube)
const ROOT = 'la raíz del repo (el directorio de trabajo)'
const SELENE = NUBE ? '/tmp/herramientas/bin/selene' : 'selene'
const LUNE = NUBE ? '/tmp/herramientas/bin/lune' : 'lune'

const GRUPOS = [
  { key: 'base', files: ['src/lobby/servidor/Gasolinera.luau', 'src/lobby/servidor/GasolineraCoches.luau', 'src/lobby/servidor/GasolineraPiezas.luau'] },
  { key: 'tiendafuera', files: ['src/lobby/servidor/GasolineraTienda.luau', 'src/lobby/servidor/GasolineraFuera.luau'] },
  { key: 'vidaclima', files: ['src/lobby/cliente/GasolineraVista.luau', 'src/lobby/cliente/Clima.luau'] },
  { key: 'salida', files: ['src/lobby/cliente/SalidaVista.luau', 'src/lobby/cliente/Bucle.luau', 'src/lobby/cliente/Sonido.luau', 'src/lobby/cliente/init.client.luau'] },
]

const CONTEXTO = `El lobby de este juego de terror de Roblox (repo ${ROOT}, proyecto lobby.project.json) se acaba de rehacer entero por código (commits acf45ed, a963947 y 51e2817 de la rama actual; mira git show --stat). Se hizo sin Roblox Studio (solo un arnés de Lune del mapa del servidor); no le des a Play aunque esté conectado: lo prueba el principal. Contrato entre servidor y cliente (etiquetas y atributos): LuzFalla (Fallo, Zumba), Polillas, Charco, Goteo, PuertaAuto (Hoja1/Hoja2 con Desliza, Centro), Nevera, Radio, Chapa, Dentro, Sombra (Hacia, Largo), coches en workspace.Coches con etiqueta Coche (Carroceria, Asiento1..4, Faro con SpotLight Haz y PointLight Brillo, Piloto, Limpia1/2 con Eje y Normal, Attachment Escape, Rueda), Mostrador con su ProximityPrompt Tienda, atributo local SaliendoLocal. Lobby/servidor/Coches pone en el coche el atributo Salida (hora del servidor) y lo quita al pararse o al vaciarse tras un viaje. Reglas: brillos flojos, nada de Neon en piezas grandes, un solo bucle (lobby/cliente/Bucle) y solo cerca de la cámara, Rendimiento, móvil, cinemáticas que esconden la interfaz y la devuelven siempre.`

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' }, line: { type: 'integer' },
          severity: { type: 'string', enum: ['GRAVE', 'MEDIO', 'LEVE'] },
          title: { type: 'string' }, scenario: { type: 'string' }, fix: { type: 'string' },
        },
        required: ['file', 'line', 'severity', 'title', 'scenario', 'fix'],
      },
    },
  },
  required: ['findings'],
}
const VERDICTS = {
  type: 'object',
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          index: { type: 'integer' }, real: { type: 'boolean' },
          severity: { type: 'string', enum: ['GRAVE', 'MEDIO', 'LEVE'] },
          reason: { type: 'string' }, fix: { type: 'string' },
        },
        required: ['index', 'real', 'severity', 'reason', 'fix'],
      },
    },
  },
  required: ['verdicts'],
}
const FIXED = {
  type: 'object',
  properties: {
    arreglos: { type: 'array', items: { type: 'object', properties: { hallazgo: { type: 'string' }, estado: { type: 'string' }, que: { type: 'string' } }, required: ['hallazgo', 'estado', 'que'] } },
    selene: { type: 'string' },
    otros: { type: 'string' },
  },
  required: ['arreglos', 'selene', 'otros'],
}

const res = await pipeline(
  GRUPOS,
  g => agent(`${CONTEXTO}\n\nRevisa ENTEROS estos archivos (son nuevos: todo su contenido es el cambio): ${g.files.join(', ')}. Busca fallos reales: errores en ejecución (nil, tipos, APIs de Roblox mal usadas o que no existen), cosas que se acumulan o no se borran, bucles caros o por fotograma sin necesidad, lo que no respeta el contrato de arriba, lo que choca donde no debe (aparición, pasillo de la puerta, salida de los coches), luces demasiado fuertes, y lo que rompería el lobby en móvil. Devuelve solo lo comprobado, con archivo:línea.`,
    { label: 'revisar:' + g.key, phase: 'Revisar', schema: FINDINGS, agentType: 'reviewer' }),
  async (r, g) => {
    const lista = (r && r.findings || []).filter(f => f.severity !== 'LEVE')
    if (lista.length === 0) return { g, todos: r ? r.findings : [], reales: [] }
    const v = await agent(`Eres un revisor escéptico. ${CONTEXTO}\n\nOtro revisor dice haber encontrado estos fallos en ${g.files.join(', ')}. Para CADA uno, relee tú el código y trata de refutarlo: es real solo si el caso pasa de verdad con el código como está. Si no estás seguro, real=false. Corrige la gravedad si está inflada y afina el arreglo (pequeño y seguro).\n\n${JSON.stringify(lista.map((f, i) => ({ index: i, ...f })), null, 1)}`,
      { label: 'verificar:' + g.key, phase: 'Verificar', schema: VERDICTS })
    const reales = (v ? v.verdicts : []).filter(x => x.real && x.severity !== 'LEVE').map(x => ({ ...lista[x.index], severity: x.severity, reason: x.reason, fix: x.fix }))
    return { g, todos: r.findings, reales }
  },
  async (o) => {
    if (!o || o.reales.length === 0) return { grupo: o ? o.g.key : '?', todos: o ? o.todos : [], reales: [], arreglo: null }
    const f = await agent(`Eres un senior developer de Roblox/Luau. ${CONTEXTO}\n\nArregla estos fallos confirmados con el cambio más pequeño y seguro, solo en tus archivos (${o.g.files.join(', ')}; hay otros agentes editando otros archivos a la vez, no toques nada más). Comentarios en español. Comprueba al acabar desde ${ROOT}: ${SELENE} <tus archivos> sin avisos y ${LUNE} run tests/regressions.luau en verde. Sin commits.\n\n${JSON.stringify(o.reales, null, 1)}`,
      { label: 'arreglar:' + o.g.key, phase: 'Arreglar', schema: FIXED })
    return { grupo: o.g.key, todos: o.todos, reales: o.reales, arreglo: f }
  },
)
return res.filter(Boolean)
