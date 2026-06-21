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
import 'screens/relatorio_screen.dart';
import 'screens/top_vencidos_screen.dart';

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

  // Mapeia a tela atual para o item destacado na barra inferior.
  int get _selectedNavIndex {
    switch (_currentIndex) {
      case 0:
        return 0; // Produtos
      case 1: // Locais
      case 2: // Cadastro de produto
        return 1; // Cadastro
      case 3: // Importar
      case 4: // Exportar
        return 2; // Dados
      case 6: // Relatorio Geral
      case 7: // Top Vencidos
        return 3; // Relatorios
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
        _showCadastroMenu();
        break;
      case 2:
        _showDadosMenu();
        break;
      case 3:
        _showRelatoriosMenu();
        break;
      default: // Config
        setState(() => _currentIndex = 5);
        break;
    }
  }

  Future<void> _showSubmenu(String title, List<_SubmenuItem> items) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
            for (final item in items)
              ListTile(
                leading: Icon(item.icon, color: AppColors.primary),
                title: Text(item.label),
                onTap: () => Navigator.pop(ctx, item.screenIndex),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _currentIndex = selected);
      if (selected == 2) _cadastroScreenKey.currentState?.refresh();
    }
  }

  Future<void> _showCadastroMenu() => _showSubmenu('Cadastro', const [
    _SubmenuItem(Icons.inventory_2, 'Produtos', 2),
    _SubmenuItem(Icons.location_on, 'Locais', 1),
  ]);

  Future<void> _showDadosMenu() => _showSubmenu('Dados', const [
    _SubmenuItem(Icons.upload_file, 'Importacao', 3),
    _SubmenuItem(Icons.ios_share, 'Exportar', 4),
  ]);

  Future<void> _showRelatoriosMenu() => _showSubmenu('Relatorios', const [
    _SubmenuItem(Icons.assessment, 'Geral', 6),
    _SubmenuItem(Icons.emoji_events, 'Top Vencidos', 7),
  ]);

  static const _titles = [
    'Produtos',
    'Locais',
    'Novo Produto',
    'Importar Excel',
    'Exportar',
    'Configuracao',
    'Relatorio',
    'Top Vencidos',
  ];

  late final List<Widget> _screens = <Widget>[
    ProdutosScreen(key: _produtosScreenKey),
    const LocaisScreen(),
    CadastroScreen(key: _cadastroScreenKey),
    const ImportarScreen(),
    const ExportarScreen(),
    const ConfiguracaoScreen(),
    const RelatorioScreen(),
    const TopVencidosScreen(),
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
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Cadastro'),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Dados'),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Relatórios'),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: 'Config'),
        ],
      ),
    );
  }
}

/// Item de um submenu da barra inferior (Cadastro / Dados).
class _SubmenuItem {
  final IconData icon;
  final String label;
  final int screenIndex;

  const _SubmenuItem(this.icon, this.label, this.screenIndex);
}
