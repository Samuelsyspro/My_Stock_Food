# My_Stock_Food – Gerenciador de Estoque para Crises

App Android 100% **offline** para controlar o estoque de sobrevivência (água, alimentos, combustível, médico, higiene, ferramentas etc.).

## Funcionalidades

- Dashboard com resumo (total de itens, vencidos e que vencem em 30 dias)
- Categorias prontas: Água, Alimentos, Combustível, Médico, Higiene, Ferramentas, Outros
- Cadastro de itens com quantidade, unidade, validade, localização e notas
- Alertas visuais de validade
- Ajuste rápido de quantidade (+1 / -1)
- Armazenamento local com Hive (funciona sem internet)
- Tema escuro

## Como gerar o APK

### 1. Instalar o Flutter (se ainda não tiver)

No Windows, macOS ou Linux:

1. Baixe o Flutter: https://docs.flutter.dev/get-started/install
2. Extraia e adicione o `flutter/bin` no PATH
3. Rode:
   ```bash
   flutter doctor
   ```
4. Aceite as licenças do Android e instale o Android Studio (ou só o SDK)

### 2. Abrir o projeto

```bash
cd prep_manager
flutter pub get
```

### 3. Gerar o APK de release

```bash
flutter build apk --release
```

O arquivo ficará em:

```
build/app/outputs/flutter-apk/app-release.apk
```

### 4. Instalar no celular

- Transfira o `app-release.apk` para o celular
- Ative “Fontes desconhecidas” / “Instalar apps desconhecidos”
- Instale normalmente

### Alternativa: APK dividido por ABI (menor tamanho)

```bash
flutter build apk --split-per-abi --release
```

Gera um APK para cada arquitetura (arm64-v8a é o mais comum em celulares modernos).

## Estrutura do projeto

```
lib/
  main.dart                 → ponto de entrada
  models/item.dart          → modelo de dados + adapter Hive
  services/item_service.dart → lógica de CRUD
  screens/
    home_screen.dart        → dashboard
    item_list_screen.dart   → lista por categoria / filtros
    add_edit_item_screen.dart → formulário de cadastro/edição
```

## Requisitos

- Flutter 3.16+ (recomendado)
- Android SDK 21+ (Android 5.0+)

## Dicas de uso em crise

1. Cadastre tudo que já tem em casa
2. Use a data de validade sempre que existir
3. Rotacione o estoque (consuma o que está perto de vencer primeiro)
4. Faça backup do celular periodicamente (os dados ficam no app)

---

Feito para situações de escassez. Mantenha o estoque atualizado.
