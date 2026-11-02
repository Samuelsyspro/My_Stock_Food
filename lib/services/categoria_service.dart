import 'package:hive/hive.dart';
import 'package:prep_manager/models/item.dart';
import 'package:prep_manager/utils/helpers.dart';

/// Categoria criada pelo usuário. O ícone é guardado pelo nome (ex.: "cesta"),
/// e a tela traduz esse nome para o desenho (veja CategoriasApp).
class CategoriaPersonalizada {
  final String nome;
  final String icone;
  final int cor; // valor da cor (0xFFRRGGBB)

  const CategoriaPersonalizada({
    required this.nome,
    required this.icone,
    required this.cor,
  });

  Map<String, dynamic> toMap() => {'nome': nome, 'icone': icone, 'cor': cor};

  factory CategoriaPersonalizada.fromMap(Map<String, dynamic> mapa) =>
      CategoriaPersonalizada(
        nome: mapa['nome'] as String,
        icone: (mapa['icone'] as String?) ?? CategoriaService.iconePadrao,
        cor: (mapa['cor'] as num?)?.toInt() ?? CategoriaService.paletaCores.first,
      );
}

/// Guarda e consulta as categorias (as padrão do app + as criadas pelo usuário).
/// As criadas ficam na caixa 'settings' do Hive.
class CategoriaService {
  /// Categorias que já vêm com o app (não podem ser removidas).
  static const List<String> padrao = [
    'Bebidas',
    'Alimentos',
    'Combustível',
    'Médico',
    'Higiene',
    'Ferramentas',
    'Outros',
  ];

  static const String iconePadrao = 'categoria';
  static const int tamanhoMaximoNome = 20;

  /// Cores usadas, em sequência, nas categorias novas.
  static const List<int> paletaCores = [
    0xFF00897B,
    0xFF5E35B1,
    0xFFC2185B,
    0xFF3949AB,
    0xFFAFB42B,
    0xFF00ACC1,
    0xFFF4511E,
    0xFF8E24AA,
  ];

  static const String _chave = 'categorias_personalizadas';

  Box get _config => Hive.box('settings');

  List<CategoriaPersonalizada> listar() {
    final bruto = _config.get(_chave, defaultValue: <dynamic>[]) as List;
    return [
      for (final m in bruto)
        CategoriaPersonalizada.fromMap(Map<String, dynamic>.from(m as Map)),
    ];
  }

  /// Nomes de todas as categorias: as padrão, depois as suas, e "Outros" por último.
  List<String> todosOsNomes() => [
        ...padrao.where((n) => n != 'Outros'),
        ...listar().map((c) => c.nome),
        'Outros',
      ];

  bool ehPadrao(String nome) =>
      padrao.any((p) => normalizar(p) == normalizar(nome));

  CategoriaPersonalizada? buscar(String nome) {
    for (final c in listar()) {
      if (normalizar(c.nome) == normalizar(nome)) return c;
    }
    return null;
  }

  bool existe(String nome) => ehPadrao(nome) || buscar(nome) != null;

  /// Cria uma categoria. Devolve uma mensagem de erro, ou null se deu certo.
  Future<String?> adicionar(String nome, String icone) async {
    final limpo = nome.trim();
    if (limpo.isEmpty) return 'Digite um nome para a categoria.';
    if (limpo.length > tamanhoMaximoNome) {
      return 'Use no máximo $tamanhoMaximoNome caracteres.';
    }
    if (existe(limpo)) return 'Já existe uma categoria com esse nome.';

    final atuais = listar();
    final nova = CategoriaPersonalizada(
      nome: limpo,
      icone: icone,
      cor: paletaCores[atuais.length % paletaCores.length],
    );
    await _salvar([...atuais, nova]);
    return null;
  }

  /// Remove uma categoria criada pelo usuário. Só é possível se ela estiver vazia.
  /// Devolve uma mensagem de erro, ou null se deu certo.
  Future<String?> remover(String nome) async {
    if (ehPadrao(nome)) return 'As categorias do app não podem ser removidas.';

    final alvo = buscar(nome);
    if (alvo == null) return 'Categoria não encontrada.';

    final emUso =
        Hive.box<Item>('items').values.where((i) => i.categoria == alvo.nome).length;
    if (emUso > 0) {
      return 'Esta categoria tem $emUso item(ns). '
          'Mova ou exclua os itens antes de remover.';
    }

    await _salvar(
      listar().where((c) => normalizar(c.nome) != normalizar(alvo.nome)).toList(),
    );
    return null;
  }

  /// Usado na restauração de backup: recria a categoria mantendo ícone e cor.
  /// Devolve true se ela foi adicionada (false se já existia).
  Future<bool> restaurar(CategoriaPersonalizada categoria) async {
    if (categoria.nome.trim().isEmpty || existe(categoria.nome)) return false;
    await _salvar([...listar(), categoria]);
    return true;
  }

  /// Garante que a categoria exista (cria com o ícone padrão se faltar).
  /// Útil quando um backup antigo traz itens de categorias que não conhecemos.
  Future<bool> garantir(String nome) async {
    final limpo = nome.trim();
    if (limpo.isEmpty || existe(limpo)) return false;
    final atuais = listar();
    await _salvar([
      ...atuais,
      CategoriaPersonalizada(
        nome: limpo,
        icone: iconePadrao,
        cor: paletaCores[atuais.length % paletaCores.length],
      ),
    ]);
    return true;
  }

  Future<void> _salvar(List<CategoriaPersonalizada> lista) =>
      _config.put(_chave, lista.map((c) => c.toMap()).toList());
}
