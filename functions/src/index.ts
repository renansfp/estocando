import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  FUNÇÕES EXISTENTES — não alteradas
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// O "PORQUÊ": Esta função executa quando um novo usuário se cadastra.
// Ela desabilita a conta e cria um perfil 'pendente' no Firestore.
export const onUserCreate = functions
  .region("southamerica-east1")
  .auth.user()
  .onCreate(async (user: functions.auth.UserRecord) => {
    const { email, uid, displayName } = user;
    functions.logger.info(`Novo usuário: ${email}, UID: ${uid}`);

    try {
      await admin.auth().updateUser(uid, { disabled: true });
      functions.logger.info(`Usuário ${uid} desabilitado com sucesso.`);

      const userProfile = {
        email: email,
        nome: displayName || "Não informado",
        dataCriacao: admin.firestore.FieldValue.serverTimestamp(),
        status: "pendente",
      };

      await admin.firestore().collection("usuarios").doc(uid)
        .set(userProfile);
      functions.logger.info(`Perfil do usuário ${uid} criado no Firestore.`);
    } catch (error) {
      functions.logger.error(`Erro ao processar usuário ${uid}:`, error);
    }
  });

// O "PORQUÊ": Esta função é chamada pelo app para aprovar um usuário.
// Ela habilita a conta no Auth e atualiza o status no Firestore.
export const approveUser = functions
  .region("southamerica-east1")
  .https.onCall(async (data: any, context: functions.https.CallableContext) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "A função precisa ser chamada por um usuário autenticado."
      );
    }

    const { uid } = data;
    if (!uid) {
      throw new functions.https.HttpsError(
        "invalid-argument", "O UID do usuário é obrigatório."
      );
    }

    try {
      await admin.auth().updateUser(uid, { disabled: false });
      await admin.firestore().collection("usuarios").doc(uid)
        .update({ status: "aprovado" });

      functions.logger.info(`Usuário ${uid} aprovado com sucesso.`);
      return { message: "Usuário aprovado com sucesso!" };
    } catch (error) {
      functions.logger.error(`Erro ao aprovar usuário ${uid}:`, error);
      throw new functions.https.HttpsError(
        "internal", "Ocorreu um erro ao aprovar o usuário."
      );
    }
  });

export const rejectUser = functions
  .region("southamerica-east1")
  .https.onCall(async (data: any, context: functions.https.CallableContext) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "A função precisa ser chamada por um usuário autenticado."
      );
    }

    const { uid } = data;
    if (!uid) {
      throw new functions.https.HttpsError(
        "invalid-argument", "O UID do usuário é obrigatório."
      );
    }

    try {
      await admin.auth().deleteUser(uid);
      functions.logger.info(`Usuário ${uid} deletado do Authentication.`);
      await admin.firestore().collection("usuarios").doc(uid).delete();
      functions.logger.info(`Perfil do usuário ${uid} deletado do Firestore.`);
      return { message: "Usuário recusado e excluído com sucesso!" };
    } catch (error) {
      functions.logger.error(`Erro ao recusar usuário ${uid}:`, error);
      throw new functions.https.HttpsError(
        "internal", "Ocorreu um erro ao recusar o usuário."
      );
    }
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  UTILITÁRIO INTERNO — mapeamento de status → chaves do contador
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
//  Por que existe:
//  Cada extintor tem um "status" (ex: "aguardando_lixa") e um
//  "tipoAgente" (ex: "CO2"). Precisamos saber quais chaves do
//  documento de contadores incrementar/decrementar.
//
//  Exemplo:
//    status = "aguardando_recarga", agente = "CO2"
//    → retorna ["recarga", "recargaCO2"]
//
//  A lógica espelha exatamente o _calcularContadores() do Flutter.

