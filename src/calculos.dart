import 'modelos.dart';

// CÁLCULOS DE DÍVIDAS E DIVISÕES
class CalculadoraDividas {
  // Calcula as cotas de cada participante com base no tipo de divisão
  static Map<String, double> calcularCotasPorDivisao(Despesa despesa) {
    final Map<String, double> cotas = {};

    if (despesa.participantesIds.isEmpty || despesa.valorTotal == 0) {
      return {};
    }

    if (despesa.tipoDivisao == TipoDivisao.igualitaria) {
      final double valorCota =
          despesa.valorTotal / despesa.participantesIds.length;
      for (final id in despesa.participantesIds) {
        cotas[id] = valorCota;
      }
    } else if (despesa.tipoDivisao == TipoDivisao.valoresCustomizados) {
      if (despesa.detalhesDivisao != null) {
        for (final id in despesa.participantesIds) {
          cotas[id] = despesa.detalhesDivisao![id] ?? 0.0;
        }
      }
    }

    return cotas;
  }

  // Calcula os saldos de cada usuário
  static Map<String, double> calcularSaldosIniciais(
    List<Despesa> despesas,
    List<Usuario> usuarios,
    List<Liquidacao> liquidacoes,
  ) {
    final Map<String, double> saldos = {for (var u in usuarios) u.id: 0.0};

    for (var despesa in despesas) {
      final Map<String, double> cotasDevidas = calcularCotasPorDivisao(despesa);

      final String pagadorId = despesa.usuarioPagadorId;
      saldos[pagadorId] = (saldos[pagadorId] ?? 0.0) + despesa.valorTotal;

      for (var idParticipante in despesa.participantesIds) {
        final double valorDevido = cotasDevidas[idParticipante] ?? 0.0;
        saldos[idParticipante] = (saldos[idParticipante] ?? 0.0) - valorDevido;
      }
    }

    for (var liquidacao in liquidacoes) {
      saldos[liquidacao.credorId] =
          (saldos[liquidacao.credorId] ?? 0.0) - liquidacao.valor;
      saldos[liquidacao.devedorId] =
          (saldos[liquidacao.devedorId] ?? 0.0) + liquidacao.valor;
    }

    return saldos;
  }

  // Simplifica as dívidas
  static List<Transacao> simplificarDividas(
    Map<String, double> saldosIniciais,
  ) {
    final List<Transacao> transacoes = [];
    final List<MapEntry<String, double>> credores = [];
    final List<MapEntry<String, double>> devedores = [];

    saldosIniciais.forEach((id, saldo) {
      if (saldo > 0.001) {
        credores.add(MapEntry(id, saldo));
      } else if (saldo < -0.001) {
        devedores.add(MapEntry(id, saldo.abs()));
      }
    });

    int i = 0; // Índice para devedores
    int j = 0; // Índice para credores

    while (i < devedores.length && j < credores.length) {
      final String devedorId = devedores[i].key;
      final double debito = devedores[i].value;

      final String credorId = credores[j].key;
      final double credito = credores[j].value;

      final double valorTransferido = debito < credito ? debito : credito;

      transacoes.add(
        Transacao(
          devedorId: devedorId,
          credorId: credorId,
          valor: valorTransferido,
        ),
      );

      devedores[i] = MapEntry(devedorId, debito - valorTransferido);
      credores[j] = MapEntry(credorId, credito - valorTransferido);

      if (devedores[i].value < 0.001) {
        i++;
      }
      if (credores[j].value < 0.001) {
        j++;
      }
    }

    return transacoes;
  }

  // Valida a soma customizada
  static bool validarSomaCustomizada(
    double valorTotal,
    Map<String, double> detalhesDivisao,
  ) {
    double somaValores = detalhesDivisao.values.fold(
      0.0,
      (soma, valor) => soma + valor,
    );
    const double margemErro = 0.001;
    double diferenca = (valorTotal - somaValores).abs();

    return diferenca < margemErro;
  }

  // Calcula o saldo de um grupo específico
  static Map<String, double> calcularSaldoDeGrupo({
    required Grupo grupo,
    required List<Despesa> todasDespesas,
    required List<Usuario> todosUsuarios,
    required List<Liquidacao> todasLiquidacoes,
  }) {
    final List<Despesa> despesasDoGrupo = todasDespesas
        .where((d) => d.grupoId == grupo.id)
        .toList();

    final List<Usuario> membrosDoGrupo = todosUsuarios
        .where((u) => grupo.membrosIds.contains(u.id))
        .toList();

    final List<Liquidacao> liquidacoesRelevantes = todasLiquidacoes
        .where((l) => l.grupoId == grupo.id || l.grupoId == null)
        .toList();

    return calcularSaldosIniciais(
      despesasDoGrupo,
      membrosDoGrupo,
      liquidacoesRelevantes,
    );
  }
}
