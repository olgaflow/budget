import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppAboutDialog extends StatelessWidget {
  const AppAboutDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '1.0.0';
        final build = snapshot.data?.buildNumber ?? '1';
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('💰', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Carnet Livreur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Version $version ($build)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Carnet intelligent pour livreurs Uber Eats, Deliveroo et autres plateformes.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text('🚚 Suivi intelligent pour livreurs', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _row(context, Icons.check_circle_outline, 'Suivi des revenus et dépenses'),
                _row(context, Icons.check_circle_outline, 'Calcul automatique URSSAF'),
                _row(context, Icons.check_circle_outline, 'Gestion des factures récurrentes'),
                _row(context, Icons.check_circle_outline, 'Objectifs mensuels et épargne'),
                _row(context, Icons.check_circle_outline, 'Graphiques d\'évolution'),
                _row(context, Icons.check_circle_outline, 'Import CSV bancaire'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '⚠️ Cet outil est un aide-mémoire. Il ne remplace pas un service bancaire ou un cabinet comptable.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                      label: const Text('Confidentialité'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Mentions'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsScreen()));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class LegalScreen extends StatelessWidget {
  final String title;
  final Widget body;

  const LegalScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: body,
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalScreen(
      title: 'Politique de confidentialité',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Dernière mise à jour : janvier 2026', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          SizedBox(height: 16),
          Text('1. Données collectées', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Carnet Livreur ne collecte aucune donnée personnelle sur des serveurs externes. '
            'Toutes les informations que vous saisissez (revenus, dépenses, factures, objectifs) '
            'sont stockées uniquement sur votre appareil, dans le stockage local sécurisé de l\'application.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 16),
          Text('2. Aucun compte requis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'L\'application ne nécessite ni inscription, ni email, ni numéro de téléphone. '
            'Vous restez totalement anonyme.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 16),
          Text('3. Aucun partage de données', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Vos données ne sont jamais transmises à des tiers, à des annonceurs ou à des services d\'analyse. '
            'L\'application fonctionne entièrement hors-ligne.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 16),
          Text('4. Suppression des données', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Vous pouvez à tout moment supprimer toutes vos données depuis les paramètres de l\'application, '
            'ou en désinstallant l\'application.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 16),
          Text('5. Permissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            '• Internet (uniquement pour l\'ouverture de liens externes vers vos espaces bancaires)\n'
            '• Stockage local (pour vos données et l\'import de fichiers CSV)',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 16),
          Text('6. Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
            'Pour toute question : support@carnet-livreur.app',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warningBg = isDark ? const Color(0xFF78350F) : Colors.amber.shade50;
    final warningBorder = isDark ? const Color(0xFFFCD34D) : Colors.amber.shade200;
    final warningText = isDark ? Colors.amber.shade100 : Colors.black87;
    return LegalScreen(
      title: 'Mentions légales',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Éditeur de l\'application', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Carnet Livreur\n'
            'Application éditée par un particulier.\n'
            'Contact : support@carnet-livreur.app',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text('Hébergement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'L\'application fonctionne en local sur votre appareil. '
            'Aucun serveur externe n\'est utilisé pour stocker vos données.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text('Avertissement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: warningBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: warningBorder),
            ),
            child: Text(
              '⚠️ Carnet Livreur est un outil d\'aide à la gestion personnelle. '
              'Il ne constitue pas un service de paiement, ne se connecte pas à votre banque, '
              'et ne remplace pas un cabinet comptable. '
              'Les calculs URSSAF sont fournis à titre indicatif et peuvent varier selon votre situation. '
              'Vérifiez toujours vos obligations fiscales auprès d\'un professionnel.',
              style: TextStyle(fontSize: 13, color: warningText),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Propriété intellectuelle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'L\'application et son contenu sont protégés par le droit d\'auteur. '
            'Toute reproduction non autorisée est interdite.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text('Marques citées', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Uber, Uber Eats, Deliveroo, Just Eat et autres noms de plateformes sont des marques déposées '
            'appartenant à leurs propriétaires respectifs. Cette application n\'est ni affiliée, ni sponsorisée par ces marques.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Voir la politique de confidentialité'),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> launchExternal(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Impossible d\'ouvrir $url')),
    );
  }
}
