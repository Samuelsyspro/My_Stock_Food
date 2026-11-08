import 'package:flutter/material.dart';
import 'package:prep_manager/widgets/aviso.dart';
import 'package:flutter/services.dart';
import 'package:prep_manager/seguranca/seguranca.dart';
import 'package:prep_manager/seguranca/totp.dart';
import 'package:prep_manager/seguranca/ui/teclado_pin.dart';
import 'package:prep_manager/utils/app_info.dart';
import 'package:prep_manager/widgets/fundo_scaffold.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:prep_manager/widgets/superficie.dart';

/// Ativa a verificação em duas etapas (apps como Google Authenticator,
/// Microsoft Authenticator, Aegis, 2FAS...). Devolve true ao fechar se ativou.
class Config2faScreen extends StatefulWidget {
  const Config2faScreen({super.key});

  @override
  State<Config2faScreen> createState() => _Config2faScreenState();
}

class _Config2faScreenState extends State<Config2faScreen> {
  // O segredo só é salvo depois que o usuário prova que o app autenticador funciona.
  final String _segredo = Totp.gerarSegredo();
  String? _erro;
  bool _verificando = false;

  String get _segredoFormatado {
    final grupos = <String>[];
    for (var i = 0; i < _segredo.length; i += 4) {
      grupos.add(_segredo.substring(i, i + 4));
    }
    return grupos.join(' ');
  }

  Future<void> _confirmar(String codigo) async {
    setState(() {
      _verificando = true;
      _erro = null;
    });
    final ok =
        await Seguranca.instancia.trava.ativarDoisFatores(_segredo, codigo);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _verificando = false;
      _erro =
          'Código incorreto. Confira se o horário do celular está automático e tente de novo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final uri = Totp.uri(
      segredo: _segredo,
      conta: 'Este celular',
      emissor: kNomeDoApp,
    );

    return FundoScaffold(
      appBar: AppBar(title: const Text('Verificação em duas etapas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Superficie(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Instale um app autenticador',
                      style: tema.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Por exemplo: Google Authenticator, Microsoft Authenticator, Aegis ou 2FAS.',
                  ),
                  const SizedBox(height: 16),
                  Text('2. Adicione uma conta',
                      style: tema.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Escaneie o QR Code (se estiver usando outro aparelho) ou digite a chave abaixo no autenticador.',
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      child: QrImageView(data: uri, size: 190),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _segredoFormatado,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _segredo));
                        if (!context.mounted) return;
                        mostrarAviso(context, 'Chave copiada.',
                            tipo: TipoAviso.sucesso);
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar a chave'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tipo da chave: baseada em tempo (TOTP), 6 dígitos, a cada 30 segundos.',
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Superficie(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('3. Confirme com o código',
                      style: tema.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Digite o código de 6 dígitos que o autenticador mostra agora.',
                    textAlign: TextAlign.center,
                  ),
                  if (_erro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _erro!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tema.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  EntradaNumerica(
                    minimo: 6,
                    maximo: 6,
                    habilitada: !_verificando,
                    onConcluir: _confirmar,
                  ),
                ],
              ),
            ),
          ),
          Superficie(
            margin: const EdgeInsets.symmetric(vertical: 4),
            tom: tema.colorScheme.tertiary,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Importante: o 2FA fica só neste celular e não vai junto com o backup. '
                'Se você trocar de celular, ative de novo. Se perder o autenticador, '
                'ainda dá para redefinir o PIN pelo bloqueio de tela do celular.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
