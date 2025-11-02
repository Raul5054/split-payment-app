enum TipoDivisao { igualitaria, valoresCustomizados }

enum SugestaoCategoria { alimentacao, transporte, moradia, lazer, outros }

// REPRESENTAÇÃO DE DESPESAS
class Despesa {
  final String descricao;
  final double valorTotal;
  final String usuarioPagadorId;
  final List<String> participantesIds;
  final DateTime dataDespesa;
  final TipoDivisao tipoDivisao;
  final Map<String, double>? detalhesDivisao;
  final String grupoId;
  final bool notificacaoNovaDividaEnviada;
  final bool despesaVisualmenteResolvida;
  final String categoriaNome;
  final int totalParcelas;
  final int parcelasPagas;
  final double valorParcela;

  Despesa({
    required this.descricao,
    required this.valorTotal,
    required this.usuarioPagadorId,
    required this.participantesIds,
    required this.dataDespesa,
    required this.grupoId,
    required this.tipoDivisao,
    this.detalhesDivisao,
    this.notificacaoNovaDividaEnviada = false,
    this.despesaVisualmenteResolvida = false,
    required this.categoriaNome,
    required this.totalParcelas,
    required this.parcelasPagas,
    required this.valorParcela,
  });

  // Método copyWith para facilitar a atualização de despesas
  Despesa copyWith({
    String? descricao,
    double? valorTotal,
    String? usuarioPagadorId,
    List<String>? participantesIds,
    DateTime? dataDespesa,
    String? grupoId,
    TipoDivisao? tipoDivisao,
    Map<String, double>? detalhesDivisao,
    bool? notificacaoNovaDividaEnviada,
    bool? despesaVisualmenteResolvida,
    String? categoriaNome,
    int? totalParcelas,
    int? parcelasPagas,
    double? valorParcela,
  }) {
    return Despesa(
      descricao: descricao ?? this.descricao,
      valorTotal: valorTotal ?? this.valorTotal,
      usuarioPagadorId: usuarioPagadorId ?? this.usuarioPagadorId,
      participantesIds: participantesIds ?? this.participantesIds,
      dataDespesa: dataDespesa ?? this.dataDespesa,
      grupoId: grupoId ?? this.grupoId,
      tipoDivisao: tipoDivisao ?? this.tipoDivisao,
      detalhesDivisao: detalhesDivisao ?? this.detalhesDivisao,
      notificacaoNovaDividaEnviada:
          notificacaoNovaDividaEnviada ?? this.notificacaoNovaDividaEnviada,
      despesaVisualmenteResolvida:
          despesaVisualmenteResolvida ?? this.despesaVisualmenteResolvida,
      categoriaNome: categoriaNome ?? this.categoriaNome,
      totalParcelas: totalParcelas ?? this.totalParcelas,
      parcelasPagas: parcelasPagas ?? this.parcelasPagas,
      valorParcela: valorParcela ?? this.valorParcela,
    );
  }
}

// CÁLCULOS DE DÍVIDAS E DIVISÕES
class CalculadoraDividas {
  // Calcula as cotas de cada participante com base no tipo de divisão da despesa
  static Map<String, double> calcularCotasPorDivisao(Despesa despesa) {
    final Map<String, double> cotas = {};

    if (despesa.participantesIds.isEmpty || despesa.valorTotal == 0) {
      return {};
    }

    switch (despesa.tipoDivisao) {
      case TipoDivisao.igualitaria:
        final double valorCota =
            despesa.valorTotal / despesa.participantesIds.length;
        for (final id in despesa.participantesIds) {
          cotas[id] = valorCota;
        }
        break;

      case TipoDivisao.valoresCustomizados:
        if (despesa.detalhesDivisao != null) {
          for (final id in despesa.participantesIds) {
            cotas[id] = despesa.detalhesDivisao![id] ?? 0.0;
          }
        }
        break;
    }

    return cotas;
  }

