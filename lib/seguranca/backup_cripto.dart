import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:prep_manager/seguranca/base32.dart';
import 'package:prep_manager/seguranca/kdf.dart';

/// Erro mostrado ao usuário (senha errada, backup danificado, etc.).
class BackupException implements Exception {
  final String mensagem;
  const BackupException(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Resultado de proteger um backup.
class BackupCifrado {
  /// O texto protegido (é isso que o usuário copia e guarda).
  final String texto;

  /// Código de recuperação (só aparece uma vez). Null se não foi pedido.
  final String? codigoRecuperacao;

  const BackupCifrado(this.texto, this.codigoRecuperacao);
}

/// Backup criptografado com AES-256-GCM.
///
/// Como funciona:
/// - Os dados são cifrados com uma chave aleatória (a "chave dos dados").
/// - Essa chave é guardada dentro do backup, trancada de duas formas:
///   pela SENHA (via PBKDF2) e, se pedido, pelo CÓDIGO DE RECUPERAÇÃO.
/// - Qualquer um dos dois abre o backup. Sem nenhum dos dois, não há como abrir.
/// - O GCM também detecta qualquer alteração no texto (senha errada ou backup adulterado).
class BackupProtegido {
  static const String formato = 'prep_manager_backup';
  static const int versao = 2;
  static const int iteracoesPadrao = 300000;
  static const int tamanhoMinimoSenha = 8;

  static const int _iteracoesMinimas = 1000;
  static const int _iteracoesMaximas = 5000000;
  static const int _tamanhoCodigo = 20; // 160 bits (32 caracteres)

  static final List<int> _aad = utf8.encode('$formato:v$versao');
  static final List<int> _saltCodigo = utf8.encode('$formato:recuperacao');
  static final List<int> _infoCodigo = utf8.encode('chave-de-recuperacao');

  static final AesGcm _aes = AesGcm.with256bits();

  /// Devolve uma mensagem se a senha for fraca demais, ou null se estiver ok.
  static String? validarSenha(String senha) {
    if (senha.length < tamanhoMinimoSenha) {
      return 'Use pelo menos $tamanhoMinimoSenha caracteres.';
    }
    if (senha.split('').toSet().length < 3) {
      return 'Essa senha é fácil demais. Misture mais caracteres.';
    }
    return null;
  }

  /// O texto parece um backup protegido?
  static bool ehProtegido(String texto) {
    try {
      final mapa = jsonDecode(texto);
      return mapa is Map && mapa['formato'] == formato;
    } catch (_) {
      return false;
    }
  }

  /// O backup protegido tem código de recuperação?
  static bool temCodigoRecuperacao(String texto) {
    try {
      final mapa = jsonDecode(texto);
      return mapa is Map && mapa['recuperacao'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Protege [textoJson] com a [senha] (e com um código de recuperação, se pedido).
  static Future<BackupCifrado> proteger(
    String textoJson,
    String senha, {
    bool gerarCodigoRecuperacao = true,
    int iteracoes = iteracoesPadrao,
    bool isolado = true,
    Random? random,
  }) async {
    final erro = validarSenha(senha);
    if (erro != null) throw BackupException(erro);

    final r = random ?? Random.secure();
    List<int> aleatorio(int n) => List<int>.generate(n, (_) => r.nextInt(256));

    final chaveDados = aleatorio(32);
    final sal = aleatorio(16);

    // 1) trancar a chave dos dados com a senha
    final chaveSenha = await derivarChave(senha, sal, iteracoes, isolado: isolado);
    final trancadaPelaSenha = await _cifrar(chaveDados, chaveSenha);

    // 2) (opcional) trancar também com o código de recuperação
    String? codigo;
    List<int>? trancadaPeloCodigo;
    if (gerarCodigoRecuperacao) {
      final bruto = aleatorio(_tamanhoCodigo);
      codigo = _formatarCodigo(Base32.codificar(bruto));
      trancadaPeloCodigo = await _cifrar(chaveDados, await _chaveDoCodigo(bruto));
    }

    // 3) cifrar os dados
    final dados = await _cifrar(utf8.encode(textoJson), chaveDados);

    final envelope = <String, dynamic>{
      'formato': formato,
      'versao': versao,
      'kdf': {'alg': 'PBKDF2-HMAC-SHA256', 'iteracoes': iteracoes},
      'senha': {'sal': base64Encode(sal), 'chave': base64Encode(trancadaPelaSenha)},
      if (trancadaPeloCodigo != null)
        'recuperacao': {'chave': base64Encode(trancadaPeloCodigo)},
      'dados': base64Encode(dados),
    };
    return BackupCifrado(jsonEncode(envelope), codigo);
  }

  /// Abre um backup protegido com a [senha] OU com o [codigoRecuperacao].
  /// Lança [BackupException] com uma mensagem clara se não conseguir.
  static Future<String> abrir(
    String texto, {
    String? senha,
    String? codigoRecuperacao,
    bool isolado = true,
  }) async {
    final Map envelope;
    try {
      final decodificado = jsonDecode(texto);
      if (decodificado is! Map || decodificado['formato'] != formato) {
        throw const FormatException();
      }
      envelope = decodificado;
    } catch (_) {
      throw const BackupException('Este texto não é um backup protegido válido.');
    }
    if (envelope['versao'] != versao) {
      throw const BackupException(
          'Este backup foi feito por uma versão incompatível do app.');
    }

    try {
      final List<int> chaveDados;

      if (senha != null && senha.isNotEmpty) {
        final iteracoes = (envelope['kdf']?['iteracoes'] as num?)?.toInt() ?? 0;
        if (iteracoes < _iteracoesMinimas || iteracoes > _iteracoesMaximas) {
          throw const BackupException('O backup está danificado.');
        }
        final sal = base64Decode(envelope['senha']['sal'] as String);
        final chaveSenha = await derivarChave(senha, sal, iteracoes, isolado: isolado);
        try {
          chaveDados = await _decifrar(
            base64Decode(envelope['senha']['chave'] as String),
            chaveSenha,
          );
        } on SecretBoxAuthenticationError {
          // A pessoa pode ter digitado o CÓDIGO DE RECUPERAÇÃO no campo da
          // senha. Se o texto tem cara de código, tenta abrir com ele.
          final trancada = envelope['recuperacao'];
          if (trancada == null || !pareceCodigo(senha)) rethrow;
          return utf8.decode(await _decifrar(
            base64Decode(envelope['dados'] as String),
            await _abrirComCodigo(
              base64Decode(trancada['chave'] as String),
              senha,
            ),
          ));
        }
      } else if (codigoRecuperacao != null && codigoRecuperacao.trim().isNotEmpty) {
        final trancada = envelope['recuperacao'];
        if (trancada == null) {
          throw const BackupException(
              'Este backup não foi feito com código de recuperação.');
        }
        chaveDados = await _abrirComCodigo(
          base64Decode(trancada['chave'] as String),
          codigoRecuperacao,
        );
      } else {
        throw const BackupException('Informe a senha do backup.');
      }

      final claro = await _decifrar(
        base64Decode(envelope['dados'] as String),
        chaveDados,
      );
      return utf8.decode(claro);
    } on BackupException {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw BackupException(
        (senha != null && senha.isNotEmpty)
            ? 'Senha incorreta, ou o backup foi alterado.'
            : 'Código de recuperação incorreto, ou o backup foi alterado.',
      );
    } catch (_) {
      throw const BackupException('O backup está danificado ou incompleto.');
    }
  }

  // ------------------------------------------------- código de recuperação

  static const String _alfabetoCodigo = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// No máximo 2^6 = 64 tentativas para os "1" ambíguos (I ou L).
  static const int _maximoAmbiguos = 6;

  /// Possíveis leituras do código digitado, corrigindo as trocas comuns de
  /// quem anota no papel. O código só usa A-Z e 2-7, então:
  /// 0 -> O, 8 -> B e 1 -> I ou L (testa as duas).
  /// Lança [BackupException] se houver caracteres que não podem ser do código.
  static List<String> leiturasDoCodigo(String digitado) {
    final limpo = digitado
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-=_.]'), '')
        .replaceAll('0', 'O')
        .replaceAll('8', 'B');

    final invalidos = limpo
        .split('')
        .where((c) => c != '1' && !_alfabetoCodigo.contains(c))
        .toSet();
    if (invalidos.isNotEmpty) {
      throw BackupException(
        'O código de recuperação tem caracteres que não fazem parte dele '
        '(${invalidos.join(' ')}). Ele usa só letras de A a Z e números de 2 a 7.',
      );
    }
    // 20 bytes = 32 caracteres
    if (limpo.length != 32) {
      throw BackupException(
        'O código de recuperação tem 32 caracteres (8 grupos de 4), '
        'mas foram digitados ${limpo.length}. Confira se faltou ou sobrou algum.',
      );
    }

    final ambiguos = '1'.allMatches(limpo).length;
    if (ambiguos == 0) return [limpo];
    if (ambiguos > _maximoAmbiguos) {
      throw const BackupException(
        'O código de recuperação não usa o número 1. Troque cada "1" pela '
        'letra I ou L, conforme anotado.',
      );
    }

    var leituras = [''];
    for (final c in limpo.split('')) {
      final opcoes = c == '1' ? const ['I', 'L'] : [c];
      leituras = [
        for (final l in leituras)
          for (final o in opcoes) l + o,
      ];
    }
    return leituras;
  }

  /// O texto tem o formato de um código de recuperação (32 caracteres do
  /// código, com ou sem hífens)?
  static bool pareceCodigo(String texto) {
    try {
      leiturasDoCodigo(texto);
      return true;
    } on BackupException {
      return false;
    }
  }

  /// Destranca a chave dos dados com o código de recuperação, aceitando as
  /// trocas comuns de caracteres (veja [leiturasDoCodigo]).
  static Future<List<int>> _abrirComCodigo(
      List<int> trancada, String digitado) async {
    for (final leitura in leiturasDoCodigo(digitado)) {
      final bruto = Base32.decodificar(leitura);
      if (bruto.length != _tamanhoCodigo) continue;
      try {
        return await _decifrar(trancada, await _chaveDoCodigo(bruto));
      } on SecretBoxAuthenticationError {
        // tenta a próxima leitura
      }
    }
    throw const BackupException(
      'Código de recuperação incorreto. Confira cada grupo de 4 caracteres '
      '(o código não usa 0, 1, 8 nem 9).',
    );
  }

  // ------------------------------------------------------------ detalhes

  static Future<List<int>> _cifrar(List<int> claro, List<int> chave) async {
    final caixa = await _aes.encrypt(claro, secretKey: SecretKey(chave), aad: _aad);
    return caixa.concatenation(); // nonce + texto cifrado + marca de autenticação
  }

  static Future<List<int>> _decifrar(List<int> concatenado, List<int> chave) {
    final caixa = SecretBox.fromConcatenation(
      concatenado,
      nonceLength: 12,
      macLength: 16,
    );
    return _aes.decrypt(caixa, secretKey: SecretKey(chave), aad: _aad);
  }

  static Future<List<int>> _chaveDoCodigo(List<int> bruto) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final chave = await hkdf.deriveKey(
      secretKey: SecretKey(bruto),
      nonce: _saltCodigo,
      info: _infoCodigo,
    );
    return chave.extractBytes();
  }

  /// "ABCDEFGH..." -> "ABCD-EFGH-..." (mais fácil de anotar e ler)
  static String _formatarCodigo(String base32) {
    final grupos = <String>[];
    for (var i = 0; i < base32.length; i += 4) {
      grupos.add(base32.substring(i, min(i + 4, base32.length)));
    }
    return grupos.join('-');
  }
}
