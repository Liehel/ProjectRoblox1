-- Shoreline edge parts (tag "ShoreGlow").
--
-- Estas partes son marcadores invisibles del borde de la isla: el juego las
-- necesita ocultas, no visibles. Antes ademas les colgaba un ParticleEmitter
-- con Rate = 400, que con Lifetime de hasta 2.6s daban ~1000 particulas VIVAS
-- por cada parte etiquetada, siempre, mirara el jugador o no. Ese efecto se
-- retiro por peticion; aqui solo queda el ocultado.
--
-- Si en algun momento quieres recuperar el brillo, hazlo con Rate bajo (unos
-- 90 en PC y 30 en movil), nunca con 400.

local CollectionService = game:GetService("CollectionService")

local GLOW_TAG = "ShoreGlow"

local function track(part)
	if not part:IsA("BasePart") then return end

	part.Transparency = 1
	part.CanCollide   = false
	part.CastShadow   = false

	-- limpia el emisor antiguo si el place todavia lo trae guardado
	local old = part:FindFirstChild("ShoreSparkle")
	if old then old:Destroy() end
end

for _, p in ipairs(CollectionService:GetTagged(GLOW_TAG)) do track(p) end
CollectionService:GetInstanceAddedSignal(GLOW_TAG):Connect(track)
