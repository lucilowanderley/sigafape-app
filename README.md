# SIGAFAPE · app do Operador de Campo

App de celular (Android e iPhone) do policial, feito em **Flutter**. Usa a API `/api/v1` do sistema web
([armaria-digital](https://github.com/lucilowanderley/armaria-digital), documentação em `docs/API-APP-OPERADOR-DE-CAMPO.md`).

- **Android 6.0 ou mais novo** (API 23). É o mínimo aceito pelo Flutter atual.
- Tela no modelo **A** (cartão do policial + atalhos em grade), nas cores **azul e dourado**, **escuro tático** e **cinza e marrom claro**.
  O policial escolhe a cor em *Eu → Aparência*.

## O que o app faz

| Aba | Conteúdo |
|---|---|
| Início | Cartão do policial, meu serviço e agenda de 30 dias, material comigo, reservas, assinaturas pendentes, inspeção, alertas, diárias, viatura em uso, depósitos e patrimônio |
| Material | Comigo agora e histórico (filtros por situação), com detalhe da cautela, assinaturas e **assinatura do recebimento** da cautela de urgência |
| Reservas | Minhas reservas, cancelamento e **nova reserva assinada** |
| Alertas | Notificações (ciência normal ou **assinada**, anexos) e avisos do sino |
| Eu | Minha ficha e pedido de atualização ao RH, inspeção do arsenal, aparelhos conectados, aparência, trocar senha, sair |

Login por usuário **ou matrícula**. O token do aparelho fica cifrado com chave do Android Keystore. Toda assinatura pede matrícula e senha, e a senha nunca é guardada.

## Baixar o .apk

O GitHub gera o .apk sozinho a cada envio na `main`: **Actions → Gerar APK → execução mais recente → Artifacts → sigafape-apk**.

- `sigafape-operador-de-campo.apk`: o app de verdade. Na primeira abertura, informe o endereço do sistema (ex.: `https://sigafape.8bpm.internal`).
- `sigafape-demonstracao.apk`: funciona **sem servidor**, com dados de exemplo. Entre com qualquer usuário e a senha `demo`; nas assinaturas use a matrícula `215.347-8` e a senha `demo`.

Para já sair com o endereço preenchido: *Actions → Gerar APK → Run workflow* e preencha **servidor**.
Ao criar uma tag `v1.0.0`, `v1.0.1`... o .apk também vai para **Releases**.

### Assinatura do .apk

Sem a chave de assinatura, o celular não aceita instalar uma versão nova por cima da antiga.
Cadastre em *Settings → Secrets and variables → Actions*: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_SENHA`, `ANDROID_KEY_ALIAS` e `ANDROID_KEY_SENHA`.
O arquivo `.jks` e as senhas **nunca** vão para o repositório.

## App do iPhone (iOS 15 ou mais novo)

O workflow **Gerar app iOS** (`.github/workflows/ios.yml`) compila o app num Mac do GitHub, sem precisar de Mac próprio:

- Sempre sai o `.ipa` **sem assinatura** (app real e demonstração) em Actions → execução → Artifacts → `sigafape-ios`.
  Ele confere que o app compila e pode ser instalado com ferramentas de *sideload* usando um Apple ID (o app vence em 7 dias).
- Com a conta **Apple Developer** e os segredos `IOS_*` e `ASC_*` cadastrados (lista no topo do workflow),
  também sai o `.ipa` assinado e vai direto para o **TestFlight**, de onde os policiais instalam no iPhone.

Identificador do app: `br.gov.rn.pm.sigafape.sigafapeApp`.

## Servidores (vários endereços)

Em *Eu → Servidores* o policial guarda mais de um endereço do sistema (Wi-Fi da unidade, Tailscale, nome interno, endereço na internet).
O app tenta na ordem da lista e usa o primeiro que responder. Se nenhum responder, abre a tela **Sem conexão**, que mostra o resultado de cada
endereço e permite testar e salvar um novo. Todo endereço é testado antes de ser salvo (`GET /api/v1/me` precisa responder 401 em JSON).

## Rede interna com CA própria (pmrn.internal)

Coloque o certificado público da CA em `assets/certs/ca.pem` e gere o .apk de novo: o app passa a confiar no HTTPS do servidor interno.
Endereços `http://` só servem para teste; o app mostra um aviso.

## Para programar

```bash
flutter pub get
flutter test                                   # testes com a API de demonstração
flutter run --dart-define=DEMO=true            # roda sem servidor
flutter test capturas/capturas_test.dart --update-goldens   # prints das telas em capturas/telas/
```

O app não usa plugins de terceiros: as funções nativas (guardar o token, nome do aparelho, abrir anexos) estão em
`android/app/src/main/kotlin/.../MainActivity.kt` e `ios/Runner/AppDelegate.swift`, no canal `sigafape/nativo`.
Isso mantém o mínimo em Android 6.0 (os plugins oficiais atuais exigem Android 7.0).

| Pasta | Conteúdo |
|---|---|
| `lib/api/` | Cliente da API, erros e certificados |
| `lib/screens/` | Telas |
| `lib/widgets/` | Peças comuns e a janela de assinatura |
| `lib/demo.dart` | API de demonstração (testes e .apk de demonstração) |
| `lib/tema.dart` | As 3 cores |
