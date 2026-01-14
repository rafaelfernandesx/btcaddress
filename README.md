# Bitcoin Address Generator 🪙

Um aplicativo Flutter profissional para geração segura de endereços Bitcoin com interface moderna e funcionalidades avançadas.

## ✨ Funcionalidades

### 🎯 Principais
- **Geração de Endereços Bitcoin**: Crie endereços a partir de seed, HEX ou WIF
- **Endereços Comprimidos e Descomprimidos**: Suporte completo para ambos os formatos
- **Geração Aleatória**: Crie chaves privadas seguras aleatoriamente
- **Consulta de Saldo**: Verifique o saldo de qualquer endereço Bitcoin

### 🎨 Interface Moderna
- **Design Profissional**: UI/UX limpa e intuitiva com Material Design 3
- **Tema Claro/Escuro**: Alterne entre temas com persistência de preferências
- **Animações Suaves**: Transições fluidas e feedback visual
- **Responsivo**: Funciona perfeitamente em diferentes tamanhos de tela

### 🔐 Recursos de Segurança
- **QR Codes**: Gere QR codes para compartilhar endereços com segurança
- **Copiar para Clipboard**: Copie rapidamente qualquer informação
- **Validação de Inputs**: Validação em tempo real de chaves HEX e WIF
- **Avisos de Segurança**: Lembretes sobre proteção de chaves privadas

### 📝 Histórico e Gerenciamento
- **Histórico de Endereços**: Salve até 50 endereços gerados
- **Detalhes Completos**: Visualize todas as informações de um endereço
- **Exportação Fácil**: Copie ou compartilhe via QR code
- **Limpeza de Histórico**: Gerencie seus dados com facilidade

### 🔍 Informações Avançadas
- **Chaves Privadas**: HEX, WIF e WIF Comprimida
- **Chaves Públicas**: HEX e HEX Comprimida
- **Hash RIPEMD-160**: Visualize os hashes intermediários
- **Múltiplos Métodos de Entrada**: Seed, HEX ou WIF

## 🚀 Como Usar

### Instalação
```bash
# Entre no diretório
cd btcaddress

# Instale as dependências
flutter pub get

# Execute o aplicativo
flutter run
```

### Gerando um Endereço

1. **Escolha o método de entrada**:
   - **Seed**: Digite qualquer texto ou use o botão "Gerar Aleatório"
   - **HEX**: Digite uma chave privada em formato hexadecimal (64 caracteres)
   - **WIF**: Digite uma chave privada em formato Wallet Import Format

2. **Visualize os resultados**:
   - Endereço comprimido (recomendado)
   - Endereço descomprimido (legacy)
   - Informações avançadas (chaves, hashes, etc.)

3. **Ações disponíveis**:
   - Copiar qualquer informação
   - Gerar QR code do endereço
   - Consultar saldo na blockchain
   - Salvar no histórico

## 🛠️ Tecnologias Utilizadas

- **Flutter**: Framework de desenvolvimento multiplataforma
- **Dart**: Linguagem de programação
- **Material Design 3**: Sistema de design moderno
- **Google Fonts**: Tipografia profissional (Inter)
- **QR Flutter**: Geração de QR codes
- **Shared Preferences**: Persistência local de dados
- **Dio**: Cliente HTTP para consultas de saldo
- **PointyCastle**: Criptografia ECDSA
- **RIPEMD-160**: Hash criptográfico

## 📦 Dependências Principais

```yaml
dependencies:
  flutter:
    sdk: flutter
  crypto: ^3.0.6
  pointycastle: ^3.9.1
  hex: ^0.2.0
  dio: ^5.7.0
  qr_flutter: ^4.1.0
  shared_preferences: ^2.2.2
  google_fonts: ^6.1.0
```

## 🎨 Estrutura do Projeto

```
lib/
├── main.dart                 # Ponto de entrada e tela principal
├── btc_tool.dart            # Lógica de geração de endereços Bitcoin
├── models/
│   └── address_model.dart   # Modelo de dados de endereço
├── screens/
│   ├── history_screen.dart  # Tela de histórico
│   └── address_detail_screen.dart # Tela de detalhes
├── services/
│   └── storage_service.dart # Serviço de armazenamento local
├── theme/
│   └── app_theme.dart       # Tema claro e escuro
└── widgets/
    ├── copyable_textfield.dart # Campo de texto com cópia
    └── qr_code_dialog.dart     # Diálogo de QR code
```

## 🔒 Segurança

⚠️ **IMPORTANTE**: Este aplicativo é para fins educacionais e de desenvolvimento. Para uso em produção:

- Nunca compartilhe suas chaves privadas
- Sempre use métodos seguros para gerar seeds aleatórias
- Mantenha backups seguros de suas chaves
- Considere usar hardware wallets para grandes quantias
- Teste em testnet antes de usar com Bitcoin real

## 📱 Recursos da Interface

### Tela Principal
- Interface limpa com cores do Bitcoin (laranja #F7931A)
- Campos de entrada intuitivos com validação
- Resultados bem organizados em cards
- Botão flutuante para geração rápida

### Tema Claro/Escuro
- Alternância fácil entre temas
- Design elegante para ambientes com pouca luz
- Persistência de preferência do usuário

### Histórico
- Lista de endereços gerados com data/hora
- Informações resumidas para visualização rápida
- Acesso rápido aos detalhes completos

### Detalhes do Endereço
- Todas as informações criptográficas organizadas
- QR codes para compartilhamento seguro
- Funcionalidade de cópia em um toque

---

**Feito com ❤️ usando Flutter**
