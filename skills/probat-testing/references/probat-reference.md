# ProBat — Referência Detalhada (TLPP)

> Material extraído do repositório oficial **`totvs/tlpp-probat-samples`** (branch `main`) e da TDN. Use como base canônica; valide símbolos novos contra esses fontes.

---

## 1. Anatomia de um fonte de teste

```tlpp
#include 'tlpp-core.th'     // tipos/recursos TLPP
#include 'tlpp-probat.th'   // motor ProBat (asserts + anotacoes)

namespace       test.<area>
using namespace tlpp.probat  // chama asserts sem qualificar (assertEquals em vez de tlpp.probat.assertEquals)
```

- Sem `using namespace tlpp.probat`, chame qualificado: `tlpp.probat.assertEquals(...)`.
- O fonte sob teste é chamado pelo seu símbolo real (ex.: `tlpp.U_sampleOK(...)`, ou `portalaprovacao.utils.u_nfcEditQuote(...)`).

---

## 2. Anotações

| Anotação | Onde | Efeito |
|---|---|---|
| `@TestFixture(owner=, target=, suite=)` | função ou classe | marca o conjunto de testes. `owner`/`target`/`suite` são metadados opcionais (filtragem/relatório). |
| `@Test('descricao')` | método (estilo classe) | marca o método como caso de teste. |
| `@OneTimeSetUp()` | método | roda **1x** antes de todos os `@Test` da classe. |
| `@Setup()` | método | roda **antes de cada** `@Test`. |
| `@TearDown()` | método | roda **depois de cada** `@Test`. |
| `@OneTimeTearDown()` | método | roda **1x** após todos os `@Test`. |

Todo método de teste/lifecycle retorna `.T.`.

---

## 3. Estilo função (1 teste por função)

```tlpp
#include "tlpp-probat.th"
namespace test.tlpp

@TestFixture(owner='sample', target="sample_ok.tlpp")
function U_test_sample_function()
  local cTest     := 'test_1'
  local xValue    := tlpp.U_sampleOK( cTest )
  local xExpected := cTest
  tlpp.probat.assertEquals( xValue, xExpected, 'tlpp.U_sampleOK( cTest )' )
return .T.
```

- A função usa a palavra-chave `function` + nome com prefixo `U_` — **exigência do runner**. É a única exceção ao "`Function` proibido" do CLAUDE.md, **só em testes**. Prefira o estilo classe.

---

## 4. Estilo classe (preferido)

```tlpp
#include 'tlpp-core.th'
#include 'tlpp-probat.th'
namespace test.exemplo
using namespace tlpp.probat

@TestFixture(suite="exemplo")
class test_exemplo
  private data nValor as numeric
  public  method new() constructor

  @OneTimeSetUp()
  public method setUpAll()

  @Setup()
  public method setUp()

  @Test('valor dobrado')
  public method test01_dobro()

  @TearDown()
  public method tearDown()

  @OneTimeTearDown()
  public method tearDownAll()
endclass

method new() class test_exemplo
  ::nValor := 0
return self

method setUpAll() class test_exemplo
return .T.

method setUp() class test_exemplo
  ::nValor := 21
return .T.

method test01_dobro() class test_exemplo
  assertEquals( ::nValor * 2, 42, 'dobro de 21' )
return .T.

method tearDown() class test_exemplo
return .T.

method tearDownAll() class test_exemplo
return .T.
```

**Regra declaração x implementação (CLAUDE.md):**
- Na **declaração** (`class`/`endclass`): `public method x()` / `private method y()` + as anotações.
- Na **implementação**: `method x() class test_exemplo` (sem `public`/`private`/`@...`).
- Método com parâmetro: declaração `public method z()` (parênteses vazios); parâmetro **só** na implementação `method z(cArg as character) class ...`.

---

## 5. API de asserção completa

