import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'supabase/supabase_client.dart';
import 'screens/produtos_screen.dart';
import 'screens/locais_screen.dart';
import 'screens/cadastro_screen.dart';
import 'screens/importar_screen.dart';
import 'screens/exportar_screen.dart';
import 'screens/configuracao_screen.dart';

const kPrimaryColor = Color(0xFF7CB24B);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initSupabase();
  } catch (_) {
    // Sem rede no boot: o app abre em modo offline e sincroniza depois.
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle de Validades',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimaryColor),
        useMaterial3: true,
      ),
      home: const SplashWrapper(),
    );
  }
}

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: const Color(0xFF7CB24B),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/market4u.png', width: 200, height: 200),
              const SizedBox(height: 24),
              const Text(
                'Controle de Validades',
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 14),
              const Text(
                'Gerenciamento de Vencimentos',
                style: TextStyle(fontSize: 24, color: Color(0xFFE8F5E9)),
              ),
            ],
          ),
        ),
      );
    }
    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() => _offline = results.contains(ConnectivityResult.none));
      }
    });
    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        setState(() => _offline = results.contains(ConnectivityResult.none));
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  static const _titles = [
    'Produtos',
    'Locais',
    'Novo Produto',
    'Importar Excel',
    'Exportar',
    'Configuracao',
  ];

  final _screens = <Widget>[
    const ProdutosScreen(),
    const LocaisScreen(),
    const CadastroScreen(),
    const ImportarScreen(),
    const ExportarScreen(),
    const ConfiguracaoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        title: Row(
          children: [
            Image.asset('assets/market4u.png',
                width: 140, height: 50, fit: BoxFit.contain),
            const Spacer(),
            Text(
              _titles[_currentIndex],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_offline)
            Container(
              width: double.infinity,
              color: const Color(0xFFFF9800),
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Text(
                'Problemas na conexao. As alteracoes serao realizadas offline e '
                'adicionadas posteriormente quando houver conexao na base.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: kPrimaryColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFF353535),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
              icon: SizedBox.shrink(), label: 'Produtos'),
          BottomNavigationBarItem(
              icon: SizedBox.shrink(), label: 'Locais'),
          BottomNavigationBarItem(
              icon: SizedBox.shrink(), label: 'Cadastrar'),
          BottomNavigationBarItem(
              icon: SizedBox.shrink(), label: 'Importar'),
          BottomNavigationBarItem(
              icon: SizedBox.shrink(), label: 'Exportar'),
          BottomNavigationBarItem(
              icon: SizedBox.shrink(), label: 'Config'),
        ],
      ),
    );
  }
}
