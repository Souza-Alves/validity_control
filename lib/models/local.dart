class Local {
  final String id;
  String nome;
  bool ativo;

  Local({required this.id, required this.nome, this.ativo = true});

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome, 'ativo': ativo};

  factory Local.fromJson(Map<String, dynamic> json) => Local(
        id: json['id'] as String? ?? '',
        nome: json['nome'] as String? ?? '',
        ativo: json['ativo'] == true || json['ativo'] == 'true',
      );
}
