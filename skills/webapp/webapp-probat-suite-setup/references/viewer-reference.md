# probat-viewer — uso e contrato

O **probat-viewer** e um visualizador de resultados ProBat standalone, sem
dependencias externas, que roda inteiramente offline via `file://`. Nao e
necessario servidor, NPM, instalacao ou conexao de rede. Um unico arquivo HTML
cobre tudo: parser XML, arvore de navegacao, painel de ambiente, chips de
`<runParameters>`, tema claro/escuro e self-test embutido.

**Versao atual:** v2.1.0 (`const VIEWER_VERSION = "2.1.0"`)

**Asset:** [`assets/tools/probat-viewer.html`](../assets/tools/probat-viewer.html)
**Exemplo de XML:** [`assets/tools/sample-run.xml`](../assets/tools/sample-run.xml)

---

## Abrir e carregar

1. Abra `assets/tools/probat-viewer.html` diretamente no browser — basta
   arrastar o arquivo para uma aba, ou usar `File > Open` / `Ctrl+O`. A URL
   resultante comeca com `file://`.
2. Carregue o XML do run de uma destas formas:
   - **Drag-and-drop:** arraste o arquivo `.xml` carimbado para a janela do viewer.
   - **Botao de carga:** clique no botao de abertura de arquivo na interface e
     selecione o `.xml` desejado.