  // Calcula os saldos de cada usuário, incorporando parcelas e liquidações.
  static Map<String, double> calcularSaldosIniciais(
    List<Despesa> despesas,
    List<Usuario> usuarios,
    List<Liquidacao> liquidacoes,
  ) {
    final List<Despesa> despesasACalcular = [];

    for (var despesa in despesas) {
      if (despesa.totalParcelas > 1) {
        final parcelas = gerarParcelasVirtuais(despesa);
        despesasACalcular.addAll(parcelas);
      } else {
        despesasACalcular.add(despesa);
      }
    }

    final Map<String, double> saldos = {for (var u in usuarios) u.id: 0.0};

    for (var despesa in despesasACalcular) {
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

  // Valida se a soma dos valores customizados corresponde ao valor total da despesa.
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

  // Simplifica as dívidas entre usuários, retornando uma lista de transações necessárias.
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

    int i = 0; // Índice do devedor
    int j = 0; // Índice do credor

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

  // Calcula o saldo de um grupo específico com base nas despesas e usuários fornecidos.
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

  // Gera um relatório de despesas agrupadas por categoria.
  static Map<String, double> gerarRelatorioPorCategoria(
    List<Despesa> todasDespesas,
  ) {
    final Map<String, double> relatorio = {};

    for (var despesa in todasDespesas) {
      final String categoria = despesa.categoriaNome;
      final double valor = despesa.valorTotal;

      relatorio.update(
        categoria,
        (totalAtual) => totalAtual + valor,
        ifAbsent: () => valor,
      );
    }
    return relatorio;
  }

  // Gera parcelas virtuais para uma despesa parcelada
  static List<Despesa> gerarParcelasVirtuais(Despesa despesaOriginal) {
    final dataCorte = DateTime.now();
    final List<Despesa> parcelasVirtuais = [];

    DateTime dataParcela = despesaOriginal.dataDespesa;
    int parcelaNum = 1;

    while (parcelaNum <= despesaOriginal.totalParcelas) {
      if (dataParcela.isAfter(dataCorte) ||
          parcelaNum > despesaOriginal.parcelasPagas) {
        break;
      }

      final parcelaVirtual = despesaOriginal.copyWith(
        descricao: '${despesaOriginal.descricao} (Parc. $parcelaNum)',
        valorTotal: despesaOriginal.valorParcela,
        dataDespesa: dataParcela,
      );

      parcelasVirtuais.add(parcelaVirtual);

      dataParcela = DateTime(
        dataParcela.year,
        dataParcela.month + 1,
        dataParcela.day,
      );
      parcelaNum++;
    }

    return parcelasVirtuais;
  }
}

// SERVIÇO DE NOTIFICAÇÕES
class ServicoNotificacao {
  // Notificações de dívidas pendentes
  static List<Transacao> listarTodasDividasPendentes({
    required List<Despesa> todasDespesas,
    required List<Usuario> todosUsuarios,
    required List<Liquidacao> todasLiquidacoes,
  }) {
    final Map<String, double> saldosAgregados =
        CalculadoraDividas.calcularSaldosIniciais(
          todasDespesas,
          todosUsuarios,
          todasLiquidacoes,
        );

    return CalculadoraDividas.simplificarDividas(saldosAgregados);
  }

  // Notificações de nova despesa criada
  static List<String> listarUsuariosParaNotificacaoInstantanea({
    required Despesa novaDespesa,
  }) {
    final List<String> usuariosAnotificar = [];

    if (novaDespesa.notificacaoNovaDividaEnviada) {
      return [];
    }

    for (final id in novaDespesa.participantesIds) {
      final estaEnvolvido = novaDespesa.participantesIds.contains(id);
      final naoEPagador = novaDespesa.usuarioPagadorId != id;

      if (estaEnvolvido && naoEPagador) {
        usuariosAnotificar.add(id);
      }
    }

    return usuariosAnotificar;
  }
}

// REPRESENTAÇÃO DE USUÁRIOS
class Usuario {
  final String id;
  final String nome;
  final String email;
  final String senhaHash;
  final String? fotoUrl;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.senhaHash,
    this.fotoUrl,
  });
  // ... (copyWith se necessário)
}

// SERVIÇO DE AUTENTICAÇÃO
class ServicoAutenticacao {
  static final List<Usuario> _databaseUsuarios = [];

  static Usuario? cadastrarUsuario({
    required String nome,
    required String email,
    required String senha,
  }) {
    if (_databaseUsuarios.any((u) => u.email == email)) {
      return null;
    }

    final novoId = 'u${_databaseUsuarios.length + 1}';
    final senhaHash = 'HASH_${senha.hashCode}';

    final novoUsuario = Usuario(
      id: novoId,
      nome: nome,
      email: email,
      senhaHash: senhaHash,
    );

    _databaseUsuarios.add(novoUsuario);
    return novoUsuario;
  }

