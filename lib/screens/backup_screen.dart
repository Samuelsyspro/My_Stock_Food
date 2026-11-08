import 'package:flutter/material.dart';
import 'package:prep_manager/widgets/aviso.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prep_manager/seguranca/backup_cripto.dart';
import 'package:prep_manager/seguranca/seguranca.dart';
import 'package:prep_manager/seguranca/ui/config_2fa_screen.dart';
import 'package:prep_manager/seguranca/ui/confirmar_identidade.dart';
import 'package:prep_manager/seguranca/ui/fluxo_criar_pin.dart';
import 'package:prep_manager/services/backup_arquivo.dart';
import 'package:prep_manager/services/backup_service.dart';
import 'package:prep_manager/services/fundo_service.dart';
import 'package:prep_manager/services/item_service.dart';
import 'package:prep_manager/services/notification_service.dart';
import 'package:prep_manager/widgets/fundo_scaffold.dart';
import 'package:prep_manager/widgets/superficie.dart';

class _OpcoesBackup {
  final String senha;
  final bool gerarCodigo;
  const _OpcoesBackup(this.senha, this.gerarCodigo);
}

class _Credencial {
  final String? senha;
  final String? codigo;
  const _Credencial({this.senha, this.codigo});
}

/// Ajustes: segurança, avisos, aparência e dados (backup).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _trava = Seguranca.instancia.trava;
  final _bio = Seguranca.instancia.biometria;

  bool _biometriaDisponivel = false;
  bool _biometriaAtiva = false;
  bool _tem2fa = false;
  int _segundos = 10;
  String? _versao;

  @override
  void initState() {
    super.initState();
    _carregarSeguranca();
    _carregarVersao();
  }

  Future<void> _carregarVersao() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _versao = '${info.version}.${info.buildNumber}');
    } catch (_) {}
  }

  Future<void> _carregarSeguranca() async {
    final disponivel = await _bio.biometriaDisponivel;
    final ativa = await _trava.biometriaAtiva;
    final doisFatores = await _trava.doisFatoresAtivo;
    final segundos = await _trava.segundosParaTravar();
    if (!mounted) return;
    setState(() {
      _biometriaDisponivel = disponivel;
      _biometriaAtiva = ativa;
      _tem2fa = doisFatores;
      _segundos = segundos;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FundoScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.settings,
              color: Color(0xFF07A35D),
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              'Ajustes',
              style: GoogleFonts.rochester(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Secao('Segurança'),
          Superficie(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.pin, size: 36, color: Colors.indigo),
                  title: const Text(
                    'Alterar PIN',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Confirme com o PIN atual ou com o código do autenticador (2FA).',
                  ),
                  onTap: _alterarPin,
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.fingerprint, size: 36, color: Colors.teal),
                  title: const Text(
                    'Abrir com digital ou rosto',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_biometriaDisponivel
                      ? 'O PIN continua funcionando sempre.'
                      : 'Cadastre uma digital ou um rosto nas configurações do celular.'),
                  value: _biometriaAtiva,
                  onChanged: _biometriaDisponivel ? _alternarBiometria : null,
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.all(16),
                  secondary: const Icon(Icons.shield_outlined, size: 36, color: Colors.deepPurple),
                  title: const Text(
                    'Verificação em duas etapas (2FA)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_tem2fa
                      ? 'Ativa. O código do autenticador também protege o backup.'
                      : 'Use um app como o Google Authenticator para recuperar o PIN e proteger o backup.'),
                  value: _tem2fa,
                  onChanged: _alternar2fa,
                ),
                ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.timer_outlined, size: 36, color: Colors.orange),
                  title: const Text(
                    'Travar o app depois de',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Quando o app fica em segundo plano: ${_rotuloTempo(_segundos)}.',
                  ),
                  onTap: _escolherTempo,
                ),
              ],
            ),
          ),
          const _Secao('Avisos e aparência'),
          Superficie(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.all(16),
                  secondary: const Icon(
                    Icons.notifications_active,
                    size: 36,
                    color: Colors.amber,
                  ),
                  title: const Text(
                    'Avisos de validade',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Uma notificação às 9h, 7 dias antes e no dia em que '
                    'um item vence.',
                  ),
                  value: NotificationService.instance.ativado,
                  onChanged: _alternarAvisos,
                ),
                ListTile(
                  leading: const Icon(Icons.send),
                  title: const Text('Enviar aviso de teste'),
                  subtitle: const Text(
                    'Se nada aparecer, confira se as notificações do app '
                    'estão permitidas no celular.',
                  ),
                  onTap: () => NotificationService.instance.enviarTeste(),
                ),
              ],
            ),
          ),
          Superficie(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.all(16),
              secondary: const Icon(Icons.wallpaper, size: 36, color: Colors.teal),
              title: const Text(
                'Imagem de fundo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Uma imagem diferente a cada vez que o app é aberto.',
              ),
              value: FundoService.ativo,
              onChanged: (valor) async {
                await FundoService.definirAtivo(valor);
                if (mounted) setState(() {});
              },
            ),
          ),
          const _Secao('Dados'),
          _Opcao(
            icone: Icons.lock_outline,
            cor: Colors.blue,
            titulo: 'Salvar backup protegido',
            descricao:
                'Cria um arquivo criptografado com uma senha só do backup. '
                'Salve no Google Drive, iCloud Drive, Downloads ou onde preferir.',
            onTap: _gerarBackup,
          ),
          _Opcao(
            icone: Icons.restore,
            cor: Colors.green,
            titulo: 'Restaurar backup',
            descricao:
                'Abra o arquivo de um backup (ou cole o texto). Nada é apagado: '
                'itens iguais são atualizados e os novos são adicionados.',
            onTap: _restaurarBackup,
          ),
          _Opcao(
            icone: Icons.merge_type,
            cor: Colors.orange,
            titulo: 'Unir itens duplicados',
            descricao:
                'Junta itens com o mesmo nome, categoria e unidade, somando as '
                'quantidades e mantendo a validade mais próxima.',
            onTap: () => _unirDuplicados(context),
          ),
          const SizedBox(height: 24),
          _Rodape(versao: _versao),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- util

  /// Avisos desta tela: sempre em popup (veja widgets/aviso.dart).
  Future<void> _mensagem(String texto, {TipoAviso tipo = TipoAviso.info}) =>
      mostrarAviso(context, texto, tipo: tipo);

  void _mostrarProgresso(String texto) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(texto)),
            ],
          ),
        ),
      ),
    );
  }

  void _fecharProgresso() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  String _rotuloTempo(int segundos) {
    if (segundos <= 0) return 'imediatamente';
    if (segundos < 60) return '$segundos segundos';
    if (segundos == 60) return '1 minuto';
    return '${segundos ~/ 60} minutos';
  }

  // ----------------------------------------------------------- segurança

  Future<void> _alterarPin() async {
    final ok = await confirmarIdentidade(
      context,
      motivo: 'Para alterar o PIN, confirme com o PIN atual ou com o código do autenticador.',
      permitirEscolha: true,
    );
    if (!ok || !mounted) return;

    final alterado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NovoPinScreen()),
    );
    if (alterado == true && mounted) _mensagem('PIN alterado.', tipo: TipoAviso.sucesso);
  }

  Future<void> _alternarBiometria(bool ativar) async {
    if (ativar) {
      final ok = await _bio.autenticarBiometria('Confirme para ativar a biometria');
      if (!ok) return;
    }
    await _trava.definirBiometria(ativar);
    await _carregarSeguranca();
  }

  Future<void> _alternar2fa(bool ativar) async {
    if (ativar) {
      final ativado = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const Config2faScreen()),
      );
      if (ativado == true && mounted) {
        _mensagem('Verificação em duas etapas ativada.', tipo: TipoAviso.sucesso);
      }
    } else {
      final ok = await confirmarIdentidade(
        context,
        motivo: 'Para desativar o 2FA, informe o código do autenticador.',
      );
      if (!ok) return;
      await _trava.desativarDoisFatores();
      if (mounted) _mensagem('Verificação em duas etapas desativada.', tipo: TipoAviso.sucesso);
    }
    await _carregarSeguranca();
  }

  Future<void> _escolherTempo() async {
    const opcoes = [0, 10, 30, 60, 300];
    final escolhido = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Travar o app depois de'),
        children: [
          for (final s in opcoes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, s),
              child: Text(
                _rotuloTempo(s)[0].toUpperCase() + _rotuloTempo(s).substring(1),
                style: TextStyle(
                  fontWeight: s == _segundos ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
    if (escolhido == null) return;
    await _trava.definirSegundosParaTravar(escolhido);
    await _carregarSeguranca();
  }

  // -------------------------------------------------------------- avisos

  Future<void> _alternarAvisos(bool valor) async {
    final resultado = await NotificationService.instance.definirAtivado(valor);
    if (!mounted) return;
    setState(() {});
    if (valor && !resultado) {
      _mensagem(
        'Permissão negada. Ative as notificações do app nas configurações do celular.',
        tipo: TipoAviso.erro,
      );
    }
  }

  // -------------------------------------------------------------- backup

  Future<void> _gerarBackup() async {
    final ok = await confirmarIdentidade(
      context,
      motivo: _tem2fa
          ? 'Para gerar o backup, informe o código do autenticador.'
          : 'Para gerar o backup, digite o seu PIN.',
    );
    if (!ok || !mounted) return;

    final opcoes = await _pedirSenhaDoBackup();
    if (opcoes == null || !mounted) return;

    _mostrarProgresso('Protegendo o backup...');
    final BackupCifrado backup;
    try {
      backup = await BackupService().exportarProtegido(
        opcoes.senha,
        gerarCodigoRecuperacao: opcoes.gerarCodigo,
      );
    } on BackupException catch (e) {
      _fecharProgresso();
      if (mounted) _mensagem(e.mensagem, tipo: TipoAviso.erro);
      return;
    } catch (e) {
      _fecharProgresso();
      if (mounted) _mensagem('Não foi possível gerar o backup: $e', tipo: TipoAviso.erro);
      return;
    }
    _fecharProgresso();

    final guardado = await _guardarBackup(backup.texto);
    if (!guardado || !mounted) return;

    // O código só tem valor se o backup foi guardado: por isso vem depois.
    if (backup.codigoRecuperacao != null) {
      await _mostrarCodigoRecuperacao(backup.codigoRecuperacao!);
    }
  }

  /// Salva o backup em arquivo (ou copia como texto). Se a pessoa cancelar
  /// a tela do sistema, pergunta de novo, para o backup não se perder sem querer.
  /// Devolve true se o backup foi guardado de alguma forma.
  Future<bool> _guardarBackup(String texto) async {
    while (true) {
      if (!mounted) return false;
      final escolha = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => SimpleDialog(
          title: const Text('Onde guardar o backup?'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'arquivo'),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.save_alt),
                title: Text('Salvar em arquivo (recomendado)'),
                subtitle: Text(
                  'Escolha a pasta: Google Drive, iCloud Drive, Downloads...',
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'texto'),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.copy),
                title: Text('Copiar como texto'),
                subtitle: Text('Para colar em Notas, e-mail ou WhatsApp.'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'descartar'),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.close),
                title: Text('Cancelar'),
                subtitle: Text('O backup gerado será descartado.'),
              ),
            ),
          ],
        ),
      );
      if (!mounted || escolha == null || escolha == 'descartar') return false;

      if (escolha == 'texto') {
        await Clipboard.setData(ClipboardData(text: texto));
        if (mounted) {
          await _mensagem('Backup protegido copiado. Cole em um lugar seguro.',
              tipo: TipoAviso.sucesso);
        }
        return true;
      }

      try {
        if (await BackupArquivo.salvar(texto)) {
          if (mounted) await _mensagem('Backup protegido salvo.', tipo: TipoAviso.sucesso);
          return true;
        }
        // Cancelou a tela do sistema: volta para a pergunta.
      } catch (e) {
        if (mounted) await _mensagem('Não foi possível salvar o arquivo: $e', tipo: TipoAviso.erro);
      }
    }
  }

  Future<_OpcoesBackup?> _pedirSenhaDoBackup() {
    final senhaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();
    var gerarCodigo = true;
    var ocultar = true;
    String? erro;

    return showDialog<_OpcoesBackup>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Senha do backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ATENÇÃO: esta senha NÃO tem recuperação. Se você '
                          'esquecê-la, ninguém consegue abrir este backup, nem '
                          'o app e nem o suporte. Anote em um lugar seguro.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: senhaCtrl,
                  obscureText: ocultar,
                  decoration: InputDecoration(
                    labelText: 'Senha do backup (mínimo 8 caracteres)',
                    suffixIcon: IconButton(
                      icon: Icon(ocultar ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setD(() => ocultar = !ocultar),
                    ),
                  ),
                ),
                TextField(
                  controller: confirmarCtrl,
                  obscureText: ocultar,
                  decoration: InputDecoration(
                    labelText: 'Repita a senha',
                    errorText: erro,
                  ),
                ),
                CheckboxListTile(
                  value: gerarCodigo,
                  onChanged: (v) => setD(() => gerarCodigo = v ?? true),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Gerar também um código de recuperação'),
                  subtitle: Text(gerarCodigo
                      ? 'Abre o backup se você esquecer a senha. Aparece uma única vez: anote.'
                      : 'Sem o código, esquecer a senha significa perder este backup.'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final problema = BackupProtegido.validarSenha(senhaCtrl.text);
                if (problema != null) {
                  setD(() => erro = problema);
                } else if (senhaCtrl.text != confirmarCtrl.text) {
                  setD(() => erro = 'As senhas são diferentes.');
                } else {
                  Navigator.pop(ctx, _OpcoesBackup(senhaCtrl.text, gerarCodigo));
                }
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarCodigoRecuperacao(String codigo) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Código de recuperação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anote este código agora, em papel ou em um gerenciador de senhas. '
              'Ele aparece UMA ÚNICA VEZ e não dá para consultar depois. '
              'Quem tiver o backup e este código consegue abri-lo.',
            ),
            const SizedBox(height: 16),
            Center(
              child: SelectableText(
                codigo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codigo));
              if (ctx.mounted) {
                mostrarAviso(ctx, 'Código copiado.', tipo: TipoAviso.sucesso);
              }
            },
            child: const Text('Copiar o código'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Já anotei'),
          ),
        ],
      ),
    );
  }

  Future<void> _restaurarBackup() async {
    final ok = await confirmarIdentidade(
      context,
      motivo: _tem2fa
          ? 'Para restaurar um backup, informe o código do autenticador.'
          : 'Para restaurar um backup, digite o seu PIN.',
    );
    if (!ok || !mounted) return;

    final texto = await _pedirTextoDoBackup();
    if (texto == null || texto.trim().isEmpty || !mounted) return;

    try {
      final ResultadoImportacao r;
      if (BackupProtegido.ehProtegido(texto)) {
        final credencial = await _pedirCredencial(
          temCodigo: BackupProtegido.temCodigoRecuperacao(texto),
        );
        if (credencial == null || !mounted) return;

        _mostrarProgresso('Abrindo o backup...');
        try {
          r = await BackupService().importarProtegido(
            texto,
            senha: credencial.senha,
            codigoRecuperacao: credencial.codigo,
          );
        } finally {
          _fecharProgresso();
        }
      } else {
        final seguir = await _confirmarBackupSemProtecao();
        if (!seguir || !mounted) return;
        r = await BackupService().importar(texto);
      }

      if (!mounted) return;
      _mensagem(
        'Backup restaurado: ${r.itensAdicionados} item(ns) novo(s), '
        '${r.itensAtualizados} atualizado(s), '
        '${r.comprasAdicionadas} na lista de compras'
        '${r.categoriasAdicionadas > 0 ? ', ${r.categoriasAdicionadas} categoria(s)' : ''}'
        '${r.ignorados > 0 ? ', ${r.ignorados} ignorado(s)' : ''}.',
        tipo: TipoAviso.sucesso,
      );
    } on BackupException catch (e) {
      if (mounted) _mensagem(e.mensagem, tipo: TipoAviso.erro);
    } on FormatException catch (e) {
      if (mounted) _mensagem(e.message, tipo: TipoAviso.erro);
    } catch (e) {
      if (mounted) _mensagem('Erro ao restaurar: $e', tipo: TipoAviso.erro);
    }
  }

  Future<String?> _pedirTextoDoBackup() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Abra o arquivo do backup ou cole o texto aqui',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Abrir arquivo'),
                  onPressed: () async {
                    String? erro;
                    try {
                      final texto = await BackupArquivo.abrir();
                      if (texto != null && ctx.mounted) Navigator.pop(ctx, texto);
                    } on BackupException catch (e) {
                      erro = e.mensagem;
                    } catch (e) {
                      erro = 'Não foi possível abrir o arquivo: $e';
                    }
                    if (erro != null && mounted) _mensagem(erro, tipo: TipoAviso.erro);
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.paste),
                  label: const Text('Colar'),
                  onPressed: () async {
                    final dados = await Clipboard.getData(Clipboard.kTextPlain);
                    controller.text = dados?.text ?? '';
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Future<_Credencial?> _pedirCredencial({required bool temCodigo}) {
    final senhaCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();
    var usarCodigo = false;
    var ocultar = true;

    return showDialog<_Credencial>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Backup protegido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!usarCodigo)
                TextField(
                  controller: senhaCtrl,
                  obscureText: ocultar,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Senha do backup',
                    suffixIcon: IconButton(
                      icon: Icon(ocultar ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setD(() => ocultar = !ocultar),
                    ),
                  ),
                )
              else
                TextField(
                  controller: codigoCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código de recuperação',
                    hintText: 'XXXX-XXXX-XXXX-...',
                  ),
                ),
              if (temCodigo)
                TextButton(
                  onPressed: () => setD(() => usarCodigo = !usarCodigo),
                  child: Text(usarCodigo
                      ? 'Usar a senha do backup'
                      : 'Esqueci a senha: usar o código de recuperação'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                usarCodigo
                    ? _Credencial(codigo: codigoCtrl.text)
                    : _Credencial(senha: senhaCtrl.text),
              ),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmarBackupSemProtecao() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup sem proteção'),
        content: const Text(
          'Este backup é de uma versão antiga e não tem senha: qualquer pessoa '
          'que tenha o texto consegue ler os seus dados. Restaurar mesmo assim? '
          'Depois, gere um backup protegido novo e apague o antigo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _unirDuplicados(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unir itens duplicados?'),
        content: const Text(
          'Itens com o mesmo nome, categoria e unidade serão juntados em um só, '
          'somando as quantidades. Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final removidos = await ItemService().unirDuplicados();
    if (!mounted) return;
    _mensagem(
      removidos == 0
          ? 'Nenhum item duplicado encontrado.'
          : '$removidos item(ns) duplicado(s) unido(s).',
      tipo: removidos == 0 ? TipoAviso.info : TipoAviso.sucesso,
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;

  const _Secao(this.titulo);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(
        titulo.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  const _Opcao({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Superficie(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icone, size: 36, color: cor),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(descricao),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Direitos autorais e versão do app (no fim dos Ajustes).
class _Rodape extends StatelessWidget {
  final String? versao;

  const _Rodape({required this.versao});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Superficie(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text(
              '© 2026 Samuel. Todos os direitos reservados.',
              style: TextStyle(fontSize: 12, color: cor),
              textAlign: TextAlign.center,
            ),
            if (versao != null) ...[
              const SizedBox(height: 4),
              Text(
                'Versão $versao',
                style: TextStyle(fontSize: 11, color: cor),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
