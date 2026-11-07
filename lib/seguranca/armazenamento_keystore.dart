import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:prep_manager/seguranca/armazenamento_seguro.dart';

/// Guarda os segredos no cofre do Android (Keystore).
/// Os valores ficam criptografados com uma chave que nunca sai do celular.
class ArmazenamentoKeystore implements ArmazenamentoSeguro {
  final FlutterSecureStorage _st = const FlutterSecureStorage();

  @override
  Future<String?> ler(String chave) => _st.read(key: chave);

  @override
  Future<void> gravar(String chave, String valor) =>
      _st.write(key: chave, value: valor);

  @override
  Future<void> apagar(String chave) => _st.delete(key: chave);
}
