# Harness ProBat — anatomia dos templates

Este documento e a referencia tecnica aprofundada dos templates que a skill
[`webapp-probat-suite-setup`](../SKILL.md) instala. O SKILL.md cobre o checklist de
bootstrap e o fluxo do runner em alto nivel; aqui esta a anatomia arquivo a
arquivo: o que cada funcao faz, por que a ordem de chamada importa, e como os
templates se conectam entre si.

**Escopo.** Este documento descreve o *harness* — a infra de descoberta, run,
export e stamp. Para a API de asserts (`assertEquals`, `assertTrue`, `assertOK`,
etc.) e o ciclo de lifecycle (`@TestFixture`, `@Setup`, `@OneTimeSetUp`), use
[probat-testing](../../probat-testing/SKILL.md).

---

## Placeholders

Os templates usam tokens delimitados por `<` e `>` dentro do *conteudo* dos
arquivos — nunca como nome de arquivo. Ao copiar um template para o projeto
alvo, renomeie o arquivo conforme a convencao de destino e substitua todos os
tokens pelo valor real.

| Placeholder | O que representa | Exemplo |
|---|---|---|
| `<area>` | Nome curto da area de teste; vira namespace (`test.<area>`) e nome de pasta (`<test-root>/<area>/`) | `compras` |
| `<mod>` | Modulo Protheus passado ao `RpcSetEnv` (terceiro par de aspas simples `,,,"<mod>"`) | `COM` |
| `<emp>` | Codigo de empresa para `cfgDefault`; valor coletado no passo 0 do bootstrap | `01` |
| `<fil>` | Codigo de filial para `cfgDefault`; valor coletado no passo 0 do bootstrap | `0101` |
| `<author>` | Nome do autor para o header `@author` do `{Protheus.doc}` | `Vinicius Barbosa` |
| `<target>` | Nome curto da funcao ou classe sob teste; aparece em nomes de classe e metodo da fixture | `pcNecessidades` |
| `<target-ns>` | Namespace qualificado do simbolo sob teste, usado para chamada cross-namespace na fixture | `portalaprovacao.u_pcNecessidades` |
| `<test-root>` | Caminho da pasta de teste no projeto alvo — decisao de bootstrap, nao token de codigo. Default: `test/` na raiz do projeto. Aceitavel qualquer caminho alternativo (ex.: `server/test/`) que o usuario informe no passo 0. | `server/test` |

> **Nota sobre nomes de arquivo:** os assets usam nomes literais como stand-ins
> (`area/runTestArea.tlpp`, `area/areaTestConfig.tlpp`, `area/test_target.tlpp`).
> Ao copiar para `<test-root>`, renomeie de acordo — ex.:
> `area/runTestArea.tlpp` -> `compras/runTestCompras.tlpp`. Os tokens `<...>` no
> conteudo do arquivo sao substituidos separadamente (ver passo 6 do SKILL.md).

---

## probatStampResults.tlpp

**Localizacao no asset:** `assets/common/probatStampResults.tlpp`
**Namespace:** `test.common`
**Destino tipico:** `<test-root>/common/probatStampResults.tlpp` (quase sem alteracoes — substituir apenas `<author>`)

### Por que existe

O ProBat exporta o XML com um nome fixo determinado pela chave `PROBAT_XML_PATH`
do `appserver.ini`. Execucoes sucessivas sobrescrevem o mesmo arquivo. O helper
de stamp localiza o XML recem-gerado, confirma que e o run correto e renomeia com
timestamp, preservando o historico.

### Funcoes publicas

> **Convencao de nome (TLPP):** estas funcoes sao declaradas **sem** o prefixo `u_`
> (`User Function stampResults(...)`, `buildRunParamsXml`, `injectRunParams`). O
> `User Function foo()` publica o simbolo `U_FOO`, **chamado** como `u_foo()` /
> `<namespace>.u_foo()`. Por isso este doc usa a forma de chamada `u_stampResults(...)`,
> mas no fonte a declaracao e `stampResults(...)`.

#### `u_stampResults(cKey, cDir, jParams)`

Ponto de entrada principal, chamado pelo runner logo apos `tlpp.probat.export`.