```tlpp
assertEquals(    'str', 'str'      , 'valores iguais'      )
assertNotEquals( 'str', 'str_diff' , 'valores diferentes'  )

assertOK(      'forca resultado positivo' )
assertError(   'forca resultado negativo' )   // quebra o teste
assertWarning( 'aviso, sem positivo nem negativo' )

assertTrue(  .T., 'logical true'  )
assertFalse( .F., 'logical false' )

assertGreater(        100, 99 , 'maior'        )
assertGreaterOrEqual( 100, 100, 'maior ou igual' )
assertLess(           100, 101, 'menor'        )
assertLessOrEqual(    100, 100, 'menor ou igual' )

assertIsRegExFull(    'So letras'        , '[A-Za-z ]+', 'regex total'   )
assertIsRegExPartial( '123 letras 456'   , '[A-Za-z ]+', 'regex parcial' )
assertIsContained(    'str_test', '_'    , 'contem substring' )

assertNil( , 'deve ser nulo' )

assertVector( {1,2,3,"4",Nil,6}, {1,2,3,"4",Nil,6}, 'vetores iguais' )

oJson1 := JsonObject():New() ; oJson1:fromJson( '{"key":"value"}' )
oJson2 := JsonObject():New() ; oJson2:fromJson( '{"key":"value"}' )
assertJson( oJson1, oJson2          , 'json objetos iguais'   )
assertJson( oJson1, '{"key":"value"}', 'json igual a string'  )
```

- O `desc` é opcional em vários asserts (ex.: `assertEquals(a, b)` válido), mas **sempre descreva** — facilita o diagnóstico no relatório.

---

## 6. Teste de integração com banco (padrão oficial)

O sample `test/integration/test_db.tlpp` cria uma tabela própria, faz CRUD e assere. Estrutura típica:

```tlpp
@TestFixture( suite="bd" )
class test_db
  private data nConn  as numeric
  private data cTable as character
  private data cAlias as character
  public  method new() constructor
  @OneTimeSetUp()    public method setConn()     // TcLink na conexao do .ini
  @Setup()           public method setTable()    // cria/abre tabela + carga
  @Test('update')    public method test01_update()
  @Test('insert')    public method test02_insert()
  @TearDown()        public method clearTable()  // DELETE FROM tabela
  @OneTimeTearDown() public method closeConn()   // TCUNLink
endclass
```

Conexão no `@OneTimeSetUp` (do sample):
```tlpp
cEnv := GetEnvServer() ; cIni := GetSrvIniName()
cDB  := GetPvProfString( cEnv, 'DBDATABASE', '', cIni )
cDsn := GetPvProfString( cEnv, 'DBALIAS'   , '', cIni )
cSrv := GetPvProfString( cEnv, 'DBSERVER'  , '', cIni )
nPort:= val( GetPvProfString( cEnv, 'DBPORT', '', cIni ) )
::nConn := TcLink( cDB+'/'+cDsn, cSrv, nPort )
assertGreaterOrEqual( 0, ::nConn, 'TcLink' )
```

Leitura/assert via query temporária:
```tlpp
cQry := 'SELECT * FROM ' + ::cTable
dbUseArea(.T., "TOPCONN", TCGenQry(NIL,NIL,cQry), (cAlias), .F., .T.)
  assertEquals( (cAlias)->ID, cNewID )
(cAlias)->( dbCloseArea() )
```

### Variante: testar rotina de módulo (ExecAuto / NFCA020)

Quando o alvo é uma **rotina de módulo** (não uma tabela genérica), prepare o **ambiente do módulo** em vez de `TcLink`:

```tlpp
method prepara() class test_minhaRotina
  RpcSetEnv( "02", "001001", , , "COM" )   // empresa, filial, modulo
  // ... descobrir/seed de um registro SACRIFICIAL ...
return .T.

method encerra() class test_minhaRotina
  RpcClearEnv()
return .T.
```

Exemplo real no projeto: [`server/test/cotacao/test_nfcQuoteModel.tlpp`](../../../server/test/cotacao/test_nfcQuoteModel.tlpp) — valida `u_nfcEditQuote`/`u_nfcNewProposal`/`u_nfcRejectQuote` (helper NFCA020) contra uma cotação real, lendo a SC8 de volta para asserir.

---

## 7. Execução (runner ProBat)

Compilar **não** executa os testes — é preciso um **runner** que dispara o motor ProBat. Padrão canônico (de `run/main.prw` do repo oficial):

