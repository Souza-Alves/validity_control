class Produto {
  final String id;
  String localId;
  String localNome;
  int quantidade;
  String nome;
  String validade; // DD/MM/AAAA
  String situacao; // '' | 'Vendido' | 'Vencido'
  String status; // '' | 'Baixado' | 'Pendente'

  Produto({
    required this.id,
    required this.localId,
    required this.localNome,
    required this.quantidade,
    required this.nome,
    required this.validade,
    this.situacao = '',
    this.status = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'localId': localId,
    'localNome': localNome,
    'quantidade': quantidade,
    'nome': nome,
    'validade': validade,
    'situacao': situacao,
    'status': status,
  };

  factory Produto.fromJson(Map<String, dynamic> json) => Produto(
    id: json['id'] as String? ?? '',
    localId: json['localId'] as String? ?? '',
    localNome: json['localNome'] as String? ?? '',
    quantidade: (json['quantidade'] is int)
        ? json['quantidade'] as int
        : int.tryParse(json['quantidade']?.toString() ?? '0') ?? 0,
    nome: json['nome'] as String? ?? '',
    validade: json['validade'] as String? ?? '',
    situacao: json['situacao'] as String? ?? '',
    status: json['status'] as String? ?? '',
  );

  Produto copyWith({
    String? localId,
    String? localNome,
    int? quantidade,
    String? nome,
    String? validade,
    String? situacao,
    String? status,
  }) => Produto(
    id: id,
    localId: localId ?? this.localId,
    localNome: localNome ?? this.localNome,
    quantidade: quantidade ?? this.quantidade,
    nome: nome ?? this.nome,
    validade: validade ?? this.validade,
    situacao: situacao ?? this.situacao,
    status: status ?? this.status,
  );
}
