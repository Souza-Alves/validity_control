int _lastId = 0;

/// Gera IDs numéricos monotônicos compatíveis com o tipo int8 do Supabase.
///
/// Base é o timestamp em ms * 1000; se vários IDs forem gerados no mesmo
/// milissegundo (ex.: import em massa de 91+ itens), apenas incrementamos
/// sobre o último ID. Garante unicidade independente de quantos sejam
/// gerados por ms — sem colisões e sem estouro de contador.
String generateId() {
  var id = DateTime.now().millisecondsSinceEpoch * 1000;
  if (id <= _lastId) id = _lastId + 1;
  _lastId = id;
  return id.toString();
}