- **Busca** todos os `*.xml` no diretorio `cDir` (default: rootpath do AppServer).
- **Ordena** do mais recente para o mais antigo por data+hora de modificacao.
- **Confirma** o arquivo correto pela tag `custom="<cKey>"` dentro do conteudo XML — nao so pelo timestamp (evita colisao quando dois runners rodam em sequencia rapida).
- **Renomeia** para `<cKey>_<YYYYMMDD>-<HHMMSS>.xml`.
- Se o arquivo `_warning.xml` irmao existir, recebe o mesmo timestamp (sem injecao de params).
- Se `jParams` for informado: chama `u_buildRunParamsXml` + `u_injectRunParams`, grava o XML enriquecido com o novo nome e apaga o original; se a gravacao falhar, recai no rename simples.
- Falhas de rename/gravacao sao registradas como `WARN` em `FWLogMsg` — nunca derrubam o run.
- **Retorna** o novo nome do arquivo, ou `""` se nada foi renomeado.

O limite `STAMP_MAX_SCAN` (20) restringe quantos XMLs sao lidos na varredura —
o export recem-gravado e sempre o mais recente, entao varrer os 20 primeiros e
suficiente e evita ler todo o rootpath em ambientes com muitos arquivos.

#### `u_buildRunParamsXml(jParams)`

Constroi o bloco XML `<runParameters>` a partir de um `JsonObject`:

- Um elemento filho por chave do JSON.
- Nomes de elemento sanitizados: mantidos apenas `[A-Za-z0-9_]`, digitos iniciais removidos (`1bad` -> `bad`).
- Valores XML-escapados (`&` -> `&amp;`, `<` -> `&lt;`, `>` -> `&gt;`).
- JSON vazio ou `nil` retorna `""` (sem bloco).

#### `u_injectRunParams(cXml, cBlock)`

Insere `cBlock` imediatamente antes do ultimo `</testsuites>` no conteudo XML
passado como string. Se `cBlock` for vazio, retorna `cXml` sem alteracao. Se
`</testsuites>` nao for encontrado, anexa ao fim (fallback defensivo).

### Funcoes privadas (Static Function)

`sanitizeName` e `xmlEscape` sao `Static Function` — escopo de arquivo, nao
acessiveis de fora. Por essa razao usam comentarios inline em vez de headers
`{Protheus.doc}` (convencao do repositorio: ProtheusDOC apenas em funcoes
publicas).

---

## Runners

Existem dois templates de runner, escolhidos conforme a area precisa de ambiente
Protheus (empresa/filial/modulo) ou nao.

### Runner minimo — `assets/common/runTestArea.tlpp`

**Use quando:** a area testa funcoes puras, helpers, utilitarios — sem SQL, sem
ExecAuto, sem `RpcSetEnv`.

**Fluxo:**

```
tlpp.module('PROBAT', @jModule)        // verifica instalacao
tlpp.probat.discovery()                // assincrono: Sleep(1500) a seguir
loop: tlpp.probat.runOffCoverage(...)  // Sleep(2000) entre suites
tlpp.probat.export("type:custom", cKey)
test.common.u_stampResults(cKey)       // so renomeia (sem jParams)
```

Nao ha `RpcSetEnv`, `ParamBox` nem config cross-thread — o runner e intencionalmente
minimo. O `cKey` e gerado como `"<AREA>-" + StrTran(Time(),":","-")` para ser
unico por run.

**Ao copiar:** colocar em `<test-root>/common/`, renomear o arquivo
(`runTestArea.tlpp` -> `runTest<Area>.tlpp`), substituir `<area>` e `<author>`, e
atualizar `groupSuites()` com as suites da area.

### Runner completo — `assets/area/runTestArea.tlpp`

**Use quando:** a area usa ExecAuto, rotinas automaticas, SQL com branch, ou
qualquer operacao que exija `RpcSetEnv`.

**Fluxo:**

