import 'modelos.dart';
import 'calculos.dart';

// FUNÇÃO AUXILIAR DE HASHING
String _gerarSenhaHash(String senha) {
  // Simulação de hashing seguro para Autenticação Real
  return 'BCRYPT_HASH_DE_VERDADE_${senha.hashCode}';
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

// SERVIÇO DE GESTÃO DE DESPESAS
class ServicoDespesas {
  static Despesa? criarNovaDespesa({
    required String descricao,
    required double valorTotal,
    required String usuarioPagadorId,
    required List<String> participantesIds,
    required DateTime dataDespesa,
    required String grupoId,
    required TipoDivisao tipoDivisao,
    required String categoriaNome,
    required int totalParcelas,
    required int parcelasPagas,
    Map<String, double>? detalhesDivisao,
  }) {
    final double valorParcela = totalParcelas > 0
        ? (valorTotal / totalParcelas)
        : valorTotal;

    if (tipoDivisao == TipoDivisao.valoresCustomizados &&
        detalhesDivisao != null) {
      final isValid = CalculadoraDividas.validarSomaCustomizada(
        valorTotal,
        detalhesDivisao,
      );
      if (!isValid) {
        return null;
      }
    }

    final novaDespesa = Despesa(
      descricao: descricao,
      valorTotal: valorTotal,
      usuarioPagadorId: usuarioPagadorId,
      participantesIds: participantesIds,
      dataDespesa: dataDespesa,
      grupoId: grupoId,
      tipoDivisao: tipoDivisao,
      categoriaNome: categoriaNome,
      detalhesDivisao: detalhesDivisao,
      totalParcelas: totalParcelas,
      parcelasPagas: parcelasPagas,
      valorParcela: valorParcela,
    );

    // SALVAR NO FIREBASE
    return novaDespesa;
  }
}

// SERVIÇO DE GESTÃO DE GRUPOS
class ServicoGrupos {
  static Grupo criarNovoGrupo({
    required String nome,
    required String criadorId,
  }) {
    final novoId = 'g_${DateTime.now().microsecondsSinceEpoch}';

    final novoGrupo = Grupo(
      id: novoId,
      nome: nome,
      membrosIds: [criadorId],
      despesasIds: [],
    );

    return novoGrupo;
  }

  static Grupo adicionarMembro({
    required Grupo grupoAtual,
    required String novoMembroId,
  }) {
    if (grupoAtual.membrosIds.contains(novoMembroId)) {
      return grupoAtual;
    }

    final novaListaMembros = List<String>.from(grupoAtual.membrosIds)
      ..add(novoMembroId);
    final grupoAtualizado = grupoAtual.copyWith(membrosIds: novaListaMembros);

    return grupoAtualizado;
  }
}

// SERVIÇO DE GESTÃO DE LIQUIDAÇÕES
class ServicoLiquidacao {
  static Liquidacao? marcarComoPago({
    required String devedorId,
    required String credorId,
    required double valor,
    String? grupoId,
    String? metodoPagamento,
  }) {
    if (valor <= 0) {
      return null;
    }

    final novoId = 'l_${DateTime.now().microsecondsSinceEpoch}';

    final novaLiquidacao = Liquidacao(
      id: novoId,
      devedorId: devedorId,
      credorId: credorId,
      valor: valor,
      dataLiquidacao: DateTime.now(),
      grupoId: grupoId,
      metodoPagamento: metodoPagamento,
    );

    // SALVAR NO FIREBASE
    return novaLiquidacao;
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
