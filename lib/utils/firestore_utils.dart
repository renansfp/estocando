// lib/utils/firestore_utils.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Converte recursivamente todos os [Timestamp] de um documento Firestore
/// para [DateTime], incluindo mapas e listas aninhados.
///
/// Usado pelos repositórios para que nenhuma tela precise importar
/// `cloud_firestore` apenas para lidar com datas.
Map<String, dynamic> convertTimestamps(Map<String, dynamic> data) {
  return data.map((key, value) {
    if (value is Timestamp) return MapEntry(key, value.toDate());
    if (value is Map<String, dynamic>) {
      return MapEntry(key, convertTimestamps(value));
    }
    if (value is List) {
      return MapEntry(key, value.map((e) {
        if (e is Timestamp) return e.toDate();
        if (e is Map<String, dynamic>) return convertTimestamps(e);
        return e;
      }).toList());
    }
    return MapEntry(key, value);
  });
}
