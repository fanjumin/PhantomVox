import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/flow_graph_page.dart';
import 'pages/agent_page.dart';
import 'pages/storycut_page.dart';
import 'pages/pro_edit_page.dart';
import 'pages/palette_page.dart';
import 'pages/audioforge_page.dart';
import 'pages/effectlab_page.dart';

void main() {
  runApp(const PhantomVoxApp());
}

class PhantomVoxApp extends StatelessWidget {
  const PhantomVoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhantomVox AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF6C63FF),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      home: const MainShell(),
    );
  }
}

/// Main shell with scrollable workspace navigation
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final _scrollCtrl = ScrollController();

  final _pages = const [
    FlowGraphPage(),
    AgentPage(),
    StoryCutPage(),
    ProEditPage(),
    PalettePage(),
    AudioForgePage(),
    EffectLabPage(),
    HomePage(),
  ];

  final _labels = [
    'Flow Graph',
    'AI Agent',
    'StoryCut',
    'ProEdit',
    'Palette',
    'AudioForge',
    'EffectLab',
    'Dashboard',
  ];

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Scrollable workspace switcher bar
          Container(
            height: 32,
            color: const Color(0xFF0D0D1A),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Text('PhantomVox',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_labels.length, (i) {
                        final active = i == _currentIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _currentIndex = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: active
                                      ? const Color(0xFF6C63FF)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              _labels[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: active ? Colors.white : Colors.grey,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Page content
          Expanded(child: _pages[_currentIndex]),
        ],
      ),
    );
  }
}
