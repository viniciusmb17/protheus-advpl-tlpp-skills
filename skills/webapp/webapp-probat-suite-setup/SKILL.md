---
name: webapp-probat-suite-setup
description: 'Bootstrap and run a portable ProBat test harness in any AdvPL/TLPP (Protheus) project, plus the probat-viewer. Covers the per-area runner (discovery/run/export), cross-thread JSON config, XML stamping with <runParameters>, env (RpcSetEnv/ParamBox) setup, fixture templates, and the standalone probat-viewer.html. Use when a user says "ProBat", "rodar testes TLPP", "runner ProBat", "infra de teste TLPP", "bootstrap teste Protheus", "configurar testes num projeto Protheus novo", "carimbar XML ProBat", or "probat-viewer". For writing the fixtures/asserts themselves, see the probat-testing skill.'
license: MIT
metadata:
  domain: Protheus
  maintainer: Customizacoes ADVPL/TLPP
  author: Vinicius Barbosa
  version: '1.0.0'
  category: Testing
  source: 'https://github.com/totvs/tlpp-probat-samples (official TOTVS samples) + TDN PROBAT'
---

# ProBat Suite Setup — Harness portavel + probat-viewer

## Overview

Esta skill empacota a **infra completa de testes ProBat** de forma portavel: o runner por area (discovery, run, export), o helper de stamp/inject de `<runParameters>` no XML, o helper de config cross-thread via JSON, os templates de fixture prontos para parametrizacao, e o **probat-viewer v2.1.0** para visualizacao off-line dos resultados. O foco e **harness** — como montar, conectar e rodar a infra em qualquer projeto AdvPL/TLPP Protheus — e nao como escrever asserts ou fixtures (isso e responsabilidade da skill irma `probat-testing`). Todos os templates sao ASCII-only (CP-1252 safe) e usam placeholders parametrizaveis, de modo que o mesmo conjunto de arquivos serve tanto neste projeto quanto em um projeto Protheus zerado.

## Relacao com probat-testing

| Skill | Responsabilidade |
|---|---|
| **`webapp-probat-suite-setup`** (esta) | Harness, runner, config cross-thread, stamp/export, viewer, portabilidade |
| **[`probat-testing`](../probat-testing/SKILL.md)** | Authoring: fixtures `@TestFixture`/`@Test`, API completa de asserts, lifecycle setup/teardown, exemplos de testes de integracao |

Nao e repetida aqui a tabela de asserts nem o ciclo de lifecycle — carregue `probat-testing` quando precisar escrever ou revisar fixtures.

## Quando usar

| Situacao | Usar esta skill |
|---|---|
| Criar a infra de testes em um projeto Protheus novo | Sim — bootstrap completo |
| Adicionar um runner para uma nova area (`<area>`) | Sim — copiar e parametrizar o template de runner |
| Carimbar XML com `<runParameters>` e visualizar no viewer | Sim — stamp + probat-viewer |
| Portar o harness para outro projeto Protheus | Sim — assets portaveis prontos |
| Escrever uma nova fixture ou escolher o assert correto | Nao — usar `probat-testing` |

## Bootstrap "novo projeto"

Checklist operacional para montar a infra do zero em qualquer projeto AdvPL/TLPP:

**Passo 0 — Coletar do usuario antes de criar qualquer arquivo:**

- **(a) Local da pasta de teste (`<test-root>`):** perguntar onde criar a estrutura. Default: `test/` na raiz do projeto. Aceitar caminho alternativo se o usuario informar (ex.: `server/test/`, convencao deste repo). Nao assumir `server/` automaticamente.
- **(b) Empresa (`<emp>`) e Filial (`<fil>`):** perguntar os valores a usar como defaults do runner e do config-helper. Esses valores ficam hardcoded em `cfgDefault` do helper de config; sem colete-los, nao gerar o runner.

1. Criar `<test-root>/common/`, `<test-root>/<area>/` e `<test-root>/tools/`.
2. Copiar `assets/common/probatStampResults.tlpp` para `<test-root>/common/` (quase intacto — so substituir `<author>`).
3. Escolher o runner conforme a area precisa de env:
   - **Sem env** (fixture de funcao pura): `assets/common/runTestArea.tlpp` → `<test-root>/common/runTest<Area>.tlpp`
   - **Com env/ParamBox** (ExecAuto, rotinas com RpcSetEnv): `assets/area/runTestArea.tlpp` → `<test-root>/<area>/runTest<Area>.tlpp`
4. Quando houver inputs em runtime, copiar `assets/area/areaTestConfig.tlpp` → `<test-root>/<area>/<area>TestConfig.tlpp`.
5. Adicionar a primeira fixture:
   - Com env: `assets/area/test_target.tlpp` → `<test-root>/<area>/test_<target>.tlpp`
   - Sem env: `assets/common/test_pure.tlpp` → `<test-root>/common/test_<target>.tlpp`
