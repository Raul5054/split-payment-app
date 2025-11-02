// ENUMS
enum TipoDivisao { igualitaria, valoresCustomizados }

enum SugestaoCategoria { alimentacao, transporte, moradia, lazer, outros }

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
