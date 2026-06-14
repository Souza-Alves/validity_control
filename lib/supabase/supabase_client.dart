import 'package:supabase_flutter/supabase_flutter.dart';

// A anon key é pública por natureza (feita para ficar embutida no app cliente).
// Pode ser sobrescrita em build com --dart-define=SUPABASE_URL=... etc.
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://snmbifulthaouoywugrb.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNubWJpZnVsdGhhb3VveXd1Z3JiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA2MTE4NTksImV4cCI6MjA5NjE4Nzg1OX0.2IRdjrtx_GKBgEgmOfeGXwgAdBXUJ1bmhIJQj_Fsir0',
);

Future<void> initSupabase() async {
  // anonKey é a chave pública (publishable) do projeto.
  // ignore: deprecated_member_use
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
