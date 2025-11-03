// --- ARQUIVO: test_logic.dart (FINAL) ---

// Importações (Ajuste o caminho para 'src' se necessário: ../src/...)
import '../src/modelos.dart';
import '../src/calculos.dart';
import '../src/servicos.dart';

// ----------------------------------------------------------------------
// DADOS DE TESTE COMUNS
// ----------------------------------------------------------------------

final alice = Usuario(
  id: 'u1',
  nome: 'Alice',
  email: 'a@a.com',
  senhaHash: 'hash',
);
final bob = Usuario(id: 'u2', nome: 'Bob', email: 'b@b.com', senhaHash: 'hash');
final carol = Usuario(
  id: 'u3',
  nome: 'Carol',
  email: 'c@c.com',
  senhaHash: 'hash',
);
final todosUsuarios = [alice, bob, carol];

// Função auxiliar para inicializar a base de dados
void inicializarAmbiente() {
  ServicoAutenticacao.cadastrarUsuario(
    nome: 'Alice',
    email: 'a@a.com',
    senha: '1',
  );
  ServicoAutenticacao.cadastrarUsuario(
    nome: 'Bob',
    email: 'b@b.com',
    senha: '1',
  );
  ServicoAutenticacao.cadastrarUsuario(
    nome: 'Carol',
    email: 'c@c.com',
    senha: '1',
  );
}

// ----------------------------------------------------------------------
// TESTE 1: VALIDAÇÃO DE DIVISÃO CUSTOMIZADA (Módulo 1.2)
// Objetivo: Garantir que a validação de soma falhe corretamente.
// ----------------------------------------------------------------------
void testarValidacaoCustomizada() {
  print('\n--- TESTE 1: VALIDAÇÃO DE DIVISÃO CUSTOMIZADA ---');

  // Cenário de FALHA: Valor total 100,00, mas a soma customizada é 99,00.
  final detalhesInvalidos = {'u1': 49.00, 'u2': 50.00};

  // O ServicoDespesas tentará validar a soma antes de criar a despesa
  final despesaFalha = ServicoDespesas.criarNovaDespesa(
    descricao: 'Falha',
    valorTotal: 100.00,
    usuarioPagadorId: 'u1',
    participantesIds: ['u1', 'u2'],
    dataDespesa: DateTime.now(),
    grupoId: 'g1',
    tipoDivisao: TipoDivisao.valoresCustomizados,
    categoriaNome: 'Outros',
    detalhesDivisao: detalhesInvalidos,
  );

  if (despesaFalha == null) {
    print('Status: PASSOU (Salvamento foi bloqueado por soma incorreta)');
  } else {
    print('Status: FALHOU (Salvamento não foi bloqueado)');
  }
}

// ----------------------------------------------------------------------
// TESTE 2: LIQUIDAÇÃO GLOBAL E SIMPLIFICAÇÃO (Módulo 1.3 e 2.2)
// Objetivo: Testar a integração entre a Despesa, o pagamento Global e a Simplificação final.
// ----------------------------------------------------------------------
void testarLiquidacaoGlobal() {
  print('\n--- TESTE 2: LIQUIDAÇÃO GLOBAL E SIMPLIFICAÇÃO ---');

  // Despesa: Bob pagou R$ 60,00 para ele e Alice (R$ 30,00 cada)
  final despesa =
      ServicoDespesas.criarNovaDespesa(
            descricao: 'Teste',
            valorTotal: 60.00,
            usuarioPagadorId: 'u2', // Bob pagou
            participantesIds: ['u1', 'u2'],
            dataDespesa: DateTime.now(),
            grupoId: 'g2',
            tipoDivisao: TipoDivisao.igualitaria,
            categoriaNome: 'Outros',
          )!
          as Despesa;

  // Alice (u1) deve R$ 30,00 para Bob (u2).

  // Liquidação: Alice paga R$ 10,00 Globalmente para Bob (Módulo 4.4)
  final liquidacaoGlobal = ServicoLiquidacao.marcarComoPago(
    devedorId: 'u1',
    credorId: 'u2',
    valor: 10.00,
    grupoId: null, // GLOBAL
  )!;

  // CÁLCULO
  final saldos = CalculadoraDividas.calcularSaldosIniciais(
    [despesa],
    todosUsuarios,
    [liquidacaoGlobal],
  );

  // EXPECTATIVA: Saldo Bob era +30. Recebe -10 (liquidação). Final: +20. Alice: -30 + 10. Final: -20.
  final transacoes = CalculadoraDividas.simplificarDividas(saldos);

  // Deve haver 1 transação: Alice deve R$ 20,00 para Bob.
  if (transacoes.length == 1 &&
      transacoes.first.devedorId == 'u1' &&
      transacoes.first.valor.toStringAsFixed(2) == '20.00') {
    print('Status: PASSOU (Liquidação Global e Simplificação Corretas)');
  } else {
    print('Status: FALHOU (Simplificação/Cálculo Final Incorreto)');
  }
}

