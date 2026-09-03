import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _idx = 0;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      icon: '💰',
      title: 'Bienvenue dans Carnet Livreur',
      subtitle: 'L\'application pensée pour les livreurs Uber Eats, Deliveroo et plus.',
      color: AppColors.brand,
    ),
    _OnboardingPage(
      icon: '📊',
      title: 'Suis tes revenus en temps réel',
      subtitle: 'Saisie rapide des livraisons, calcul automatique URSSAF, suivi des frais de virement.',
      color: AppColors.success,
    ),
    _OnboardingPage(
      icon: '🎯',
      title: 'Atteins tes objectifs',
      subtitle: 'Définis un objectif mensuel, suis ta progression, gère les factures récurrentes.',
      color: AppColors.warning,
    ),
    _OnboardingPage(
      icon: '🔒',
      title: '100% privé et local',
      subtitle: 'Tes données restent sur ton téléphone. Aucun compte requis, aucune connexion serveur.',
      color: AppColors.brand,
    ),
  ];

  void _next() {
    if (_idx < _pages.length - 1) {
      _ctrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_idx < _pages.length - 1)
                    TextButton(
                      onPressed: _complete,
                      child: Text('Passer', style: TextStyle(color: context.textSecondary)),
                    )
                  else
                    const SizedBox(width: 60),
                  TextButton(
                    onPressed: _complete,
                    child: const Text('Passer', style: TextStyle(color: Colors.transparent)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _idx = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) => _buildPage(_pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _idx ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _idx ? _pages[_idx].color : context.borderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_idx].color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _idx == _pages.length - 1 ? 'Commencer 🚀' : 'Suivant',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: p.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(p.icon, style: const TextStyle(fontSize: 80))),
          ),
          const SizedBox(height: 40),
          Text(
            p.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            p.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: context.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  const _OnboardingPage({required this.icon, required this.title, required this.subtitle, required this.color});
}
