// Conteúdo para o arquivo lib/utils/validadores.dart

class CPFValidator {
  static bool isValid(String? cpf) {
    if (cpf == null || cpf.isEmpty) return false;
    final numbers = cpf.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.length != 11) return false;
    if (RegExp(r'^(\d)\1*$').hasMatch(numbers)) return false;

    final digits = numbers.split('').map(int.parse).toList();
    var calcDv1 = 0;
    for (var i in List.generate(9, (i) => 10 - i)) {
      calcDv1 += digits[10 - i] * i;
    }
    final dv1 = (calcDv1 % 11) < 2 ? 0 : 11 - (calcDv1 % 11);
    if (digits[9] != dv1) return false;

    var calcDv2 = 0;
    for (var i in List.generate(10, (i) => 11 - i)) {
      calcDv2 += digits[11 - i] * i;
    }
    final dv2 = (calcDv2 % 11) < 2 ? 0 : 11 - (calcDv2 % 11);
    if (digits[10] != dv2) return false;

    return true;
  }
}

class CNPJValidator {
  static bool isValid(String? cnpj) {
    if (cnpj == null || cnpj.isEmpty) return false;
    final numbers = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.length != 14) return false;
    if (RegExp(r'^(\d)\1*$').hasMatch(numbers)) return false;

    final digits = numbers.split('').map(int.parse).toList();
    var calcDv1 = 0;
    final List<int> weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    for (int i = 0; i < 12; i++) {
      calcDv1 += digits[i] * weights1[i];
    }
    final dv1 = (calcDv1 % 11) < 2 ? 0 : 11 - (calcDv1 % 11);
    if (digits[12] != dv1) return false;

    var calcDv2 = 0;
    final List<int> weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    for (int i = 0; i < 13; i++) {
      calcDv2 += digits[i] * weights2[i];
    }
    final dv2 = (calcDv2 % 11) < 2 ? 0 : 11 - (calcDv2 % 11);
    if (digits[13] != dv2) return false;

    return true;
  }
}