function obterChavesContador(status: string, tipoAgente: string): string[] {
  const s = (status || "").toLowerCase().replace(/_/g, "");
  const ag = (tipoAgente || "").toUpperCase();
  const chaves: string[] = [];

  // ── Recarga (usa "contains" porque pode ser "aguardando_recarga_co2" etc.) ──
  if (s.includes("aguardandorecarga")) {
    chaves.push("recarga");
    if (ag === "ABC") chaves.push("recargaABC");
    else if (ag === "BC" || ag === "PQS") chaves.push("recargaBC");
    else if (["AP", "ESP", "AGUA"].includes(ag)) chaves.push("recargaAgua");
    else if (ag === "CO2") chaves.push("recargaCO2");
    return chaves;
  }

  // ── Estanqueidade ──────────────────────────────────────────────────────────
  if (s.includes("aguardandoestanqueidade")) {
    chaves.push("estanqueidade");
    if (ag === "ABC") chaves.push("estanqueABC");
    else if (ag === "BC" || ag === "PQS") chaves.push("estanqueBC");
    else if (["AP", "ESP", "AGUA"].includes(ag)) chaves.push("estanqueAgua");
    else if (ag === "CO2") chaves.push("estanqueCO2");
    return chaves;
  }

  // ── Demais estações (mapeamento direto) ────────────────────────────────────
  const mapa: Record<string, string> = {
    "aguardandodescarga":           "descarga",
    "aguardandolimpeza":            "limpeza",
    "aguardandolixa":               "lixa",
    "aguardandomanutencaovalvula":  "manutencao",
    "aguardandosaquevalvula":       "saque",
    "aguardandopintura":            "pintura",
    "aguardandopremontagem":        "premontagem",
    "aguardandomontagem":           "montagem",
    "aguardandoth":                 "teste",
    "aguardandomanutencaovalvulapo":"valvulaPo",
    "aguardandoexpedicao":          "expedicao",
  };

  const chavePrincipal = mapa[s];
  if (!chavePrincipal) return chaves; // status não rastreado (ex: "condenado")

  chaves.push(chavePrincipal);

  // Sub-chaves para descarga (por tipo de agente)
  if (s === "aguardandodescarga") {
    if (ag === "ABC") chaves.push("descargaABC");
    else if (ag === "BC" || ag === "PQS") chaves.push("descargaBC");
    else if (ag === "CO2") chaves.push("descargaCO2");
    else if (["AP", "ESP", "AGUA"].includes(ag)) chaves.push("descargaAgua");
  }

  return chaves;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  NOVA FUNÇÃO 1 — atualizarContadoresDashboard
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
//  O "PORQUÊ":
//  Antes, o app Flutter lia TODOS os itens em produção para calcular
//  os badges do dashboard (ex: com 500 itens → 500 leituras por evento).
//  Agora um documento "contadores/{empresaId}" mantém os totais prontos.
//  O app lê 1 documento; esta função mantém ele atualizado.
//
//  Como funciona:
//  Toda vez que um item em "itens_os" é criado, alterado ou removido,
//  esta função calcula a diferença (quanto incrementar/decrementar)
//  e aplica no documento de contadores usando FieldValue.increment().
//  Isso garante que nunca haja condição de corrida entre dois operadores
//  bipando ao mesmo tempo.
//
//  Analogia: é como um placar de futebol. Em vez de contar os gols
//  assistindo ao replay do jogo todo a cada minuto, alguém atualiza
//  o placar a cada gol. Você só olha o placar.

export const atualizarContadoresDashboard = functions
  .region("southamerica-east1")
  .firestore.document("itens_os/{itemId}")
  .onWrite(async (change, context) => {
    const antes = change.before.exists ? change.before.data() : null;
    const depois = change.after.exists ? change.after.data() : null;

    // Obtém o empresaId de qualquer versão disponível do documento
    const empresaId = depois?.empresaId || antes?.empresaId;
    if (!empresaId) {
      functions.logger.warn("Item sem empresaId — ignorado.", context.params);
      return;
    }

    // Acumula o delta (quanto cada chave deve mudar)
    // Usamos número puro aqui e depois convertemos para FieldValue.increment()
    const delta: Record<string, number> = {};

    // ── Decrementa os contadores do status ANTERIOR ────────────────
    // Só conta se o item estava em produção antes da mudança
    if (antes && antes.statusAtual === "emProducao") {
      for (const chave of obterChavesContador(antes.status, antes.tipoAgente)) {
        delta[chave] = (delta[chave] || 0) - 1;
      }
    }

    // ── Incrementa os contadores do status NOVO ────────────────────
    // Só conta se o item continua em produção após a mudança
    if (depois && depois.statusAtual === "emProducao") {
      for (const chave of obterChavesContador(depois.status, depois.tipoAgente)) {
        delta[chave] = (delta[chave] || 0) + 1;
      }
    }

    // Se nada mudou nos contadores (ex: só o nome do operador foi salvo),
    // não há nada a fazer — evita escritas desnecessárias no Firestore
    const chavesMudaram = Object.values(delta).some((v) => v !== 0);
    if (!chavesMudaram) return;

    // Converte o delta em FieldValue.increment() — operação atômica do Firestore
    // Isso garante que dois operadores bipando ao mesmo tempo não se pisem
    const updates: Record<string, admin.firestore.FieldValue> = {};
    for (const [chave, valor] of Object.entries(delta)) {
      if (valor !== 0) {
        updates[chave] = admin.firestore.FieldValue.increment(valor);
      }
    }

    const contadorRef = admin.firestore()
      .collection("contadores")
      .doc(empresaId);

    await contadorRef.set(updates, { merge: true });

    functions.logger.info(
      `Contadores atualizados para empresa ${empresaId}:`,
      updates
    );
  });

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  NOVA FUNÇÃO 2 — recalcularContadores
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
//  O "PORQUÊ":
//  Quando esta função for deployada pela primeira vez, o documento
//  "contadores/{empresaId}" não existe ainda. Precisamos populá-lo
//  uma única vez lendo todos os itens em produção.
//  Também serve de "reset" se o documento ficar fora de sincronia
//  por algum motivo (bug, manutenção manual no banco, etc.).
//
//  Como usar:
//  Esta função é chamada uma única vez pelo admin logo após o deploy.
//  Depois disso, a atualizarContadoresDashboard mantém tudo em dia
//  automaticamente. Não há necessidade de chamar esta função
//  rotineiramente.

export const recalcularContadores = functions
  .region("southamerica-east1")
  .https.onCall(async (data: any, context: functions.https.CallableContext) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "A função precisa ser chamada por um usuário autenticado."
      );
    }

    const { empresaId } = data;
    if (!empresaId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "O campo 'empresaId' é obrigatório."
      );
    }

    functions.logger.info(`Recalculando contadores para empresa: ${empresaId}`);

    // Lê todos os itens em produção — única vez, para inicializar
    const snap = await admin.firestore()
      .collection("itens_os")
      .where("empresaId", "==", empresaId)
      .where("statusAtual", "==", "emProducao")
      .get();

    // Conta do zero
    const contadores: Record<string, number> = {};
    for (const doc of snap.docs) {
      const item = doc.data();
      for (const chave of obterChavesContador(item.status, item.tipoAgente)) {
        contadores[chave] = (contadores[chave] || 0) + 1;
      }
    }

    // Sobrescreve o documento inteiro com os valores corretos
    await admin.firestore()
      .collection("contadores")
      .doc(empresaId)
      .set(contadores);

    functions.logger.info(
      `Contadores recalculados: ${snap.size} itens processados.`,
      contadores
    );

    return {
      message: `Contadores recalculados com sucesso. ${snap.size} itens processados.`,
      contadores,
    };
  });