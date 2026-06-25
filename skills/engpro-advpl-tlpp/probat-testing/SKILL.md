---
name: probat-testing
description: 'Generate ProBat unit/integration tests in TLPP for AdvPL/TLPP functions, classes and methods (the tlppCore test engine). Covers @TestFixture/@Test annotations, setup/teardown lifecycle, the full assert API (assertEquals, assertTrue, assertJson, assertVector, etc.), function-style vs class-style fixtures, and DB integration tests. Use when a user says "ProBat", "teste unitario TLPP", "TLPP unit test", "@TestFixture", "@Test", "assertEquals", "testar funcao/classe TLPP", or "teste automatizado TLPP".'
license: MIT
metadata:
  domain: Protheus
  maintainer: Customizações ADVPL/TLPP
  author: Vinicius Barbosa
  version: '1.0.0'
  category: Testing
  source: 'https://github.com/totvs/tlpp-probat-samples (official TOTVS samples)'
---

# ProBat — Testes Unitários e de Integração em TLPP

## Overview

**ProBat** é o motor de testes do **tlppCore** (nativo do AppServer Protheus). Permite criar e executar testes **unitários, funcionais e de integração** escritos em **TLPP/AdvPL**, com suporte a TDD. Diferente do **TIR** (que dirige a *tela* SmartClient/Webapp em Python), o ProBat roda **headless dentro do AppServer** e faz asserções diretamente sobre o resultado de funções/métodos e o estado do banco.

> **Fonte canônica:** repositório oficial **`totvs/tlpp-probat-samples`** e TDN (`tdn.totvs.com/display/tec/PROBAT`). Toda a sintaxe abaixo foi extraída desses exemplos oficiais — valide símbolos novos contra eles (regra *API Symbol Validation* do CLAUDE.md).

## Quando usar

| Situação | Ferramenta |
|---|---|
| Testar lógica de função/método/classe TLPP, regra de negócio, repositório, util | **ProBat** (esta skill) |
| Testar gravação via ExecAuto / rotina automática (ex.: NFCA020) com assert no banco | **ProBat** (teste de integração) |
| Testar a **tela** Protheus (SmartClient/Webapp), CRUD/MVC visual | `tir-test-generator` |
| Testar o **portal web** (Next.js) | Playwright (não Protheus) |

## Include e namespace (obrigatórios)

```tlpp
#include 'tlpp-core.th'
#include 'tlpp-probat.th'

namespace       test.<area>          // namespace de teste (ex.: test.cotacao)
using namespace tlpp.probat          // permite chamar asserts sem qualificar
```

## Dois estilos de fixture

### 1. Estilo função (simples, 1 teste por função)

```tlpp
#include 'tlpp-probat.th'
namespace test.tlpp

@TestFixture(owner='sample', target="sample_ok.tlpp")
function U_test_soma()
  local nRet := tlpp.U_soma(2, 3)
  tlpp.probat.assertEquals( nRet, 5, 'soma(2,3) deve ser 5' )
return .T.
```

> ⚠️ O estilo função usa a palavra-chave `function` (exigida pelo runner ProBat). É a **única** exceção tolerada à regra "`Function` é proibido" do CLAUDE.md, e **apenas em fontes de teste**. Para alinhar com o CLAUDE.md, **prefira o estilo classe** abaixo (usa `class`/`method`).

### 2. Estilo classe (preferido — setup/teardown + vários testes)

```tlpp
#include 'tlpp-core.th'
#include 'tlpp-probat.th'
namespace test.cotacao
using namespace tlpp.probat

@TestFixture(suite="cotacao")
class test_minhaRegra
  private data nBase as numeric
  public  method new() constructor

  @OneTimeSetUp()
  public method prepara()           // 1x antes de todos os testes

  @Setup()
  public method antesDeCada()        // antes de cada @Test

  @Test('descricao do caso')
  public method test01_caso()

  @TearDown()
  public method depoisDeCada()       // depois de cada @Test

  @OneTimeTearDown()
  public method encerra()            // 1x ao final
endclass

method new() class test_minhaRegra
  ::nBase := 0
return self

method prepara() class test_minhaRegra
  ::nBase := 10
  assertTrue( ::nBase > 0, 'base preparada' )
return .T.

method test01_caso() class test_minhaRegra
  assertEquals( ::nBase + 5, 15, 'soma com a base' )
return .T.
```

> **Declaração x implementação** (regra do CLAUDE.md): modificadores (`public`/`private`) e `@Test`/`@Setup` ficam **só na declaração** (dentro de `class`/`endclass`); a implementação usa `method nome() class X`, sem modificadores. Métodos com parâmetro: declarar com `()` vazio, parâmetros só na implementação.

## API de asserção (namespace `tlpp.probat`)

| Assert | Uso |
|---|---|
| `assertEquals(atual, esperado [, desc])` | igualdade |
| `assertNotEquals(a, b [, desc])` | diferença |
| `assertTrue(lExpr [, desc])` / `assertFalse(lExpr [, desc])` | lógico |
| `assertGreater(n, lim [, desc])` / `assertGreaterOrEqual(...)` | maior / maior-igual |
| `assertLess(n, lim [, desc])` / `assertLessOrEqual(...)` | menor / menor-igual |
| `assertNil([x ,] desc)` | valor nulo |
| `assertVector(aA, aB [, desc])` | arrays iguais |
| `assertJson(oJson, oJsonOuString [, desc])` | JSON iguais |
| `assertIsContained(cValor, cParte [, desc])` | substring contida |
| `assertIsRegExFull(c, cRegex [, desc])` / `assertIsRegExPartial(...)` | regex total / parcial |
| `assertOK(desc)` / `assertError(desc)` / `assertWarning(desc)` | resultado forçado / aviso |

Todo método de teste retorna `.T.`.

## Convenções deste projeto

- **Local dos testes:** `server/test/<area>/test_<alvo>.tlpp` (ex.: [`server/test/cotacao/test_nfcQuoteModel.tlpp`](../../../server/test/cotacao/test_nfcQuoteModel.tlpp) — exemplo real validando o helper NFCA020).
- **Encoding:** preferir **comentários ASCII** (sem acento) em fontes de teste — evita corrupção CP-1252 e a etapa de conversão. Caso use acento, vale a regra geral (CP-1252).
- **Integração com ExecAuto/rotina automática (ex.: NFCA020):** o teste é de **integração** e **muta dados** — use um registro **sacrificial** de homologação, prepare o módulo no `@OneTimeSetUp` (`RpcSetEnv(cEmp, cFil,,,"COM")`) e libere no `@OneTimeTearDown` (`RpcClearEnv()`). Leia campos **memo** (ex.: `C8_OBSFOR`) pela work-area (`FieldGet`), não no `SELECT`.
- **Compilação:** compilar o(s) fonte(s) sob teste **antes** do teste. Sem CLI — usar a skill `advpl-tlpp-compile` (TDS).
- **Execução:** rodar pelo **runner ProBat** do TDS/AppServer (descobre os fixtures pelas anotações). Confirme o mecanismo de run do seu ambiente na doc oficial.

## Referência detalhada

Para o conjunto completo (lifecycle, exemplos de função/classe/DB, gotchas e links oficiais), ver:
[`references/probat-reference.md`](references/probat-reference.md).

## Fontes oficiais

- Repositório de exemplos: https://github.com/totvs/tlpp-probat-samples
- TDN PROBAT: https://tdn.totvs.com/display/tec/PROBAT
- TDN Asserts: https://tdn.totvs.com/display/tec/d+-+Asserts
- TDN (função/fixture): https://tdn.totvs.com/pages/viewpage.action?pageId=654948020