6. Substituir todos os placeholders nos arquivos copiados:
   - `<area>` — namespace e pasta de teste (ex.: `compras`)
   - `<mod>` — modulo Protheus (ex.: `COM`)
   - `<emp>` / `<fil>` — empresa/filial coletados no passo 0
   - `<author>` — nome para o header ProtheusDOC
   - `<target>` — funcao ou classe sob teste (ex.: `pcNecessidades`)
   - `<target-ns>` — namespace qualificado do simbolo sob teste (ex.: `portalaprovacao.u_pcNecessidades`)
7. Garantir os includes no topo de cada fonte: `tlpp-core.th`, `totvs.ch`, `tlpp-probat.th`; runners com SQL adicionam `topconn.ch`. O RPO deve conter os fontes compilados.
8. Rodar via SmartClient ("Programa inicial": `U_runTest<Area>`) ou console TDS.
9. Abrir `assets/tools/probat-viewer.html` via `file://` no browser e carregar o XML carimbado.

> Para detalhes de parametrizacao de cada template, ver [`references/harness-reference.md`](references/harness-reference.md).

## Fluxo do runner

Cadeia canonica do runner completo (com env):

```
RpcSetEnv(cEmp, cFil,,,"<mod>")
  -> ParamBox (guardado por IsBlind() — headless pula o dialog)
  -> RpcClearEnv()
  -> u_<area>TestCfgSet(jCfg)              // grava o JSON inteiro com MemoWrite
  -> tlpp.module('PROBAT', @jModule)
  -> tlpp.probat.discovery()               // assincrono; aguardar com Sleep(1500)
  -> loop por suite: runOffCoverage("type:suite", <suite>, "custom:"+cKey)   // Sleep(2000) entre suites
  -> export("type:custom", cKey)
  -> u_stampResults(cKey, , jCfg)          // renomeia + injeta <runParameters>
```

**Ponto critico — ordem RpcSetEnv/ParamBox/RpcClearEnv:** `ParamBox` chama `xFilial()` internamente e precisa de `cFilAnt` na memoria. Por isso: `RpcSetEnv` **antes** do `ParamBox`; `RpcClearEnv` **depois** do `ParamBox` (antes do ProBat). Sem essa ordem o runner falha com `variable does not exist CFILANT`.

## Config cross-thread

ProBat executa cada fixture em **outra thread** — um `Private` atribuido no runner e invisivel ao teste. Regras:

- Config de runtime (emp, fil, branch, produto, fornecedor, solicitacao, etc.) passa por **arquivo JSON** gravado com `MemoWrite` e lido com `MemoRead`.
- O helper `<area>TestConfig.tlpp` expoe `u_<area>TestCfgSet(jCfg)` (grava o objeto JSON inteiro) e `u_<area>TestCfg(cChave[, cDefault])` (le um valor por chave, com default opcional).
- Defaults centrais ficam em `cfgDefault` no helper; os valores de `<emp>` e `<fil>` em `cfgDefault` vem do que o usuario informou no passo 0 — nao chumbar `99`/`01` sem perguntar.
- Nunca usar `Private` para passar config entre runner e fixture; nunca commitar valores de emp/fil hardcoded sem que o usuario tenha confirmado.

## Gotchas (cada um quebra o run)

- Asserts sao bare functions, **actual primeiro**: `assertEquals(actual, expected[, desc])`; nunca `::assertEquals`.
- Todo `@Test` **`Return .T.`** (bare `Return` -> "Invalid method return").
- **Sem `==` na string de descricao** de `@Test`/assert (usar "igual"/"vs").
- **Qualificar namespaces** de `test.*` (ex. `portalaprovacao.u_pcX(...)`, `Classe():new()`).
- `oRest`/response paths e `Static Function` privada nao unit-testaveis -> `assertOK("SKIP: ...")` + testar simbolo publico.
- Negative credential: **usuario inexistente** (nao senha errada — `avKey()` trunca).
- Campos **Memo (M)**: `SELECT R_E_C_N_O_`, ler por recno; ao gravar nao `PadR`.
- ExecAuto/rotina automatica: registros **sacrificiais**; modulo em `@OneTimeSetUp` (`RpcSetEnv(...,"<mod>")`), fecha em `@OneTimeTearDown` (`RpcClearEnv()`).
- Export do ProBat tem **nome fixo** (appserver.ini) -> runs sobrescrevem -> `stampResults` renomeia com timestamp.

## runParameters (o jeito atual)

O mecanismo atual (entregue em commit `c625422`, spec `2026-06-24-probat-runparams-xml-design.md`) injeta os parametros do run diretamente no XML exportado:

