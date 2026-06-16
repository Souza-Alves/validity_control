import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'supabase/supabase_client.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';
import 'theme/app_theme.dart';
import 'screens/produtos_screen.dart';
import 'screens/locais_screen.dart';
import 'screens/cadastro_screen.dart';
import 'screens/importar_screen.dart';
import 'screens/exportar_screen.dart';
import 'screens/configuracao_screen.dart';

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
      theme: AppTheme.light,
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
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/market4u.png', width: 200, height: 200),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Controle de Validades',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Gerenciamento de Vencimentos',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, color: AppColors.splashSubtitle),
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
  final _produtosScreenKey = GlobalKey<ProdutosScreenState>();
  final _cadastroScreenKey = GlobalKey<CadastroScreenState>();

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

  // Indice do item selecionado na barra inferior (Importar/Exportar -> "Dados").
  int get _selectedNavIndex {
    switch (_currentIndex) {
      case 0:
      case 1:
      case 2:
        return _currentIndex;
      case 3: // Importar
      case 4: // Exportar
        return 3; // Dados
      default: // 5 Configuracao
        return 4;
    }
  }

  void _onNavTap(int navIndex) {
    switch (navIndex) {
      case 0:
        setState(() => _currentIndex = 0);
        _produtosScreenKey.currentState?.refresh();
        break;
      case 1:
        setState(() => _currentIndex = 1);
        break;
      case 2:
        setState(() => _currentIndex = 2);
        _cadastroScreenKey.currentState?.refresh();
        break;
      case 3:
        _showDadosMenu();
        break;
      default: // Config
        setState(() => _currentIndex = 5);
        break;
    }
  }

  Future<void> _showDadosMenu() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Dados',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: AppColors.primary),
              title: const Text('Importacao'),
              onTap: () => Navigator.pop(ctx, 3),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share, color: AppColors.primary),
              title: const Text('Exportar'),
              onTap: () => Navigator.pop(ctx, 4),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _currentIndex = selected);
    }
  }

  static const _titles = [
    'Produtos',
    'Locais',
    'Novo Produto',
    'Importar Excel',
    'Exportar',
    'Configuracao',
  ];

  late final List<Widget> _screens = <Widget>[
    ProdutosScreen(key: _produtosScreenKey),
    const LocaisScreen(),
    CadastroScreen(key: _cadastroScreenKey),
    const ImportarScreen(),
    const ExportarScreen(),
    const ConfiguracaoScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Row(
          children: [
            Image.asset(
              'assets/market4u.png',
              width: 140,
              height: 50,
              fit: BoxFit.contain,
            ),
            const Spacer(),
            Text(_titles[_currentIndex], style: AppTextStyles.appBarTitle),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_offline)
            Container(
              width: double.infinity,
              color: AppColors.offline,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Text(
                'Problemas na conexao. As alteracoes serao realizadas offline e '
                'adicionadas posteriormente quando houver conexao na base.',
                style: AppTextStyles.offlineBanner,
              ),
            ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: _onNavTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.primary,
        selectedItemColor: AppColors.white,
        unselectedItemColor: AppColors.navUnselected,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Produtos'),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Locais'),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Cadastrar'),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Dados'),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Config'),
        ],
      ),
    );
  }
}
