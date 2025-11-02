String _gerarSenhaHash(String senha) {
  // Apenas uma simulação para manter o código puro.
  return 'BCRYPT_HASH_DE_VERDADE_${senha.hashCode}';
}

// ENUMS
enum TipoDivisao { igualitaria, valoresCustomizados }

enum SugestaoCategoria { alimentacao, transporte, moradia, lazer, outros }

// =======================================================
// MODELOS DE DADOS CENTRAIS
// =======================================================

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
  final String categoriaNome;

  // Campos para despesas parceladas
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
    required this.categoriaNome,
    required this.totalParcelas,
    required this.parcelasPagas,
    required this.valorParcela,
  });

  Despesa copyWith({
    String? descricao,
    double? valorTotal,
    String? usuarioPagadorId,
    List<String>? participantesIds,
    DateTime? dataDespesa,
    String? grupoId,
    TipoDivisao? tipoDivisao,
    Map<String, double>? detalhesDivisao,
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
      categoriaNome: categoriaNome ?? this.categoriaNome,
      totalParcelas: totalParcelas ?? this.totalParcelas,
      parcelasPagas: parcelasPagas ?? this.parcelasPagas,
      valorParcela: valorParcela ?? this.valorParcela,
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

// =======================================================
// SERVIÇOS E LÓGICA
// =======================================================

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
    final senhaHash = _gerarSenhaHash(senha);

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

    final senhaHashDigitada = _gerarSenhaHash(senha);

    if (usuario.senhaHash == senhaHashDigitada) {
      return usuario;
    } else {
      return null;
    }
  }
}

// CÁLCULOS DE DÍVIDAS E DIVISÕES
class CalculadoraDividas {
  // Calcula as cotas de cada participante com base no tipo de divisão
  static Map<String, double> calcularCotasPorDivisao(Despesa despesa) {
    final Map<String, double> cotas = {};

    if (despesa.participantesIds.isEmpty || despesa.valorTotal == 0) {
      return {};
    }

    if (despesa.tipoDivisao case TipoDivisao.igualitaria) {
      final double valorCota =
          despesa.valorTotal / despesa.participantesIds.length;
      for (final id in despesa.participantesIds) {
        cotas[id] = valorCota;
      }
    } else if (despesa.tipoDivisao case TipoDivisao.valoresCustomizados) {
      if (despesa.detalhesDivisao != null) {
        for (final id in despesa.participantesIds) {
          cotas[id] = despesa.detalhesDivisao![id] ?? 0.0;
        }
      }
    }

    return cotas;
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

  // Calcula os saldos de cada usuário, incorporando parcelas e liquidações
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

  // Simplifica as dívidas entre usuários, retornando as transações mínimas
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

  // Valida se a soma dos valores customizados corresponde ao valor total
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

// SERVIÇO DE NOTIFICAÇÕES
class ServicoNotificacao {
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

  static List<String> listarUsuariosParaNotificacaoInstantanea({
    required Despesa novaDespesa,
  }) {
    final List<String> usuariosAnotificar = [];

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

// GERADOR DE RELATÓRIOS E MÉTRICAS
class GeradorRelatorios {
  static Map<String, double> gerarRelatorioPorCategoria(
    List<Despesa> todasDespesas,
  ) {
    final Map<String, double> relatorio = {};

    for (var despesa in todasDespesas) {
      // Nota: Esta função usa o valorTotal, o que pode dobrar a contagem de despesas parceladas.
      // Em uma refatoração avançada, esta função precisaria usar as 'Parcelas Virtuais'.
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

  // Gera métricas de despesas por usuário em um grupo
  static Map<String, Map<String, double>> gerarMetricasPorUsuario({
    required List<Despesa> despesasDoGrupo,
    required List<Usuario> membrosDoGrupo,
  }) {
    final Map<String, Map<String, double>> metricas = {};

    // Note: Em um app real, esta função também precisaria consolidar as despesas parceladas
    // usando CalculadoraDividas.gerarParcelasVirtuais para calcular 'Devido' corretamente.

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
