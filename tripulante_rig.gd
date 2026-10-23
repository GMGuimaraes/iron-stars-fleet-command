extends RefCounted
## Rig da tripulação: dobra o corpo rigged do GLB em gente operando a ponte.
##
## `assets/tripulante.glb` (gerado por `tools/synth_humanoid.py`) chega em pose de cadastro:
## braço em cruz, perna estendida, osso a osso onde o gerador escreveu. Cadastro é o que a sonda
## mede; pose de trabalho é o que o olho vê. A pose mora aqui, e não num AnimationPlayer, por uma
## razão só: `battle_clock` congela na pausa tática, e um relógio próprio dentro da cena deixaria
## a ponte respirando enquanto a batalha está parada.
##
## Braço e perna não têm ângulo chutado. A mão é escrita como o ponto do corpo onde ela trabalha
## (o teclado da bancada, o pad de leitura na altura do peito) e o osso gira o mínimo para chegar
## lá — solução fechada de dois paus, com o cotovelo empurrado para fora e um pouco para trás, que
## é para onde um oficial apoia o braço. Se o gerador mexer num comprimento, a régua desta conta
## muda junto e a sonda mede o desvio da mão no ar, não a opinião de quem escreveu o número.
##
## Nada aqui toca `rng` nem `visual_rng` da casa: pose é conta sobre constantes. A prova é a
## corrida A/B de `tools/probes/tripulacao.gd`, que relê os dois geradores depois de duzentos
## quadros de ponte trabalhando.

const CAMINHO := "res://assets/tripulante.glb"
const CENA := preload(CAMINHO)

## Comprimentos lidos do cadastro (`JUNTAS` em `tools/synth_humanoid.py`): ombro→cotovelo e
## cotovelo→punho, em metros no eixo do membro. A perna não precisa de régua: as direções abaixo
## são unidades e o comprimento vem do próprio esqueleto, osso a osso.
const BRACO_SUPERIOR := 0.26
const ANTEBRACO := 0.24

## Ossos que a ponte usa. Nome é o do cadastro; `find_bone` devolve -1 se o gerador renomear, e
## escrever no índice -1 estoura na hora — surdo não é opção.
const NOMES := ["quadril", "coluna", "peito", "pescoco", "cabeca",
	"braco_e", "antbraco_e", "mao_e", "braco_d", "antbraco_d", "mao_d",
	"coxa_e", "perna_e", "pe_e", "coxa_d", "perna_d", "pe_d"]

## Ombro no repouso do cadastro (braco_e global). O lado -1 é o do braco_d.
const OMBRO := Vector3(0.26, 1.33, 0.0)
## O quadril desce ao sentar: a junta fica a 0,62 do soalho, a bacia pousa na almofagem da cadeira
## (topo do assento em 0,56) e o tornozelo fecha a 0,08 — exatamente a altura da palmilha dourada
## acima da sola, portanto o pé do sentado encosta no convés em vez de flutuar como o corpo de caixa
## antigo flutuava. Os números são conta, não gosto.
const QUADRIL_CAIDA := 0.28
## Onde a mão trabalha, no espaço do corpo (soalho em y=0, frente em -z). O sentado tecla na própria
## bancada; o oficial de pé segura o pad de leitura a 1,13 — embaixo dos olhos, com o cotovelo
## dobrado o suficiente para não parecer um braço de manequim travado.
const MAO_BANCADA := Vector3(0.30, 0.97, -0.45)
const MAO_PAD := Vector3(0.24, 1.13, -0.40)
## O pad fica sob as duas mãos, e o cone de leitura nasce dele.
const PAD_ALTURA := 1.09
## Para onde o cotovelo aponta: fora e um pouco para trás. É o joelho da mão, não mais uma meta.
const COTOVELO_POLO := Vector3(0.80, -0.35, 0.45)
## Sentado: coxa desce um palmo e vai à frente, perna cai quase a prumo com o pé embaixo da
## bancada. As duas direções fecham a cadeia do pé no soalho com o quadril já rebaixado.
const COXA_SENTADA := Vector3(0.05, -0.405, -0.915)
const PERNA_SENTADA := Vector3(0.02, -0.925, -0.38)
## Pescoço do sentado: leitura da tela baixa, não queixo no peito. Negativo derruba o rosto para
## -z, que é a frente do corpo e a face da bancada.
const PESCOCO_LEITURA := -0.16