  static Usuario? logarUsuario({required String email, required String senha}) {
    final usuario = _databaseUsuarios.firstWhere(
      (u) => u.email == email,
      orElse: () => throw Exception('Usuário não encontrado'),
    );

    final senhaHashDigitada = 'HASH_${senha.hashCode}';

    if (usuario.senhaHash == senhaHashDigitada) {
      return usuario;
    } else {
      return null;
    }
  }
}

// REPRESENTA DE TRANSAÇÕES ENTRE USUÁRIOS
class Transacao {
  final String devedorId;
  final String credorId;
  final double valor;

  Transacao({
    required this.devedorId,
    required this.credorId,
    required this.valor,
  });

  @override
  String toString() {
    return '$devedorId deve R\$${valor.toStringAsFixed(2)} para $credorId';
  }
}

// REPRESENTAÇÃO DE GRUPOS DE USUÁRIOS
class Grupo {
  final String id;
  final String nome;
  final List<String> membrosIds;
  final List<String> despesasIds;

  Grupo({
    required this.id,
    required this.nome,
    required this.membrosIds,
    required this.despesasIds,
  });

  // Método copyWith para facilitar a atualização de grupos
  Grupo copyWith({
    String? nome,
    List<String>? membrosIds,
    List<String>? despesasIds,
  }) {
    return Grupo(
      id: this.id,
      nome: nome ?? this.nome,
      membrosIds: membrosIds ?? this.membrosIds,
      despesasIds: despesasIds ?? this.despesasIds,
    );
  }
}

// REPRESENTAÇÃO DE LIQUIDAÇÕES DE DÍVIDAS
class Liquidacao {
  final String id;
  final String devedorId;
  final String credorId;
  final double valor;
  final DateTime dataLiquidacao;
  final String? grupoId;
  final String? metodoPagamento;

  Liquidacao({
    required this.id,
    required this.devedorId,
    required this.credorId,
    required this.valor,
    required this.dataLiquidacao,
    this.grupoId,
    this.metodoPagamento,
  });
}

// GERADOR DE RELATÓRIOS E MÉTRICAS
class GeradorRelatorios {
  // Gera métricas de despesas por usuário em um grupo
  static Map<String, Map<String, double>> gerarMetricasPorUsuario({
    required List<Despesa> despesasDoGrupo,
    required List<Usuario> membrosDoGrupo,
  }) {
    final Map<String, Map<String, double>> metricas = {};

    for (var usuario in membrosDoGrupo) {
      metricas[usuario.id] = {'Pago': 0.0, 'Devido': 0.0};
    }

    for (var despesa in despesasDoGrupo) {
      final cotasDevidas = CalculadoraDividas.calcularCotasPorDivisao(despesa);

      final pagadorId = despesa.usuarioPagadorId;
      metricas[pagadorId]?['Pago'] =
          (metricas[pagadorId]?['Pago'] ?? 0.0) + despesa.valorTotal;

      for (final id in despesasDoGrupo.first.participantesIds) {
        final valorDevido = cotasDevidas[id] ?? 0.0;
        metricas[id]?['Devido'] =
            (metricas[id]?['Devido'] ?? 0.0) + valorDevido;
      }
    }

    return metricas;
  }

  // Gera um histórico temporal de despesas para um grupo específico
  static Map<String, double> gerarHistoricoTemporal({
    required List<Despesa> todasDespesas,
    required String grupoId,
  }) {
    final Map<String, double> historico = {};

    final despesasDoGrupo = todasDespesas
        .where((d) => d.grupoId == grupoId)
        .toList();

    for (var despesa in despesasDoGrupo) {
      final ano = despesa.dataDespesa.year.toString();
      final mes = despesa.dataDespesa.month.toString().padLeft(2, '0');
      final chaveTempo = '$ano-$mes';
      final valor = despesa.valorTotal;

      historico.update(
        chaveTempo,
        (totalAtual) => totalAtual + valor,
        ifAbsent: () => valor,
      );
    }
    return historico;
  }
}