```
[IsBlind() = .F.]
  RpcSetEnv(cEmpUi, cFilUi, , , "<mod>")   // (1) prepara xFilial/cFilAnt
  ParamBox(...)                              // (2) coleta inputs do usuario
  RpcClearEnv()                             // (3) limpa antes do ProBat
test.<area>.u_<area>TestCfgSet(jCfg)        // grava config no arquivo JSON
tlpp.module('PROBAT', @jModule)
tlpp.probat.discovery()  + Sleep(1500)
loop: tlpp.probat.runOffCoverage(...) + Sleep(2000)
tlpp.probat.export("type:custom", cKey)
test.common.u_stampResults(cKey, , jCfg)   // renomeia + injeta <runParameters>
```

#### Guard `IsBlind()`

`IsBlind()` retorna `.T.` quando o AppServer roda sem SmartClient (modo headless,
ex.: linha de comando, automacao). Nesse caso, o bloco `ParamBox`/`RpcSetEnv`/
`RpcClearEnv` e pulado inteiramente — o runner usa os defaults de `cfgDefault` ou
os parametros passados diretamente na chamada.

#### Ordem obrigatoria: RpcSetEnv antes / RpcClearEnv depois do ParamBox

`ParamBox` chama `xFilial()` internamente. `xFilial()` precisa que a variavel de
sistema `cFilAnt` esteja definida na memoria — ela so e criada por `RpcSetEnv`.
**Se `RpcSetEnv` nao for chamado antes de `ParamBox`, o runner falha com
`variable does not exist CFILANT`.** Apos o `ParamBox`, `RpcClearEnv` limpa o
ambiente antes do ProBat iniciar (os proprios fixtures gerenciam o env via
`@OneTimeSetUp`/`@OneTimeTearDown`).

#### Config cross-thread via JSON

ProBat executa cada fixture em outra thread. Um `Private` definido no runner nao
e visivel ao teste. Por isso, apos coletar os parametros, o runner chama
`u_<area>TestCfgSet(jCfg)` que grava um arquivo JSON (`MemoWrite`). A fixture le
esse arquivo com `u_<area>TestCfg(cKey)` (`MemoRead`). O mesmo `jCfg` e passado a
`u_stampResults` para injecao em `<runParameters>` no XML.

**Ao copiar:** colocar em `<test-root>/<area>/`, renomear o arquivo
(`runTestArea.tlpp` -> `runTest<Area>.tlpp`), substituir `<area>`/`<mod>`/`<author>`,
ajustar os campos do `ParamBox` aos inputs do dominio e atualizar `groupSuites()`.

---

## Config helper

**Asset:** `assets/area/areaTestConfig.tlpp`
**Namespace:** `test.<area>`
**Destino tipico:** `<test-root>/<area>/<area>TestConfig.tlpp`

Expoe dois simbolos publicos e duas funcoes privadas:

| Simbolo | Tipo | Responsabilidade |
|---|---|---|
| `u_<area>TestCfgSet(jCfg)` | `User Function` | Serializa `jCfg` para JSON e grava em `probat_<area>_cfg.json` via `MemoWrite` |
| `u_<area>TestCfg(cKey, cDef)` | `User Function` | Le o JSON (`MemoRead`), extrai `cKey`; fallback: `cDef` > `cfgDefault(cKey)` |
| `cfgDefault(cKey)` | `Static Function` | Retorna os defaults centrais de `emp` e `fil` (valores coletados no passo 0) |
| `<area>TestCfgFile()` | `Static Function` | Retorna o nome do arquivo de config (`"probat_<area>_cfg.json"`) |

**`cfgDefault`** e a fonte unica de `<emp>` e `<fil>` — os valores hardcoded ali
sao os que o usuario informou no passo 0 do bootstrap. Nao assumir `99`/`01` sem
perguntar.

**Arquivo JSON cross-thread:** gravado no rootpath do AppServer (sem caminho
absoluto), acessivel tanto pelo runner (thread principal) quanto pelos fixtures
(thread async do ProBat). O nome inclui o `<area>` para evitar colisao entre
diferentes areas rodando em paralelo.

---

## Fixtures

### Fixture com env — `assets/area/test_target.tlpp`

**Use quando:** a funcao sob teste precisa de ambiente Protheus ativo (SQL,
ExecAuto, `RpcSetEnv`).