// ----------------------------------------------------------------------
// TESTE 3: RELATÓRIOS E CATEGORIZAÇÃO (Módulo 2.3 e 3.2)
// Objetivo: Testar a agregação de gastos por categoria e métricas por usuário.
// ----------------------------------------------------------------------
void testarRelatoriosECategorizacao() {
  print('\n--- TESTE 3: RELATÓRIOS E CATEGORIZAÇÃO ---');

  // Despesa A (Alimentacao): R$ 100,00. Pago por Alice.
  final despesaA =
      ServicoDespesas.criarNovaDespesa(
            descricao: 'Jantar',
            valorTotal: 100.00,
            usuarioPagadorId: 'u1',
            participantesIds: ['u1', 'u2'],
            dataDespesa: DateTime.now(),
            grupoId: 'g1',
            tipoDivisao: TipoDivisao.igualitaria,
            categoriaNome: 'Alimentacao',
          )!
          as Despesa;

  // Despesa B (Transporte): R$ 200,00. Pago por Bob.
  final despesaB =
      ServicoDespesas.criarNovaDespesa(
            descricao: 'Uber',
            valorTotal: 200.00,
            usuarioPagadorId: 'u2',
            participantesIds: ['u1', 'u2'],
            dataDespesa: DateTime.now(),
            grupoId: 'g1',
            tipoDivisao: TipoDivisao.igualitaria,
            categoriaNome: 'Transporte',
          )!
          as Despesa;

  final todasDespesas = [despesaA, despesaB];

  // A. TESTE DE CATEGORIAS (Módulo 2.3)
  final relatorioCategoria = GeradorRelatorios.gerarRelatorioPorCategoria(
    todasDespesas,
  );

  final totalAlimentacao = relatorioCategoria['Alimentacao']!.toStringAsFixed(
    2,
  );
  final totalTransporte = relatorioCategoria['Transporte']!.toStringAsFixed(2);

  // B. TESTE DE MÉTRICAS POR USUÁRIO (Módulo 3.2)
  final metricas = GeradorRelatorios.gerarMetricasPorUsuario(
    despesasDoGrupo: todasDespesas,
    membrosDoGrupo: [alice, bob],
  );

  final alicePago = metricas['u1']!['Pago']!.toStringAsFixed(2);
  final bobPago = metricas['u2']!['Pago']!.toStringAsFixed(2);

  if (totalAlimentacao == '100.00' &&
      bobPago == '200.00' &&
      alicePago == '100.00') {
    print('Status: PASSOU (Relatórios, Métricas e Categorias Corretos)');
  } else {
    print('Status: FALHOU (Erro na agregação dos relatórios)');
  }
}

// ----------------------------------------------------------------------
// EXECUTAR TODOS OS TESTES
// ----------------------------------------------------------------------
void main() {
  inicializarAmbiente();
  testarValidacaoCustomizada();
  testarLiquidacaoGlobal();
  testarRelatoriosECategorizacao();
}
