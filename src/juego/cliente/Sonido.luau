-- Sonidos de la partida: la implementación es la de comun/cliente/Sonido (16.17); aquí solo se pide la versión del juego,
-- con el Oído (OidoVista) para que las paredes tapen lo que suena en 3D.
return require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Sonido")).nuevo("juego", require(script.Parent.OidoVista))