3. O viewer aceita qualquer XML que siga o contrato descrito em
   [Contrato XML](#contrato-xml). O arquivo de exemplo
   `assets/tools/sample-run.xml` pode ser carregado imediatamente para validar
   que o viewer esta funcionando antes de ter um run real.

> **Tema:** o viewer detecta a preferencia do sistema (`prefers-color-scheme`)
> automaticamente. E possivel alternar entre claro e escuro pelo controle na
> interface.

---

## Secoes

### Painel de ambiente/config

Exibido no topo, agrega informacoes do primeiro `<exec>` encontrado no XML:

| Campo no XML | O que o viewer exibe |
|---|---|
| `<info_server>` | Sistema operacional (`<so>`), versao do AppServer, versao do TLPP |
| `<iniconfiguration>` | Tipo de banco (`<DBTYPE>`), formato de export (`<EXPORT_FORMAT>`) e demais chaves presentes |
| `<inputParameters>` | Parametros passados ao `export()` do ProBat (`type:custom`, chave do run, etc.) |

Esses tres blocos ficam dentro do elemento `<exec>` que precede a(s) `<testsuite>`
do primeiro run. Execucoes subsequentes (segundo `<exec>`) tambem sao parseadas mas
o painel exibe os dados do primeiro.

### runParameters

Quando o XML contem `<runParameters>` (injetado por `u_stampResults`), o viewer
exibe:

- **Chips de contexto** no cabecalho — cada filho de `<runParameters>` vira um
  chip rotulado com o nome da chave e seu valor.
- **Secao expandida** com todos os parametros listados — util para rastrear
  exatamente quais valores de empresa, filial, branch, produto e fornecedor
  produziram o resultado sem abrir o fonte ou re-executar o runner.
- **Campo de busca** que filtra os parametros por nome.

### Arvore de resultados

Hierarquia de navegacao gerada a partir do XML:

```
Run (raiz — um por arquivo carregado)
  Suite (cada <testsuite>)
    Classe (@TestFixture — derivado de classname do <testcase>)
      Metodo (@Test — nome do metodo)
        Assercao (cada <testcase> individual)
```

Cada no exibe o status agregado (verde/vermelho/amarelo para skip). Clicar em
um no expande os filhos e exibe o detalhe da assercao (`system-out` com
`Result`/`Expected`/`Description`).

Contadores no cabecalho refletem o total do run: suites, testes (assercoes),
ok, failures, skipped.

---

## Self-test

O viewer inclui um conjunto de testes embutidos que validam o parser XML sem
dependencia de run real. Ha duas formas de ativar:

1. **URL:** adicione `?selftest` a URL do arquivo:
   ```
   file:///caminho/para/probat-viewer.html?selftest
   ```
   O self-test executa automaticamente ao carregar a pagina.

2. **Console do browser:** apos abrir o viewer normalmente, abra o DevTools
   (`F12`) e execute:
   ```javascript
   window.__probatSelfTest()
   ```

Os testes cobrem tres cenarios: multi-suite com `runParameters`, suite simples
sem `runParameters`, e suite vazia. O resultado aparece no console (`PASS` /
`FAIL` por caso).

Use o self-test para confirmar que o browser e as permissoes de `file://` estao
funcionando antes de carregar um XML real.

---

## Contrato XML

O ProBat exporta um XML no formato JUnit estendido pelo TOTVS. O viewer espera
a seguinte estrutura:

### Elemento raiz

```xml
<testsuites name="tlppCore_tests" tests="N" ok="N" failures="N" skipped="N"
            date="DD/MM/AA" time="HH:MM:SS">
  ...
</testsuites>
```

### Elemento `<exec>`

Aparece antes de cada `<testsuite>` correspondente. Carrega os metadados do run:

```xml
<exec code="A" custom="CHAVE-DO-RUN" time="0.25" ended="1781728305.35">
  <inputParameters>
    <param1>type:custom</param1>
    <param2>CHAVE-DO-RUN</param2>
  </inputParameters>
  <info_server>
    <so>Win</so>
    <AppServerVersion>24.3.1.5</AppServerVersion>
    <TLPPVersion>01.06.01</TLPPVersion>
  </info_server>
  <iniconfiguration>
    <DBTYPE>Local</DBTYPE>
    <EXPORT_FORMAT>JUnit</EXPORT_FORMAT>
  </iniconfiguration>
</exec>
```

- `code` vincula o `<exec>` a `<testsuite exec="A">` correspondente.
- `custom` deve bater com a chave do run usada em `runOffCoverage` e `export`.
- Execucoes adicionais (segundo suite) terao seu proprio `<exec>` com `code="B"` etc.

### Elemento `<testsuite>`

```xml
<testsuite exec="A" proc="000064" custom="CHAVE-DO-RUN" name="area_suite"
           tests="N" ok="N" failures="N" skipped="N"
           time="0.1" ended="1781728305.35">
  <testcase .../>
  ...
</testsuite>
```

- `proc` e o numero de processo do AppServer que executou a suite.
- `name` corresponde ao valor declarado em `@TestFixture(suite="...")` no fonte TLPP.
- `exec` vincula a suite ao `<exec>` com o mesmo `code`.

### Elemento `<testcase>`

Uma assercao por `<testcase>`:

```xml
<!-- assercao verde -->
<testcase classname="TEST.AREA.UM" name="Method:T01()" time="0">
  <system-out>Folder: T | Assert: OK | Result: {L}-[True] | Expected: {L}-[True] | Description: ok1</system-out>
</testcase>

<!-- assercao vermelha -->
<testcase classname="TEST.AREA.DOIS" name="Method:T03()" time="0">
  <failure type="Warning" message="diff">
    <system-out>Folder: T | Assert: EQUALS | Result: {C}-[2] | Expected: {C}-[3] | Description: falhou</system-out>
  </failure>
</testcase>
```

- `classname` segue o padrao `TEST.<AREA>.<FIXTURE>` — derivado do namespace e nome da classe.
- Ausencia de `<failure>` = assercao passou. Presenca de `<failure>` = falha.

### Elemento opcional `<runParameters>`

Inserido por `u_stampResults` ao final de `<testsuites>`, antes do fechamento:

```xml
<runParameters description="runner config passed to the test run">
  <branch>0101</branch>
  <product>000003</product>
  <emp>99</emp>
  <fil>01</fil>
</runParameters>
```

- Um filho por chave do `JsonObject` passado ao runner.
- Nomes de elemento XML-validos (sanitizados por `u_buildRunParamsXml`).
- Valores XML-escapados (`&amp;`, `&lt;`, `&gt;`).
- Ausente em XMLs gerados sem `jParams` (runner minimo sem env).

### Exemplo completo

Ver [`assets/tools/sample-run.xml`](../assets/tools/sample-run.xml) — XML de dois
runs (dois `<exec>` + duas `<testsuite>`) com `<runParameters>` preenchido (branch,
product, emp, fil). Cobre os dois cenarios mais comuns: assercao verde e assercao
vermelha.

---

## Versao

| Versao | Mudanca principal |
|---|---|
| `2.x` | Modelo multi-suite: um arquivo pode conter N `<testsuite>` de procs distintos, todos agrupados sob o mesmo `custom`. Hierarquia Run -> Suite -> Classe -> Metodo -> Assercao. |
| `2.1` | Suporte a `<runParameters>`: chips de contexto, secao expandida, campo de busca. |
| `2.1.0` | Versao atual (`const VIEWER_VERSION = "2.1.0"` em `assets/tools/probat-viewer.html`) |

Para verificar a versao do arquivo local:

```javascript
// no console do browser com o viewer aberto:
window.__appVer  // ou inspecionar o texto do elemento #appVer na interface
```