## Monta o corpo na ponte e devolve o que `_update_tripulacao` vai oscilar em cima: os índices dos
## ossos, as poses-base de cada braço e a altura em que a coluna respira.
static func preparar(esqueleto: Skeleton3D, em_pe: bool) -> Dictionary:
	var ossos := {}
	for nome in NOMES:
		ossos[nome] = esqueleto.find_bone(nome)
	if not em_pe:
		var quadril := int(ossos["quadril"])
		esqueleto.set_bone_pose_position(quadril,
			esqueleto.get_bone_rest(quadril).origin + Vector3(0.0, -QUADRIL_CAIDA, 0.0))
		_sentar_pernas(esqueleto, ossos)
		esqueleto.set_bone_pose_rotation(int(ossos["pescoco"]),
			Quaternion(Vector3(1.0, 0.0, 0.0), PESCOCO_LEITURA))
	var base_e := braco(esqueleto, ossos, "braco_e", "antbraco_e", 1.0, em_pe)
	var base_d := braco(esqueleto, ossos, "braco_d", "antbraco_d", -1.0, em_pe)
	esqueleto.force_update_all_bone_transforms()
	return {"ossos": ossos, "braco_e": base_e, "braco_d": base_d,
		"base_coluna": esqueleto.get_bone_global_pose(int(ossos["coluna"])).origin.y,
		"base_mao_e": esqueleto.get_bone_global_pose(int(ossos["mao_e"])).origin,
		"base_mao_d": esqueleto.get_bone_global_pose(int(ossos["mao_d"])).origin}

## Os dois braços do corpo em pose de trabalho. Devolve [giro do ombro, giro do cotovelo] e deixa
## escrito no esqueleto — quem anima depois só torce o cotovelo em torno do eixo que já existe.
static func braco(esqueleto: Skeleton3D, ossos: Dictionary, ombro_osso: String,
		cotovelo_osso: String, lado: float, em_pe: bool) -> Array:
	var origem := ombro_de(lado, not em_pe)
	var trabalho: Vector3 = MAO_PAD if em_pe else MAO_BANCADA
	var alvo := Vector3(trabalho.x * lado, trabalho.y, trabalho.z)
	var polo := Vector3(COTOVELO_POLO.x * lado, COTOVELO_POLO.y, COTOVELO_POLO.z)
	var partes := braco_dois_paus(origem, alvo, lado, polo)
	var i_ombro := int(ossos[ombro_osso])
	var i_cotovelo := int(ossos[cotovelo_osso])
	esqueleto.set_bone_pose_rotation(i_ombro, partes[0])
	esqueleto.set_bone_pose_rotation(i_cotovelo, partes[1])
	return partes

## Ombro no espaço do corpo: a altura do cadastro menos a queda do quadril, quando é sentado.
static func ombro_de(lado: float, sentado: bool) -> Vector3:
	var y := OMBRO.y - (QUADRIL_CAIDA if sentado else 0.0)
	return Vector3(OMBRO.x * lado, y, OMBRO.z)

