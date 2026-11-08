import 'package:flutter/material.dart';
import 'package:prep_manager/screens/backup_screen.dart';
import 'package:prep_manager/screens/dispensa_screen.dart';
import 'package:prep_manager/screens/shopping_list_screen.dart';
import 'package:prep_manager/widgets/fundo_scaffold.dart';
import 'package:prep_manager/widgets/vidro.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prep_manager/widgets/superficie.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    return FundoScaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.door_sliding_outlined,
              color: Color(0xFF07A35D),
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'Despensa Digital',
              style: GoogleFonts.rochester(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Ajustes',
              child: BotaoVidroRedondo(
                tamanho: 44,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BackupScreen()),
                ),
                child: const Icon(Icons.settings),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Superficie(
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Text(
                  'Sua despensa na palma da mão!',
                  style: GoogleFonts.rochester(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    // Você pode adicionar uma cor se quiser, ex: color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    context,
                    title: 'Despensa',
                    icon: Icons.kitchen,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DispensaScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Lista de Compras',
                    icon: Icons.shopping_cart,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ShoppingListScreen()),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Financeiro',
                    icon: Icons.monetization_on_rounded,
                    color: Colors.green,
                    onTap: () {
                      //adicionar a informação que a tela financeira ainda não foi implementada
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Em desenvolvimento'),
                          content: const Text(
                              'Logo voce tera o controle total da sua finança.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Vidro(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
