// Salve como: lib/models/cracha.dart

// O "PORQUÊ": Controla se o crachá físico (ex: "P-001") está na
// caixa de crachás livres ou se está em campo com um extintor.
enum StatusCracha {
  disponivel, // Pronto para ser "casado" com um novo item
  emUso, // Atualmente "casado" com um ItemOS na produção
}

class Cracha {
  final String id; // O ID do documento no Firestore (ex: DOC-abc)

  // --- O "RG" DO CRACHÁ FÍSICO ---
  final String idCracha; // O ID legível (ex: "P-001", "P-002", "TAG-100")
  final String empresaId; // Para multi-tenancy

  // --- O CONTROLE (A "CHAVE DE HOTEL") ---
  final StatusCracha status;
  final String?
  itemOsIdAtual; // Opcional: Se estiver "emUso", qual ItemOS está com ele?
  final String?
  osIdAtual; // Opcional: Facilita saber a qual OS ele pertence

  Cracha({
    required this.id,
    required this.idCracha,
    required this.empresaId,
    required this.status,
    this.itemOsIdAtual,
    this.osIdAtual,
  });

  // "Tradutor" para salvar no Firestore
  Map<String, dynamic> toJson() {
    return {
      'idCracha': idCracha,
      'empresaId': empresaId,
      'status': status.name, // Salva o enum como texto
      'itemOsIdAtual': itemOsIdAtual,
      'osIdAtual': osIdAtual,
    };
  }

  // "Tradutor" para ler do Firestore
  factory Cracha.fromJson(Map<String, dynamic> json, String id) {
    return Cracha(
      id: id,
      idCracha: json['idCracha'] ?? '',
      empresaId: json['empresaId'] ?? '',
      status: StatusCracha.values.byName(json['status'] ?? 'disponivel'),
      itemOsIdAtual: json['itemOsIdAtual'],
      osIdAtual: json['osIdAtual'],
    );
  }
}