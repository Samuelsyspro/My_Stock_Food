import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prep_manager/services/backup_service.dart';
import 'package:prep_manager/services/item_service.dart';
import 'package:prep_manager/services/notification_service.dart';

/// Ajustes: avisos de validade, backup, restauração e manutenção dos dados.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
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
          _Opcao(
            icone: Icons.copy_all,
            cor: Colors.blue,
            titulo: 'Copiar backup',
            descricao:
                'Copia todos os seus dados em texto. Cole em um lugar seguro '
                '(Notas, e-mail, WhatsApp para você mesmo...).',
            onTap: () => _copiarBackup(context),
          ),
          _Opcao(
            icone: Icons.restore,
            cor: Colors.green,
            titulo: 'Restaurar backup',
            descricao:
                'Cole o texto de um backup. Nada é apagado: itens iguais são '
                'atualizados e os novos são adicionados.',
            onTap: () => _restaurarBackup(context),
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
        ],
      ),
    );
  }

  Future<void> _alternarAvisos(bool valor) async {
    final resultado = await NotificationService.instance.definirAtivado(valor);
    if (!mounted) return;
    setState(() {});
    if (valor && !resultado) {
      _mensagem(
        context,
        'Permissão negada. Ative as notificações do app nas configurações do celular.',
      );
    }
  }

  void _mensagem(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _copiarBackup(BuildContext context) async {
    final texto = BackupService().exportar();
    await Clipboard.setData(ClipboardData(text: texto));
    if (context.mounted) {
      _mensagem(context, 'Backup copiado! Cole em um lugar seguro.');
    }
  }

  Future<void> _restaurarBackup(BuildContext context) async {
    final controller = TextEditingController();

    final texto = await showDialog<String>(
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
                hintText: 'Cole aqui o texto do backup',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.paste),
                label: const Text('Colar'),
                onPressed: () async {
                  final dados = await Clipboard.getData(Clipboard.kTextPlain);
                  controller.text = dados?.text ?? '';
                },
              ),
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
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    // (sem dispose aqui: o diálogo ainda está animando a saída)

    if (texto == null || texto.trim().isEmpty) return;

    try {
      final r = await BackupService().importar(texto);
      if (!context.mounted) return;
      _mensagem(
        context,
        'Backup restaurado: ${r.itensAdicionados} item(ns) novo(s), '
        '${r.itensAtualizados} atualizado(s), '
        '${r.comprasAdicionadas} na lista de compras'
        '${r.ignorados > 0 ? ', ${r.ignorados} ignorado(s)' : ''}.',
      );
    } on FormatException catch (e) {
      if (context.mounted) _mensagem(context, e.message);
    } catch (e) {
      if (context.mounted) _mensagem(context, 'Erro ao restaurar: $e');
    }
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
    if (!context.mounted) return;
    _mensagem(
      context,
      removidos == 0
          ? 'Nenhum item duplicado encontrado.'
          : '$removidos item(ns) duplicado(s) unido(s).',
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
    return Card(
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