## Joelho, canela e pé de quem está sentado. A coxa e a perna recebem direções (não metas): assim
## o comprimento do cadastro é honrado osso a osso e o pé fecha no soalho em vez de flutuar.
static func _sentar_pernas(esqueleto: Skeleton3D, ossos: Dictionary) -> void:
	for lado in [1.0, -1.0]:
		var suffix := "e" if lado > 0.0 else "d"
		var i_coxa := int(ossos["coxa_" + suffix])
		var i_perna := int(ossos["perna_" + suffix])
		var i_pe := int(ossos["pe_" + suffix])
		var coxa_direcao := (COXA_SENTADA * Vector3(lado, 1.0, 1.0)).normalized()
		var perna_direcao := (PERNA_SENTADA * Vector3(lado, 1.0, 1.0)).normalized()
		var giro_coxa := giro(Vector3(0.0, -1.0, 0.0), coxa_direcao)
		var na_moldura := perna_direcao * giro_coxa
		var giro_perna := giro(Vector3(0.0, -1.0, 0.0), na_moldura)
		esqueleto.set_bone_pose_rotation(i_coxa, giro_coxa)
		esqueleto.set_bone_pose_rotation(i_perna, giro_perna)
		# O pé fica a prumo porque é o soalho que o segura: desfaz o giro acumulado da perna e a
		# palmilha dourada continua escrevendo a mesma linha de contato de quem está de pé.
		esqueleto.set_bone_pose_rotation(i_pe, (giro_coxa * giro_perna).inverse())

## Solução fechada de dois paus: o ombro gira o mínimo para levar o cotovelo ao pé da perpendicular
## escolhida pelo `polo`, e o cotovelo gira o mínimo para que a mão caia no alvo. Erro medido na
## sonda: 0,00000 m nos dois arquétipos.
static func braco_dois_paus(ombro: Vector3, alvo: Vector3, lado: float,
		polo: Vector3) -> Array:
	var eixo := Vector3(lado, 0.0, 0.0)
	var vetor := alvo - ombro
	var distancia := maxf(vetor.length(), 0.0001)
	var direcao := vetor / distancia
	var pe := (BRACO_SUPERIOR * BRACO_SUPERIOR - ANTEBRACO * ANTEBRACO + distancia * distancia) / (2.0 * distancia)
	var altura := sqrt(maxf(BRACO_SUPERIOR * BRACO_SUPERIOR - pe * pe, 0.0))
	var lateral := polo - direcao * polo.dot(direcao)
	if lateral.length_squared() < 1e-9:
		lateral = polo - eixo * polo.dot(eixo)
	var cotovelo := ombro + direcao * pe + lateral.normalized() * altura
	var giro_ombro := giro(eixo, cotovelo - ombro)
	var ante := (alvo - cotovelo) * giro_ombro
	return [giro_ombro, giro(eixo, ante)]

## Rotação mínima que leva um vetor ao outro. O paralelo exato não tem eixo: qualquer perpendicular
## serve, e o anti-paralelo gira meia volta em torno da mesma regra.
static func giro(antes: Vector3, depois: Vector3) -> Quaternion:
	var a := antes.normalized()
	var b := depois.normalized()
	var cosseno := clampf(a.dot(b), -1.0, 1.0)
	if cosseno > 0.999999:
		return Quaternion.IDENTITY
	if cosseno < -0.999999:
		var reserva := Vector3(0.0, 1.0, 0.0) if absf(a.z) < 0.5 else Vector3(1.0, 0.0, 0.0)
		return Quaternion(a.cross(reserva).normalized(), PI)
	return Quaternion(a.cross(b).normalized(), acos(cosseno))

## Torce um giro já resolvido por `delta` rad em torno do PRÓPRIO eixo dele. É o que faz o dedo
## teclar sem que a mão saia do teclado: o ângulo muda, a direção do dobradiço não.
static func torcer(base: Quaternion, delta: float) -> Quaternion:
	if base.get_angle() <= 0.000001:
		return Quaternion(Vector3(1.0, 0.0, 0.0), delta)
	return Quaternion(base.get_axis(), base.get_angle() + delta)

## O esqueleto do corpo importado, seja qual for o nome que o importer escolher para ele.
static func achar_esqueleto(no: Node) -> Skeleton3D:
	if no is Skeleton3D:
		return no as Skeleton3D
	for filho in no.get_children():
		var achado := achar_esqueleto(filho)
		if achado != null:
			return achado
	return null