- **Namespace:** `test.<area>`
- **Suite:** `<area>_<suite>` (deve bater com a lista em `groupSuites()` do runner)
- **Lifecycle:** `@OneTimeSetUp` / `@OneTimeTearDown` (uma vez por fixture, nao por metodo)
  - `prepara()`: le `emp`/`fil` do config helper, chama `RpcSetEnv(::cEmp, ::cFil, , , "<mod>")`
  - `encerra()`: chama `RpcClearEnv()`
- **Chamada do simbolo sob teste:** `<target-ns>.u_<target>(jParams)` — namespace
  qualificado obrigatorio (ex.: `portalaprovacao.u_pcNecessidades(jParams)`); bare
  `u_pcNecessidades(jParams)` de dentro de `test.<area>` resulta em "invalid symbol".
- Os parametros de runtime (`branch`, `product`, `supplier`, `request`) sao lidos
  via `u_<area>TestCfg("branch", "")` para permitir skip gracioso quando o valor
  nao foi informado no runner.

### Fixture pura — `assets/common/test_pure.tlpp`

**Use quando:** a funcao sob teste nao tem dependencias de ambiente — funcoes
utilitarias, helpers, logica de negocio sem SQL.

- **Namespace:** `test.common`
- **Sem** `@OneTimeSetUp`/`@OneTimeTearDown` — nenhum `RpcSetEnv`.
- O template entregue testa os helpers `u_buildRunParamsXml` e `u_injectRunParams`
  de `probatStampResults.tlpp` (fixture de verificacao do proprio harness). Para
  testar outro simbolo puro, adaptar a classe substituindo `<target>` e `<target-ns>`.
- Chamadas: `test.common.u_buildRunParamsXml(jP)`, `test.common.u_injectRunParams(cXml, cBlock)`.

---

## Testavel vs SKIP

| Tipo de simbolo | Estrategia |
|---|---|
| `User Function` / `u_*` core sem `oRest` | Testavel diretamente: instanciar via namespace qualificado e passar `JsonObject` |
| `Static Function` privada (escopo de arquivo) | Nao acessivel de fixture externa — testar via o simbolo publico que a chama |
| Logica que depende de `oRest` (request/response HTTP) | Nao unit-testavel: nao ha request HTTP real no ProBat. Usar `assertOK("SKIP: oRest path nao testavel headless")` com nota explicativa |
| ExecAuto / rotina automatica | Testavel com registros sacrificiais em homologacao; usar `@OneTimeSetUp` / `@OneTimeTearDown` |
| Caminhos de erro HTTP (401, 403, token invalido) | Pertencem a camada HTTP — cobrir por teste de integracao manual ou TIR |

Exemplo de SKIP documentado:

```tlpp
method test_rotaInterna() class test_minhaArea
  assertOK("SKIP: Static Function privada; testada via u_meuCore()")
return .T.
```

---

## ProtheusDOC

Todas as `User Function` publicas dos templates carregam o header
`/*/{Protheus.doc}` em pt-BR (ASCII-only, compativel com CP-1252):

```
/*/{Protheus.doc} nomeFunc
Descricao breve da funcao.
@type function
@author <author>
@since DD/MM/AAAA
@param cParam, character, descricao
@return character, descricao do retorno
/*/
```

**`Static Function` em `common/`** (ex.: `sanitizeName`, `xmlEscape`,
`cfgDefault`, `<area>TestCfgFile`) usam comentarios inline (`// ...`) — e a
convencao do repositorio. Nao forcar ProtheusDOC em funcoes privadas de arquivo.

O `<author>` deve ser o nome real do responsavel pela sessao — perguntar uma vez
por sessao e reusar (nunca hardcodar, nunca copiar de codigo pre-existente). Ver
a skill `documentation-writer` para o template completo de headers.

---

## Nao reinventar

Este documento cobre apenas o *harness* (infra, runners, config, stamp). Para a
API de asserts, o ciclo de lifecycle e os padroes de escrita de fixtures, use:

**[probat-testing](../../probat-testing/SKILL.md)**

Nao duplicate a tabela de asserts (`assertEquals`, `assertTrue`, `assertFail`,
`assertOK`, etc.) nem as regras de `@Setup`/`@TearDown` aqui.
