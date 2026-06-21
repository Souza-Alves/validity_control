# Controle de Validades

Aplicativo Flutter para **controle de validade de produtos** distribuídos por locais
(prédios/setores). Permite cadastrar locais e produtos, importar planilhas Excel,
acompanhar o que está vendido/vencido, exportar e enviar relatórios por e-mail, e
visualizar um relatório consolidado por local.

Funciona em **modo offline-first**: os dados ficam em cache local e são sincronizados
com o **Supabase** assim que há conexão (ao abrir telas e ao reconectar). Quando está
sem internet, um aviso é exibido e as alterações são enfileiradas para subir depois.

## Stack

- **Flutter** (Android, iOS e Web)
- **Supabase** (backend online) com sincronização offline (`connectivity_plus`)
- Tabelas: `tb_location` e `tb_products` (IDs `int8`)

## Arquitetura (MVC)

- **Model / Dados**: `lib/models/`, `lib/storage/`, `lib/supabase/`
- **Controller**: `lib/controllers/` (lógica das telas via `ChangeNotifier`)
- **View**: `lib/screens/`, `lib/widgets/`, `lib/theme/`

## Conceitos

- **Local**: área de armazenamento (ex.: prédio/loja). Pode estar ativo ou inativo.
- **Produto**: item com quantidade, validade (DD/MM/AAAA), situação e status.
- **Situação**: `Vendido` ou `Vencido`.
- **Status** (apenas para `Vencido`): `Baixado` ou `Pendente`.

## Navegação (menu inferior)

`Produtos` · `Cadastro` · `Dados` · `Relatório` · `Config`

Os itens **Cadastro** e **Dados** abrem um submenu (bottom sheet) com as respectivas telas.

## Funcionalidades por tela

### Produtos
Lista principal de produtos.
- Filtros por **local** (campo que ocupa toda a largura) e por **dias / período**
  (data inicial e final).
- Tabela com colunas **Local · Qtd · Produto · Data (dd/mm)**, com ordenação.
- **Exibe apenas** produtos cuja situação **não** seja `Vendido` nem `Vencido`.
- Tocar em uma linha abre o **modal de edição** (alterar local, produto, validade,
  quantidade, situação/status) com confirmação antes de **remover**.
- **Total** no rodapé somando as **quantidades** dos produtos visíveis.
- Indicador **"Carregando..."** enquanto os dados são carregados.

### Cadastro → Produtos
Formulário para **cadastrar um novo produto**: local, nome, quantidade, validade,
situação e status (status habilitado somente quando a situação é `Vencido`).

### Cadastro → Locais
Cadastro e gestão de **locais**: criar, editar nome e ativar/inativar.
- Renomear um local **propaga** o novo nome para os produtos vinculados.
- Produtos de locais **inativos** não aparecem nas listas e nos combos de filtro.

### Dados → Importação
Importa produtos a partir de uma **planilha Excel**.
- O arquivo deve conter as colunas: `predio`, `quantidade`, `produto`, `vencimento`.
- Converte a data serial do Excel para `DD/MM/AAAA`.
- **Pré-visualização** dos itens antes de confirmar; importação em **lote** (uma
  gravação + uma sincronização ao final).
- Cria automaticamente os locais únicos a partir da coluna `predio`.

### Dados → Exportar
Lista completa para exportação/relatório.
- **Exibe tudo** (inclusive `Vendido` e `Vencido`), com filtros de local e período.
- Tabela com fonte reduzida: **Local · Qtd · Produto · Data (dd/mm) · Situação · Status**.
- Tocar em uma linha abre o **mesmo modal de edição** da tela de Produtos.
- **Enviar por e-mail**: abre o app de e-mail (com seletor quando há mais de um app no
  Android) com o corpo em **tabela HTML** no mesmo estilo/colunas da tela.
- **Total** no rodapé somando as quantidades.

### Relatório
Visão consolidada por local, com o **mês atual** em destaque.
- **Caixa "Geral (todos os locais)"** logo abaixo do mês: **Total Geral**,
  **Vendidos**, **Vencidos** (= baixados + pendentes), **Pendentes** e **Baixados**,
  somando todos os locais.
- Um **card por local** com **Total Geral de Produtos** e a quebra em
  **Vendidos · Pendentes · Baixados**.
- Todas as contagens são por **quantidade** e **clicáveis**: ao tocar em um número,
  abre um modal com a **lista dos produtos** daquela contagem (na caixa Geral o local
  é exibido em cada item).

### Config
Configurações do aplicativo.
- **Apagar Toda a Base**: remove todos os locais e produtos (com confirmação).

## Como rodar

```bash
flutter pub get
flutter run            # device/emulador
flutter run -d chrome  # web
```

### Build

```bash
flutter build apk --release   # Android
flutter build web --release   # Web
```

### Qualidade

```bash
flutter analyze
```
