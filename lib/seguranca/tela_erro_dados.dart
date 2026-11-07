import 'package:flutter/material.dart';
import 'package:prep_manager/seguranca/dados_seguros.dart';

/// Tela mostrada no lugar do app quando os dados salvos não podem ser lidos.
/// Nunca apaga nada sem o usuário confirmar.
class TelaErroDados extends StatefulWidget {
  final Object erro;

  /// Tenta abrir de novo; com [recuperar] = true, aceita perder o final danificado do arquivo.
  final Future<void> Function({required bool recuperar}) onTentar;

  /// Apaga os dados e a chave, para recomeçar do zero.
  final Future<void> Function() onApagar;

  const TelaErroDados({
    super.key,
    required this.erro,
    required this.onTentar,
    required this.onApagar,
  });

  @override
  State<TelaErroDados> createState() => _TelaErroDadosState();
}

class _TelaErroDadosState extends State<TelaErroDados> {
  bool _ocupado = false;

  Future<void> _executar(Future<void> Function() acao) async {
    setState(() => _ocupado = true);
    try {
      await acao();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _confirmarApagar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar os dados e recomeçar?'),
        content: const Text(
          'Todos os dados salvos neste aparelho serão apagados e não poderão '
          'ser recuperados. Depois você poderá restaurar um backup, se tiver um.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (ok == true) await _executar(widget.onApagar);
  }

  @override
  Widget build(BuildContext context) {
    final chavePerdida = widget.erro is ChaveDadosPerdida;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 56, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Não foi possível abrir os dados',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    chavePerdida
                        ? 'A chave de segurança dos dados não foi encontrada neste aparelho. '
                            'Isso acontece, por exemplo, quando o app é restaurado em outro celular. '
                            'Os dados antigos não podem mais ser lidos. '
                            'Se você tem um backup, restaure-o depois de recomeçar.'
                        : 'Os arquivos de dados parecem danificados, talvez por o celular ter '
                            'desligado durante uma gravação. Você pode tentar recuperar '
                            '(as últimas alterações podem ser perdidas) ou recomeçar e restaurar um backup.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_ocupado)
                    const CircularProgressIndicator()
                  else ...[
                    if (!chavePerdida)
                      FilledButton(
                        onPressed: () =>
                            _executar(() => widget.onTentar(recuperar: true)),
                        child: const Text('Tentar recuperar'),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _executar(() => widget.onTentar(recuperar: false)),
                      child: const Text('Tentar abrir de novo'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _confirmarApagar,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Apagar os dados e recomeçar'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