```tlpp
#include 'tlpp-core.th'
User Function runTests()
    Local jModule := nil                                  as json
    Local cKey    := "RUN-" + StrTran(Time(), ":", "-")   as character
    If !tlpp.module('PROBAT', @jModule)                   // PROBAT instalado?
        ConOut("PROBAT nao instalado")
        Return
    EndIf
    tlpp.probat.discovery()                                          // descobre os @TestFixture (ASSINCRONO)
    Sleep(1500)                                                     // ESSENCIAL: aguardar a descoberta concluir
    tlpp.probat.run("custom:" + cKey)                               // roda TODOS os testes
    // ...ou apenas uma suite:
    // tlpp.probat.runOffCoverage("type:suite", "<suite>", "custom:" + cKey)
    Sleep(2000)                                                     // aguardar a execucao concluir
    tlpp.probat.export("type:custom", cKey)                         // exporta o resultado
Return
```

> **Gotcha de timing:** `discovery()` é assíncrono e coloca o motor em "discovery mode". Chamar `run`/`runOffCoverage` antes de concluir gera `ERROR < this function cannot be called in this discovery mode >`. Use `Sleep()` entre as etapas (como faz o `run/main.prw` oficial).

- Fluxo: compilar (alvo + testes + runner) → executar a UF do runner → ler o resultado no console (`ConOut`) e no relatório exportado (`protheus_data`).
- **TDS:** se a extensão `tds-vscode` expuser o painel de **Testes/ProBat**, os fixtures aparecem lá para rodar com 1 clique (alternativa ao runner manual).
- **Headless/CI:** o repo oficial traz `run/probat_run.sh` + `run/probat_config_{windows,linux}.sh` para execução via AppServer sem UI.

## 8. Gotchas

- **`function` em teste:** o estilo função exige `function U_test_...` (palavra-chave `function`). Use estilo classe para conformidade com o CLAUDE.md.
- **Campos memo** (ex.: `C8_OBSFOR`): não confie em `SELECT memo` via `TcQuery` — leia pela **work-area** (`SC8->(FieldGet(SC8->(FieldPos('C8_OBSFOR'))))`) após posicionar por `R_E_C_N_O_`.
- **Mutação de dados:** testes de integração que gravam (ExecAuto/MVC) **alteram o banco**. Use registros **sacrificiais** de homologação; quando possível, crie um registro descartável no teste e opere nele (evita destruir a base e acoplamento de ordem entre `@Test`).
- **Ordem dos `@Test`:** não assuma ordem garantida — torne cada teste **independente** (cada um cria/posiciona o que precisa).
- **Ambiente:** `RpcSetEnv(...,"COM")` valida o contexto de módulo headless (confirmado funcionando no AppServer). Sempre pareie com `RpcClearEnv()` no teardown.
- **Triggers MVC quebram headless:** ao testar um modelo `FwLoadModel`, `oGrid:SetValue(campo, val)` dispara o trigger do campo (X3_TRIGGER), que pode assumir contexto de tela e estourar `variable is not an object` (caso real: `NF020ATUCMPVAL` ao setar `C8_SITUAC` no NFCA020). Use **`oGrid:LoadValue(campo, val)`** para gravar **sem** disparar trigger/validação. (Validado em `server/test/cotacao/test_nfcQuoteModel.tlpp`.)
- **Compilar o alvo antes:** o fonte sob teste precisa estar no RPO antes de rodar o teste.

---

## 9. Caminhos dos exemplos oficiais (totvs/tlpp-probat-samples)

| Tema | Arquivo |
|---|---|
| Asserts (todos) | `test/probat_resources/test_sample_asserts.tlpp` |
| Teste estilo função | `test/probat_resources/test_sample_function.tlpp` |
| Teste estilo classe | `test/probat_resources/test_sample_class.tlpp` / `..._class_full.tlpp` |
| Integração com DB | `test/integration/test_db.tlpp` |
| Teste de REST | `test/api/test_rest_simples.tlpp` / `..._multiProtocol.tlpp` |
| Skip / error log | `test/probat_resources/test_sample_skip.tlpp` / `..._error_log.tlpp` |
| Suíte / agrupamento | `test/probat_resources/test_sample_suite.tlpp` |
| TDD | `test/tdd/tdd_sample_1.tlpp` / `tdd_sample_2.tlpp` |

## 10. Fontes oficiais

- https://github.com/totvs/tlpp-probat-samples
- https://tdn.totvs.com/display/tec/PROBAT
- https://tdn.totvs.com/display/tec/d+-+Asserts
- https://tdn.totvs.com/pages/viewpage.action?pageId=654948020
