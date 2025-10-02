import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

admin.initializeApp();

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

// ================== NOVA FUNÇÃO ==================
// O "PORQUÊ": Esta é a nova função que o botão "Recusar" irá chamar.
// Ela realiza uma exclusão completa e segura do usuário, removendo-o
// tanto do sistema de autenticação quanto do banco de dados Firestore.
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
      // Passo 1: Deleta o usuário do Firebase Authentication.
      await admin.auth().deleteUser(uid);
      functions.logger.info(`Usuário ${uid} deletado do Authentication.`);

      // Passo 2: Deleta o perfil do usuário do Firestore.
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
```

Depois de atualizar o arquivo, não se esqueça de fazer o deploy:

```bash
firebase deploy --only functions