- `u_buildRunParamsXml(jParams)` — constroi o bloco `<runParameters>` (um filho por chave do JSON, valor XML-escapado, nome sanitizado).
- `u_injectRunParams(cXmlPath, cBlock)` — insere o bloco antes do ultimo `</testsuites>` no arquivo.
- `u_stampResults(cKey, , jCfg)` — renomeia o XML exportado com timestamp **e** injeta `<runParameters>` quando `jCfg` e informado.

O probat-viewer v2.1.0 parseia `<runParameters>` e exibe como chips de contexto, secao expandida e campo de busca. Isso permite rastrear exatamente quais parametros (emp, fil, branch, supplier, etc.) produziram cada resultado sem abrir o fonte.

## Visualizar (probat-viewer)

O **probat-viewer v2.1.0** e um arquivo HTML zero-dependencia que roda off-line via `file://` — sem servidor, sem NPM, sem instalacao. Abra `assets/tools/probat-viewer.html` no browser, arraste o XML carimbado ou use o botao de carga, e navegue pela arvore Run -> Suite -> Classe -> Metodo -> Assercao. Suporta tema claro/escuro, chips de `runParameters`, self-test embutido (`?selftest` na URL ou `window.__probatSelfTest()` no console).

Para o contrato XML completo e o modo de uso avancado, ver [`references/viewer-reference.md`](references/viewer-reference.md) e o asset [`assets/tools/probat-viewer.html`](assets/tools/probat-viewer.html).

## Assets

Templates parametrizaveis e ferramentas incluidos nesta skill:

- **`assets/common/probatStampResults.tlpp`** — helper `u_stampResults` + `u_buildRunParamsXml` + `u_injectRunParams`; porta diretamente para qualquer projeto (substituir `<author>`).
- **`assets/common/test_pure.tlpp`** — fixture de funcao pura (sem env/RpcSetEnv); exemplo minimo para testar helpers e utilitarios headless (substituir `<author>`, `<area>`, `<target>`, `<target-ns>`).
- **`assets/common/runTestArea.tlpp`** — runner minimo sem env (discovery + run + export + stamp); usar quando a area nao precisa de RpcSetEnv (substituir `<area>`, `<author>`).
- **`assets/area/runTestArea.tlpp`** — runner completo com `ParamBox` (guardado por `IsBlind()`), `RpcSetEnv`/`RpcClearEnv`, gravacao de jCfg e stamp com `<runParameters>`; usar quando a area usa ExecAuto ou rotinas com modulo (substituir `<area>`, `<mod>`, `<emp>`, `<fil>`, `<author>`).
- **`assets/area/areaTestConfig.tlpp`** — helper de config cross-thread: `u_<area>TestCfgSet`/`u_<area>TestCfg` via `MemoWrite`/`MemoRead`; defaults em `cfgDefault` (substituir `<area>`, `<emp>`, `<fil>`, `<author>`).
- **`assets/area/test_target.tlpp`** — fixture classe-estilo com env (`@OneTimeSetUp`/`@OneTimeTearDown` com `RpcSetEnv`/`RpcClearEnv`); modelo para testes de integracao (substituir `<area>`, `<target>`, `<target-ns>`, `<mod>`, `<author>`).
- **`assets/tools/probat-viewer.html`** — probat-viewer v2.1.0 completo; copiar para `<test-root>/tools/` e abrir via `file://`.
- **`assets/tools/sample-run.xml`** — XML de exemplo com `<runParameters>` preenchido; usar para validar o viewer antes de ter um run real.

**Legenda de placeholders (aparecem dentro do conteudo dos arquivos, nunca como nomes de arquivo):**

| Placeholder | Significado |
|---|---|
| `<area>` | Nome da area de teste e namespace (ex.: `compras`) |
| `<mod>` | Modulo Protheus para `RpcSetEnv` (ex.: `COM`) |
| `<emp>` | Codigo da empresa (ex.: `01`) |
| `<fil>` | Codigo da filial (ex.: `0101`) |
| `<author>` | Nome para o header `@author` do ProtheusDOC |
| `<target>` | Nome curto do simbolo sob teste (ex.: `pcNecessidades`) |
| `<target-ns>` | Namespace qualificado do simbolo sob teste (ex.: `portalaprovacao.u_pcNecessidades`) |
| `<test-root>` | Caminho da pasta de teste no projeto-alvo (decisao do bootstrap, nao token de codigo) |

## Fontes oficiais

- Repositorio de exemplos: https://github.com/totvs/tlpp-probat-samples
- TDN PROBAT: https://tdn.totvs.com/display/tec/PROBAT
- TDN Asserts: https://tdn.totvs.com/display/tec/d+-+Asserts
