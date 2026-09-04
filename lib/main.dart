import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';
import 'legal_screens.dart';
import 'onboarding.dart';
import 'theme.dart';

const String kPrefsOnboardingCompleted = 'onboarding_completed';
const String kPrefsThemeMode = 'theme_mode';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  runApp(const BudgetLivreurApp());
}

class BudgetLivreurApp extends StatelessWidget {
  const BudgetLivreurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carnet Livreur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool? _showOnboarding;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(kPrefsOnboardingCompleted) ?? false;
    final mode = prefs.getString(kPrefsThemeMode) ?? 'system';
    setState(() {
      _showOnboarding = !completed;
      _themeMode = _parseThemeMode(mode);
    });
  }

  ThemeMode _parseThemeMode(String v) {
    switch (v) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final v = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
    await prefs.setString(kPrefsThemeMode, v);
    setState(() => _themeMode = mode);
  }

  void _onOnboardingComplete() {
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return MaterialApp(
      title: 'Carnet Livreur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: _showOnboarding!
          ? OnboardingScreen(onComplete: _onOnboardingComplete)
          : Builder(
              builder: (context) {
                try {
                  return HomePage(onThemeModeChanged: _setThemeMode, currentThemeMode: _themeMode);
                } catch (e, stack) {
                  return Scaffold(
                    backgroundColor: AppColors.brand,
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white, size: 48),
                            const SizedBox(height: 16),
                            Text('Erreur au démarrage', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('$e', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.clear();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Données effacées, redémarrez l\'appli')));
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.brand),
                              child: const Text('Effacer les données'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
    );
  }
}
class Entry {
  String id;
  String type;
  String label;
  double amount;
  bool taxable;
  bool nonEssential;
  String source;
  bool isBill;
  bool billRecurring;
  bool billPaid;
  DateTime date;
  bool isCarryOver;

  Entry({
    required this.id,
    required this.type,
    required this.label,
    required this.amount,
    this.taxable = true,
    this.nonEssential = false,
    this.source = 'livraison',
    this.isBill = false,
    this.billRecurring = false,
    this.billPaid = false,
    required this.date,
    this.isCarryOver = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'label': label,
        'amount': amount,
        'taxable': taxable,
        'nonEssential': nonEssential,
        'source': source,
        'isBill': isBill,
        'billRecurring': billRecurring,
        'billPaid': billPaid,
        'date': date.toIso8601String(),
        'isCarryOver': isCarryOver,
      };

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
        id: json['id'],
        type: json['type'],
        label: json['label'],
        amount: json['amount'].toDouble(),
        taxable: json['taxable'] ?? true,
        nonEssential: json['nonEssential'] ?? false,
        source: json['source'] ?? 'livraison',
        isBill: json['isBill'] ?? false,
        billRecurring: json['billRecurring'] ?? false,
        billPaid: json['billPaid'] ?? false,
        date: DateTime.parse(json['date']),
        isCarryOver: json['isCarryOver'] ?? false,
      );
}

class _ImportResult {
  final bool success;
  final String message;
  _ImportResult(this.success, this.message);
}

class MonthData {
  List<Entry> entries;
  double carryOver;

  MonthData({List<Entry>? entries, double? carryOver})
      : entries = entries ?? [],
        carryOver = carryOver ?? 0;

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'carryOver': carryOver,
      };

  factory MonthData.fromJson(Map<String, dynamic> json) => MonthData(
        entries: (json['entries'] as List? ?? [])
            .map((e) => Entry.fromJson(e))
            .toList(),
        carryOver: (json['carryOver'] ?? 0).toDouble(),
      );
}

class HomePage extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ThemeMode? currentThemeMode;
  HomePage({super.key, this.onThemeModeChanged, this.currentThemeMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SharedPreferences? _prefs;
  final String _storageKey = 'budget-livreur-flutter-v1';
  Timer? _saveDebounce;
  Map<String, double>? _calcCache;
  int _calcCacheStamp = -1;
  String? _errorMessage;

  Map<String, double> _objectives = {
    'perso': 0,
    'fixes': 0,
    'epargne': 0,
    'aides': 0,
  };

  Map<String, MonthData> _months = {};
  String _currentMonthKey = '';
  bool _isLoading = false;
  bool _hasError = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    'objectives': GlobalKey(),
    'result': GlobalKey(),
    'entries': GlobalKey(),
  };
  String _activeSection = 'objectives';

  @override
  void initState() {
    super.initState();
    _currentMonthKey = _getCurrentMonthKey();
    _initPrefs();
  }

  String _getCurrentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _getMonthLabel(String monthKey) {
    final parts = monthKey.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('MMMM yyyy', 'fr_FR').format(date);
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance().timeout(
        Duration(seconds: 5),
      );
      _loadState();
    } catch (e) {
      debugPrint('Erreur prefs: $e');
      if (!_months.containsKey(_currentMonthKey)) {
        _months[_currentMonthKey] = MonthData();
      }
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _loadState() {
    try {
      final saved = _prefs?.getString(_storageKey);
      if (saved != null) {
        final data = jsonDecode(saved);
        setState(() {
          _objectives = Map<String, double>.from(
            (data['objectives'] as Map<String, dynamic>? ?? {}).map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ),
          );
          _months = (data['months'] as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, MonthData.fromJson(v)),
          );
        });
      }
      if (!_months.containsKey(_currentMonthKey)) {
        _months[_currentMonthKey] = MonthData();
      }
      _checkMonthChange();
    } catch (e) {
      debugPrint('Erreur chargement: $e');
      if (!_months.containsKey(_currentMonthKey)) {
        _months[_currentMonthKey] = MonthData();
      }
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveState() async {
    final data = {
      'objectives': _objectives,
      'months': _months.map((k, v) => MapEntry(k, v.toJson())),
    };
    await _prefs?.setString(_storageKey, jsonEncode(data));
  }

  void _checkMonthChange() {
    final newMonthKey = _getCurrentMonthKey();
    if (newMonthKey != _currentMonthKey) {
      final prevCalc = _calculateMonth(_currentMonthKey);
      final prevMonth = _months[_currentMonthKey] ?? MonthData();
      _months[newMonthKey] ??= MonthData();
      final newMonth = _months[newMonthKey]!;

      if ((prevCalc['netBalance'] ?? 0) > 0) {
        newMonth.carryOver = prevCalc['netBalance'] ?? 0;
        newMonth.entries.add(Entry(
          id: '${DateTime.now().millisecondsSinceEpoch}-co',
          type: 'income',
          label: 'Report solde ${_getMonthLabel(_currentMonthKey)}',
          amount: prevCalc['netBalance'] ?? 0,
          taxable: false,
          source: 'autre',
          date: DateTime.parse('$newMonthKey-01'),
          isCarryOver: true,
        ));
      }

      final newMonthDate = DateTime.parse('$newMonthKey-01');
      for (final e in prevMonth.entries) {
        if (e.isBill && e.billRecurring) {
          newMonth.entries.add(Entry(
            id: '${DateTime.now().millisecondsSinceEpoch}-${e.id}-${newMonthKey}',
            type: 'expense',
            label: e.label,
            amount: e.amount,
            nonEssential: e.nonEssential,
            isBill: true,
            billRecurring: true,
            billPaid: false,
            date: newMonthDate,
            isCarryOver: true,
          ));
        }
      }

      _currentMonthKey = newMonthKey;
      _saveState();
    }
  }

  MonthData get _currentMonthData => _months[_currentMonthKey] ?? MonthData();

  Map<String, double> _calculateMonth(String monthKey) {
    final month = _months[monthKey] ?? MonthData();
    double totalCA = 0;
    double livraisonCA = 0;
    double otherIncome = 0;
    double taxableCA = 0;
    double paidExpenses = 0;
    double unpaidBills = 0;
    final incomeDays = <String>{};

    for (final e in month.entries) {
      if (e.type == 'income') {
        totalCA += e.amount;
        if (e.source == 'autre') {
          otherIncome += e.amount;
        } else {
          livraisonCA += e.amount;
        }
        if (e.taxable != false) taxableCA += e.amount;
        final dayKey = '${e.date.year}-${e.date.month}-${e.date.day}';
        incomeDays.add(dayKey);
      } else {
        if (e.isBill && !e.billPaid) {
          unpaidBills += e.amount;
        } else {
          paidExpenses += e.amount;
        }
      }
    }

    final urssafRate = 0.22;
    final aides = _objectives['aides'] ?? 0.0;
    final netNeeds = (_objectives['perso'] ?? 0) + (_objectives['fixes'] ?? 0) + (_objectives['epargne'] ?? 0) - aides;
    final netNeedsPositive = netNeeds > 0 ? netNeeds : 0.0;
    final targetCA = urssafRate < 1 ? netNeedsPositive / (1 - urssafRate) : 0.0;
    final urssafToPay = taxableCA * urssafRate;
    final netBalance = livraisonCA - urssafToPay + otherIncome - paidExpenses;
    final netAfterBills = netBalance - unpaidBills;

    return {
      'totalCA': totalCA,
      'livraisonCA': livraisonCA,
      'otherIncome': otherIncome,
      'paidExpenses': paidExpenses,
      'unpaidBills': unpaidBills,
      'urssafToPay': urssafToPay,
      'netBalance': netBalance,
      'netAfterBills': netAfterBills,
      'carryOver': month.carryOver,
      'targetCA': targetCA,
      'netNeeds': netNeedsPositive,
      'remainingCA': (targetCA - livraisonCA).clamp(0.0, double.infinity),
      'possibleSavings': (netAfterBills - netNeedsPositive).clamp(0.0, double.infinity),
    };
  }

  Map<String, double> _calculate() {
    final calc = _calculateMonth(_currentMonthKey);
    final totalCA = calc['totalCA'] ?? 0.0;
    final livraisonCA = calc['livraisonCA'] ?? 0.0;
    final netBalance = calc['netBalance'] ?? 0.0;
    final netAfterBills = calc['netAfterBills'] ?? netBalance;
    final netNeeds = calc['netNeeds'] ?? 0.0;
    final targetCA = calc['targetCA'] ?? 0.0;
    final remainingCA = (targetCA - livraisonCA).clamp(0.0, double.infinity);
    final possibleSavings = (netAfterBills - netNeeds).clamp(0.0, double.infinity);

    return {
      'totalCA': totalCA,
      'livraisonCA': livraisonCA,
      'otherIncome': calc['otherIncome'] ?? 0.0,
      'paidExpenses': calc['paidExpenses'] ?? 0.0,
      'unpaidBills': calc['unpaidBills'] ?? 0.0,
      'urssafToPay': calc['urssafToPay'] ?? 0.0,
      'netBalance': netBalance,
      'netAfterBills': netAfterBills,
      'carryOver': calc['carryOver'] ?? 0.0,
      'targetCA': targetCA,
      'netNeeds': netNeeds,
      'remainingCA': remainingCA,
      'possibleSavings': possibleSavings,
      'targetNet': netNeeds,
    };
  }

  String _formatCurrency(double value) {
    if (value == value.roundToDouble()) {
      return NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0).format(value);
    }
    return NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2).format(value);
  }

  void _syncChargesWithBills() {
    final billsTotal = _currentMonthData.entries.where((e) => e.isBill).fold(0.0, (s, e) => s + e.amount);
    final fixes = _objectives['fixes'] ?? 0;
    if ((billsTotal - fixes).abs() > 0.5) {
      setState(() {
        _objectives['fixes'] = billsTotal;
      });
      _saveState();
    }
  }

  void _autoCreateSyntheticBill(double value) {
    if (value <= 0) {
      final synthetic = _currentMonthData.entries.firstWhere(
        (e) => e.isBill && e.label == '📋 Charges mensuelles',
        orElse: () => Entry(id: '', type: 'expense', label: '', amount: 0, date: DateTime.now()),
      );
      if (synthetic.id.isNotEmpty) {
        setState(() => _currentMonthData.entries.removeWhere((e) => e.id == synthetic.id));
        _saveState();
      }
      return;
    }
    final existing = _currentMonthData.entries.where((e) => e.isBill).toList();
    final synthetic = existing.firstWhere(
      (e) => e.label == '📋 Charges mensuelles',
      orElse: () => Entry(id: '', type: 'expense', label: '', amount: 0, date: DateTime.now()),
    );
    final detailedBills = existing.where((e) => e.label != '📋 Charges mensuelles').fold(0.0, (s, e) => s + e.amount);
    if (detailedBills > 0) return;
    if (synthetic.id.isEmpty) {
      setState(() {
        _currentMonthData.entries.add(Entry(
          id: 'synthetic-charges-${_currentMonthKey}',
          type: 'expense',
          label: '📋 Charges mensuelles',
          amount: value,
          nonEssential: false,
          isBill: true,
          billRecurring: true,
          billPaid: false,
          date: DateTime.now(),
        ));
      });
    } else {
      setState(() => synthetic.amount = value);
    }
    _saveState();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == now.year && date.month == now.month && date.day == now.day) return "Aujourd'hui";
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) return 'Hier';
    return DateFormat('d MMM', 'fr_FR').format(date);
  }

  Future<void> _confirmReset() async {
    final confirmed = await _confirm('⚠️ Réinitialiser toutes les données ?\n\nCette action supprime :\n• Tous les objectifs\n• Toutes les opérations\n• Tous les mois\n\nCette action est irréversible.');
    if (confirmed == true) {
      await _resetAllData();
    }
  }

  Future<void> _resetAllData() async {
    _saveDebounce?.cancel();
    _prefs?.clear();
    setState(() {
      _objectives = {
        'perso': 0,
        'fixes': 0,
        'epargne': 0,
        'aides': 0,
      };
      _months = {};
      _currentMonthKey = _getCurrentMonthKey();
      _months[_currentMonthKey] = MonthData();
      _calcCache = null;
      _errorMessage = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Données réinitialisées'), backgroundColor: Colors.green),
      );
    }
  }

  void _showSummaryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📊 Résumé des opérations'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_months.length > 1)
                DropdownButton<String>(
                  value: _currentMonthKey,
                  isExpanded: true,
                  onChanged: (v) {
                    if (v != null) {
                      Navigator.pop(ctx);
                      setState(() => _currentMonthKey = v);
                      _showSummaryDialog();
                    }
                  },
                  items: (_months.keys.toList()..sort()).reversed.map((key) => DropdownMenuItem(value: key, child: Text(_getMonthLabel(key)))).toList(),
                ),
              SizedBox(height: 16),
              _buildSummaryContent(),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _buildSummaryContent() {
    final calc = _calculateMonth(_currentMonthKey);
    final month = _months[_currentMonthKey] ?? MonthData();
    final incomes = month.entries.where((e) => e.type == 'income' && !e.isCarryOver).toList();
    final expenses = month.entries.where((e) => e.type == 'expense').toList();
    final nonEssential = expenses.where((e) => e.nonEssential).toList();
    final totalEssential = expenses.where((e) => !e.nonEssential).fold(0.0, (s, e) => s + e.amount);
    final totalNonEssential = nonEssential.fold(0.0, (s, e) => s + e.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📅 ${_getMonthLabel(_currentMonthKey)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        SizedBox(height: 12),
        _summaryRow('💰 Revenus', incomes.length, calc['totalCA']!, Colors.green),
        _summaryRow('⛽ Dépenses', expenses.length, (calc['paidExpenses'] ?? 0) + (calc['unpaidBills'] ?? 0), Colors.red),
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('  ✓ Essentielles: ${_formatCurrency(totalEssential)}', style: const TextStyle(fontSize: 12)),
              Text('  ✂️ Non essentielles: ${_formatCurrency(totalNonEssential)}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ],
          ),
        ),
        Divider(),
        _summaryRow('💼 Solde net', null, calc['netBalance']!, calc['netBalance']! >= 0 ? Colors.green : Colors.red),
        _summaryRow('🏛️ URSSAF à payer', null, calc['urssafToPay']!, Colors.orange),
        if (calc['carryOver']! > 0)
          _summaryRow('🔄 Report mois suivant', null, calc['carryOver']!, Colors.blue),
        SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡 Économies réalisées', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Total économisable: ${_formatCurrency(totalNonEssential)}', style: const TextStyle(fontSize: 13)),
              if (totalNonEssential > 0)
                Text('En supprimant les dépenses non essentielles, vous pourriez économiser ${_formatCurrency(totalNonEssential)} !',
                    style: const TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, int? count, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label${count != null ? ' ($count)' : ''}'),
          Text(_formatCurrency(value), style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  void _showDemoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.science_outlined, color: Color(0xFF1A73E8)),
            SizedBox(width: 8),
            Flexible(child: Text('Charger données démo', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Cela va remplacer vos données actuelles par un exemple clair :\n\n'
            '• Factures à payer : 800 €\n'
            '• Aides (APL) : 200 €\n'
            '• URSSAF : 22%\n'
            '• CA Uber semaine : 350 €\n'
            '• Carburant payé : 50 €\n'
            '• 1 facture payée (EDF) : 60 €\n'
            '• 1 facture en attente (Loyer) : 700 €\n\n'
            'Objectif CA attendu : (800-200) ÷ 0.78 = 769 €',
            softWrap: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadDemoData();
            },
            child: const Text('Charger'),
          ),
        ],
      ),
    );
  }

  void _loadDemoData() {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastWeek = now.subtract(const Duration(days: 3));
    final twoWeeksAgo = now.subtract(const Duration(days: 10));

    setState(() {
      _objectives = {
        'perso': 250,
        'fixes': 800,
        'epargne': 50,
        'urssaf': 22,
        'aides': 200,
      };
      _months = {
        monthKey: MonthData(
          entries: [
            Entry(id: 'demo-1', type: 'income', label: '🚚 Uber lundi', amount: 120, taxable: true, source: 'livraison', date: twoWeeksAgo),
            Entry(id: 'demo-2', type: 'income', label: '🚚 Uber mardi', amount: 85, taxable: true, source: 'livraison', date: twoWeeksAgo.add(const Duration(days: 1))),
            Entry(id: 'demo-3', type: 'income', label: '🚚 Uber mercredi', amount: 145, taxable: true, source: 'livraison', date: lastWeek),
            Entry(id: 'demo-4', type: 'income', label: '💵 APL', amount: 200, taxable: false, source: 'autre', date: lastWeek),
            Entry(id: 'demo-5', type: 'expense', label: '⛽ Carburant', amount: 50, nonEssential: false, isBill: false, date: lastWeek),
            Entry(id: 'demo-6', type: 'expense', label: 'EDF', amount: 60, nonEssential: false, isBill: true, billRecurring: true, billPaid: true, date: now.subtract(const Duration(days: 5))),
            Entry(id: 'demo-7', type: 'expense', label: 'Loyer', amount: 700, nonEssential: false, isBill: true, billRecurring: true, billPaid: false, date: now.subtract(const Duration(days: 2))),
            Entry(id: 'demo-8', type: 'expense', label: 'Netflix', amount: 13, nonEssential: true, isBill: true, billRecurring: true, billPaid: false, date: now.subtract(const Duration(days: 1))),
          ],
        ),
      };
      _currentMonthKey = monthKey;
    });
    _saveState();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🧪 Démo chargée ! Objectif : 769 € Uber à gagner')));
  }

  void _showBackupDialog() {
    final json = _exportJson();
    final ctrl = TextEditingController(text: json);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.backup_outlined, color: Color(0xFF1A73E8)),
            SizedBox(width: 8),
            Flexible(child: Text('Sauvegarde', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📋 Copiez ce texte pour sauvegarder vos données (collez-le plus tard pour restaurer).', style: TextStyle(fontSize: 12, color: context.textSecondary), softWrap: true),
              SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: context.dividerColor, borderRadius: BorderRadius.circular(8)),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: SelectableText(json, style: const TextStyle(fontSize: 9, fontFamily: 'monospace')),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 Sauvegarde copiée !')));
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier'),
          ),
        ],
      ),
    );
  }

  String _exportJson() {
    final monthsData = _months.map((key, month) => MapEntry(key, {
          'entries': month.entries.map((e) => e.toJson()).toList(),
          'carryOver': month.carryOver,
        }));
    final data = {
      'objectives': _objectives,
      'currentMonthKey': _currentMonthKey,
      'months': monthsData,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  void _showImportDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_upload_outlined, color: Color(0xFF1A73E8)),
            SizedBox(width: 8),
            Flexible(child: Text('Importer un CSV', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📋 Comment faire :\n'
                '1. Uber Driver → Paiements → Historique\n'
                '2. Exporter en CSV\n'
                '3. Ouvrir le fichier, copier le contenu\n'
                '4. Coller ci-dessous',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
                softWrap: true,
              ),
              SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBFDBFE), width: 1)),
                child: const Text('💡 Formats supportés : date,montant ou date,type,montant', style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)), softWrap: true),
              ),
              SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Contenu CSV',
                  hintText: 'Coller ici...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton.icon(
            onPressed: () {
              final result = _parseAndImportCsv(ctrl.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result.message),
                backgroundColor: result.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                duration: const Duration(seconds: 3),
              ));
            },
            icon: const Icon(Icons.file_upload, size: 18),
            label: const Text('Importer'),
          ),
        ],
      ),
    );
  }

  _ImportResult _parseAndImportCsv(String text) {
    if (text.trim().isEmpty) {
      return _ImportResult(false, '❌ Aucun contenu collé');
    }
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length < 2) {
      return _ImportResult(false, '❌ Pas assez de lignes (besoin au moins un en-tête + 1 ligne)');
    }

    int dateCol = -1;
    int amountCol = -1;
    int typeCol = -1;
    int count = 0;

    setState(() {
      for (int i = 0; i < lines.length; i++) {
        final cells = _splitCsvLine(lines[i]);
        if (i == 0) {
          for (int j = 0; j < cells.length; j++) {
            final c = cells[j].toLowerCase();
            if (dateCol == -1 && (c.contains('date') || c.contains('jour') || c == 'd')) dateCol = j;
            if (amountCol == -1 && (c.contains('montant') || c.contains('amount') || c.contains('gain') || c.contains('prix') || c.contains('euros') || c.contains('€'))) amountCol = j;
            if (typeCol == -1 && (c.contains('type') || c.contains('catégorie'))) typeCol = j;
          }
          if (dateCol == -1) dateCol = 0;
          if (amountCol == -1) amountCol = cells.length > 1 ? 1 : 0;
          continue;
        }

        try {
          final dateStr = cells[dateCol].trim();
          final amountStr = cells[amountCol].trim().replaceAll('€', '').replaceAll(' ', '').replaceAll(',', '.');
          final amount = double.tryParse(amountStr);
          if (amount == null || amount <= 0) continue;
          final date = _parseDate(dateStr);
          if (date == null) continue;

          final type = typeCol >= 0 && typeCol < cells.length ? cells[typeCol].toLowerCase() : '';
          final isExpense = type.contains('frais') || type.contains('débit') || type.contains('commission') || amountStr.startsWith('-');
          final source = isExpense ? 'autre' : 'livraison';
          final cleanAmount = amount.abs();

          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          _months[monthKey] ??= MonthData();
          _months[monthKey]!.entries.add(Entry(
            id: 'csv-${DateTime.now().millisecondsSinceEpoch}-$i',
            type: isExpense ? 'expense' : 'income',
            label: isExpense ? '💸 Frais Uber' : '🚚 Course Uber',
            amount: cleanAmount,
            taxable: !isExpense,
            source: isExpense ? 'autre' : source,
            nonEssential: false,
            date: date,
          ));
          count++;
        } catch (_) {
          continue;
        }
      }
    });
    _saveState();
    if (count == 0) {
      return _ImportResult(false, '❌ Aucune ligne valide trouvée. Vérifie le format.');
    }
    return _ImportResult(true, '✅ $count opérations importées !');
  }

  DateTime? _parseDate(String s) {
    s = s.trim();
    final formats = ['yyyy-MM-dd', 'dd/MM/yyyy', 'MM/dd/yyyy', 'dd-MM-yyyy', 'dd.MM.yyyy', 'yyyy/MM/dd'];
    for (final f in formats) {
      try {
        return DateFormat(f).parseStrict(s);
      } catch (_) {
        continue;
      }
    }
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => _SettingsDialog(
        currentThemeMode: widget.currentThemeMode ?? ThemeMode.system,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF1A73E8)),
            SizedBox(width: 8),
            Flexible(child: Text('Comment ça marche ?', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _helpSection(
                '📒 C\'est un carnet de compte intelligent',
                '• Pas une app bancaire (pas de connexion à votre banque)\n'
                '• Vous notez vos revenus/dépenses vous-même\n'
                '• L\'app calcule automatiquement où vous en êtes\n'
                '• 100% privé : tout reste sur votre téléphone\n'
                '• Pensez à faire une sauvegarde (💾) de temps en temps !',
              ),
              _helpSection(
                '📌 Étape 1 : Vos besoins',
                'Entrez ce que vous devez gagner pour vivre :\n'
                '• Charges fixes (loyer, assurances...)\n'
                '• Budget perso (nourriture, loisirs...)\n'
                '• Épargne souhaitée\n'
                '• Taux URSSAF (défaut 22%)\n\n'
                'L\'app calcule votre objectif de CA (combien gagner en brut).',
              ),
              _helpSection(
                '🏦 Étape 2 : Type de virement',
                '• Hebdomadaire (gratuit) : virement auto chaque semaine\n'
                '• Instantané (0.99€/virement) : immédiat mais payant\n\n'
                'Les frais sont calculés selon le nombre de revenus.',
              ),
              _helpSection(
                '✏️ Étape 3 : Saisie',
                '+ Revenu : courses, primes, pourboires...\n'
                '  → Case "Soumis à URSSAF" cochée par défaut\n\n'
                '− Dépense : carburant, réparations...\n'
                '  → Case "Non essentielle" pour les loisirs',
              ),
              _helpSection(
                '📊 Étape 4 : Résultat',
                '• Solde en poche : CA - URSSAF - frais - dépenses\n'
                '• Gain réel : Solde - charges fixes\n'
                '• Barre de progression vers votre objectif\n'
                '• Suggestions d\'économies (dépenses non essentielles)',
              ),
              _helpSection(
                '🔄 Report automatique',
                'Quand le mois change, le solde restant est reporté '
                'automatiquement au mois suivant. Apparaît comme '
                '"🔄 Report solde [mois]" (non soumis à URSSAF).',
              ),
              _helpSection(
                '📅 Navigation entre mois',
                'Appuyez sur l\'icône calendrier pour voir les mois précédents. '
                'Appuyez sur l\'icône 📊 pour un résumé détaillé.',
              ),
              _helpSection(
                '💡 Économies',
                'Les dépenses marquées "non essentielles" apparaissent en vert. '
                'Supprimez-les pour économiser de l\'argent !',
              ),
              _helpSection(
                '📐 Formules',
                'Objectif CA = Besoins ÷ (1 - URSSAF)\n'
                'Solde = CA - URSSAF - Dépenses - Frais\n'
                'Frais = Nombre revenus × 0.99€ (si instantané)',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris !'),
          ),
        ],
      ),
    );
  }

  Widget _helpSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          SizedBox(height: 4),
          Text(content, style: TextStyle(fontSize: 13, color: context.textSecondary)),
        ],
      ),
    );
  }

  void _showAddIncomeDialog() {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool taxable = true;
    String source = 'livraison';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('💰 Ajouter un revenu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: InputDecoration(
                    labelText: 'Libellé',
                    hintText: 'Ex: Courses Uber',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: InputDecoration(
                    labelText: 'Montant (€)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: Text('Source du revenu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('🚚 Livraison'),
                        selected: source == 'livraison',
                        onSelected: (_) => setDialogState(() {
                          source = 'livraison';
                          taxable = true;
                        }),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('💵 Autre'),
                        selected: source == 'autre',
                        onSelected: (_) => setDialogState(() {
                          source = 'autre';
                          taxable = false;
                        }),
                      ),
                    ),
                  ],
                ),
                if (source == 'autre') ...[
                  SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                    child: const Text('ℹ️ Pas de prise en compte URSSAF, hors progression', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0)), softWrap: true),
                  ),
                ],
                SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Soumis à URSSAF (CA imposable)', style: TextStyle(fontSize: 14)),
                  value: taxable,
                  onChanged: source == 'autre' ? null : (v) => setDialogState(() => taxable = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (labelCtrl.text.isNotEmpty && amount > 0) {
                  setState(() {
                    _currentMonthData.entries.add(Entry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      type: 'income',
                      label: labelCtrl.text,
                      amount: amount,
                      taxable: taxable,
                      source: source,
                      date: DateTime.now(),
                    ));
                  });
                  _saveState();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog() {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool nonEssential = false;
    bool isBill = false;
    bool billRecurring = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('⛽ Ajouter une dépense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: InputDecoration(
                    labelText: 'Libellé',
                    hintText: 'Ex: Carburant, Loyer...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: InputDecoration(
                    labelText: 'Montant (€)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 12),
                _buildCheckRow('Non essentielle (loisirs...)', nonEssential, (v) => setDialogState(() => nonEssential = v)),
                _buildCheckRow('📋 C\'est une facture (à payer)', isBill, (v) => setDialogState(() => isBill = v)),
                if (isBill) ...[
                  _buildCheckRow('🔄 Récurrente (chaque mois)', billRecurring, (v) => setDialogState(() => billRecurring = v)),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                    child: const Text('ℹ️ Une facture se déduit quand marquée payée. Les récurrentes passent au mois suivant.', style: TextStyle(fontSize: 11, color: Color(0xFFE65100)), softWrap: true),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (labelCtrl.text.isNotEmpty && amount > 0) {
                  setState(() {
                    _currentMonthData.entries.add(Entry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      type: 'expense',
                      label: labelCtrl.text,
                      amount: amount,
                      nonEssential: nonEssential,
                      isBill: isBill,
                      billRecurring: billRecurring,
                      billPaid: false,
                      date: DateTime.now(),
                    ));
                  });
                  _saveState();
                  if (isBill) {
                    setState(() => _currentMonthData.entries.removeWhere((e) => e.id == 'synthetic-charges-${_currentMonthKey}'));
                    _syncChargesWithBills();
                  }
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Entry entry) {
    final labelCtrl = TextEditingController(text: entry.label);
    final amountCtrl = TextEditingController(text: entry.amount.toString());
    bool taxable = entry.taxable;
    bool nonEssential = entry.nonEssential;
    String source = entry.source;
    bool isBill = entry.isBill;
    bool billRecurring = entry.billRecurring;
    bool billPaid = entry.billPaid;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(entry.type == 'income' ? '✏️ Modifier le revenu' : '✏️ Modifier la dépense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: InputDecoration(
                    labelText: 'Libellé',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: InputDecoration(
                    labelText: 'Montant (€)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (entry.type == 'income') ...[
                  SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: Text('Source du revenu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('🚚 Livraison'),
                          selected: source == 'livraison',
                          onSelected: (_) => setDialogState(() {
                            source = 'livraison';
                            taxable = true;
                          }),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('💵 Autre'),
                          selected: source == 'autre',
                          onSelected: (_) => setDialogState(() {
                            source = 'autre';
                            taxable = false;
                          }),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Soumis à URSSAF (CA imposable)', style: TextStyle(fontSize: 14)),
                    value: taxable,
                    onChanged: source == 'autre' ? null : (v) => setDialogState(() => taxable = v ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                if (entry.type == 'expense') ...[
                  SizedBox(height: 12),
                  _buildCheckRow('Non essentielle (loisirs...)', nonEssential, (v) => setDialogState(() => nonEssential = v)),
                  _buildCheckRow('📋 C\'est une facture', isBill, (v) => setDialogState(() => isBill = v)),
                  if (isBill) ...[
                    _buildCheckRow('🔄 Récurrente chaque mois', billRecurring, (v) => setDialogState(() => billRecurring = v)),
                    _buildCheckRow('✓ Marquer comme payée', billPaid, (v) => setDialogState(() => billPaid = v)),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (labelCtrl.text.isNotEmpty && amount > 0) {
                  setState(() {
                    entry.label = labelCtrl.text;
                    entry.amount = amount;
                    entry.taxable = taxable;
                    entry.nonEssential = nonEssential;
                    if (entry.type == 'income') entry.source = source;
                    if (entry.type == 'expense') {
                      entry.isBill = isBill;
                      entry.billRecurring = billRecurring;
                      entry.billPaid = isBill ? billPaid : false;
                    }
                  });
                  _saveState();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
        ],
      ),
    ) ?? false;
  }

  void _deleteEntry(String id) async {
    final confirmed = await _confirm('Supprimer cette opération ?');
    if (confirmed) {
      setState(() {
        _currentMonthData.entries.removeWhere((e) => e.id == id);
      });
      _saveState();
    }
  }

  void _confirmClear() async {
    if (_currentMonthData.entries.isEmpty) return;
    final confirmed = await _confirm('⚠️ Effacer toutes les opérations de ${_getMonthLabel(_currentMonthKey)} ?');
    if (confirmed) {
      setState(() {
        _currentMonthData.entries.clear();
        _currentMonthData.carryOver = 0;
      });
      _saveState();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Chargement...', style: TextStyle(color: context.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('⚠️', style: TextStyle(fontSize: 48)),
                SizedBox(height: 16),
                Text(
                  'Erreur de chargement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Impossible de charger les données. Réessayez ou réinstallez l\'application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
                      _errorMessage = null;
                    });
                    _initPrefs();
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final calc = _calculate();
    final hasObjectives = _objectives['perso']! > 0 || _objectives['fixes']! > 0;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('📒', style: TextStyle(fontSize: 28)),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Text('Suivi intelligent pour livreurs', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ),
        backgroundColor: context.isDark ? AppColors.darkSurface : AppColors.brand,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: context.isDark ? AppColors.darkTextPrimary : Colors.white),
        elevation: 0,
        actions: [
          if (_months.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.calendar_month),
              onSelected: (value) {
                setState(() {
                  _currentMonthKey = value;
                });
              },
              itemBuilder: (context) {
                final sortedMonths = (_months.keys.toList()..sort()).reversed.toList();
                return sortedMonths.map((key) => PopupMenuItem(
                  value: key,
                  child: Row(
                    children: [
                      if (key == _currentMonthKey)
                        Icon(Icons.check, size: 18, color: Color(0xFF1A73E8)),
                      if (key == _currentMonthKey)
                        SizedBox(width: 8),
                      Text(_getMonthLabel(key)),
                    ],
                  ),
                )).toList();
              },
            ),
          IconButton(
            icon: const Icon(Icons.assessment),
            onPressed: _showSummaryDialog,
            tooltip: 'Résumé',
          ),
          IconButton(
            icon: const Icon(Icons.science_outlined),
            onPressed: _showDemoDialog,
            tooltip: 'Charger démo',
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _showImportDialog,
            tooltip: 'Importer CSV',
          ),
          IconButton(
            icon: const Icon(Icons.backup_outlined),
            onPressed: _showBackupDialog,
            tooltip: 'Sauvegarder',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Plus',
            onSelected: (value) async {
              switch (value) {
                case 'help':
                  _showHelpDialog();
                  break;
                case 'settings':
                  _showSettingsDialog();
                  break;
                case 'about':
                  showDialog(
                    context: context,
                    builder: (_) => const AppAboutDialog(),
                  );
                  break;
                case 'privacy':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  );
                  break;
                case 'terms':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  );
                  break;
                case 'reset':
                  _confirmReset();
                  break;
                case 'replay_onboarding':
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(kPrefsOnboardingCompleted, false);
                  if (context.mounted) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => OnboardingScreen(onComplete: () => Navigator.of(context).pop()),
                    ));
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'help',
                child: Row(children: [Icon(Icons.help_outline, size: 20), const SizedBox(width: 12), Flexible(child: Text('Aide'))]),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(children: [Icon(Icons.settings_outlined, size: 20), const SizedBox(width: 12), Flexible(child: Text('Réglages'))]),
              ),
              PopupMenuItem(
                value: 'replay_onboarding',
                child: Row(children: [Icon(Icons.replay_outlined, size: 20), const SizedBox(width: 12), Flexible(child: Text('Rejouer l\'introduction'))]),
              ),
              PopupMenuItem(
                value: 'about',
                child: Row(children: [Icon(Icons.info_outline, size: 20), const SizedBox(width: 12), Flexible(child: Text('À propos'))]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'privacy',
                child: Row(children: [Icon(Icons.privacy_tip_outlined, size: 20), const SizedBox(width: 12), Flexible(child: Text('Confidentialité'))]),
              ),
              PopupMenuItem(
                value: 'terms',
                child: Row(children: [Icon(Icons.description_outlined, size: 20), const SizedBox(width: 12), Flexible(child: Text('Mentions légales'))]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'reset',
                child: Row(children: [Icon(Icons.delete_forever, size: 20, color: Theme.of(context).colorScheme.error), const SizedBox(width: 12), Flexible(child: Text('Réinitialiser les données', style: TextStyle(color: Theme.of(context).colorScheme.error)))]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickNav(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(_getMonthLabel(_currentMonthKey), style: TextStyle(fontSize: 16, color: context.textSecondary)),
                        if ((calc['targetCA'] ?? 0) > 0) ...[
                          SizedBox(height: 6),
                          Builder(builder: (ctx) {
                            final target = calc['targetCA']!;
                            final current = calc['livraisonCA'] ?? 0.0;
                            final reached = current >= target;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: reached ? [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)] : [const Color(0xFFFEE2E2), const Color(0xFFFECACA)]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(reached ? '🎉' : '🎯', style: const TextStyle(fontSize: 14)),
                                  SizedBox(width: 6),
                                  Text('Objectif Uber : ${reached ? '' : '-'}${_formatCurrency(target)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: reached ? const Color(0xFF065F46) : const Color(0xFFDC2626))),
                                ],
                              ),
                            );
                          }),
                        ],
                        if (calc['carryOver']! > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                            child: Text('🔄 Report: ${_formatCurrency(calc['carryOver']!)}', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(key: _sectionKeys['objectives'], child: _buildObjectivesSection(calc)),
                  SizedBox(height: 16),
                  _buildActionSection(calc),
                  SizedBox(height: 16),
                  Container(key: _sectionKeys['result'], child: _buildResultSection(calc)),
                  SizedBox(height: 16),
                  Container(key: _sectionKeys['entries'], child: _buildHistorySection()),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuickAdd,
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: context.cardBackground,
        icon: const Icon(Icons.flash_on),
        label: const Text('Saisie rapide'),
      ),
    );
  }

  void _showQuickAdd() {
    String source = 'livraison';
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
                ),
                SizedBox(height: 16),
                Text('⚡ Saisie rapide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.textPrimary)),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheet(() => source = 'livraison'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: source == 'livraison' ? Color(0xFFE8F0FE) : context.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: source == 'livraison' ? Color(0xFF1A73E8) : context.borderColor, width: source == 'livraison' ? 2 : 1),
                          ),
                          child: const Center(child: Text('🚚 Livraison', style: TextStyle(fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheet(() => source = 'autre'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: source == 'autre' ? Color(0xFFE3F2FD) : context.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: source == 'autre' ? Color(0xFF1A73E8) : context.borderColor, width: source == 'autre' ? 2 : 1),
                          ),
                          child: const Center(child: Text('💵 Autre', style: TextStyle(fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text('Montants rapides', style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0, 75.0, 100.0].map((m) => InkWell(
                    onTap: () {
                      _addQuickEntry(m, source);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 75,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF10B981), width: 1)),
                      child: Center(child: Text('+${m.toStringAsFixed(0)}€', style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w700, fontSize: 14))),
                    ),
                  )).toList(),
                ),
                SizedBox(height: 16),
                Text('Ou saisir un montant', style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        decoration: InputDecoration(
                          hintText: 'Montant €',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final amount = double.tryParse(amountCtrl.text) ?? 0;
                        if (amount > 0) {
                          _addQuickEntry(amount, source);
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1A73E8), foregroundColor: context.cardBackground, padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Ajouter'),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addQuickEntry(double amount, String source) {
    setState(() {
      _currentMonthData.entries.add(Entry(
        id: 'quick-${DateTime.now().millisecondsSinceEpoch}',
        type: 'income',
        label: source == 'livraison' ? '🚚 Course' : '💵 Autre revenu',
        amount: amount,
        taxable: source == 'livraison',
        source: source,
        date: DateTime.now(),
      ));
    });
    _saveState();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ +${amount.toStringAsFixed(0)}€ ajoutés'),
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF10B981),
    ));
  }

  Widget _buildQuickNav() {
    final tabs = [
      {'key': 'objectives', 'icon': '📌', 'label': 'Besoins'},
      {'key': 'result', 'icon': '📊', 'label': 'Résultat'},
      {'key': 'entries', 'icon': '📋', 'label': 'Opérations'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: context.cardBackground,
        boxShadow: [BoxShadow(color: context.shadowColor, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: tabs.length,
            itemBuilder: (ctx, i) {
              final t = tabs[i];
              final isActive = _activeSection == t['key'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _scrollToSection(t['key']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFE8F0FE) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isActive ? Color(0xFF1A73E8) : context.borderColor, width: isActive ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Text(t['icon']!, style: const TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text(t['label']!, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? Color(0xFF1A73E8) : context.textSecondary)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _scrollToSection(String key) {
    final ctx = _sectionKeys[key]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
      setState(() => _activeSection = key);
    }
  }

  Widget _buildObjectivesSection(Map<String, double> calc) {
    final totalBills = _currentMonthData.entries.where((e) => e.isBill).fold(0.0, (s, e) => s + e.amount);
    final aides = _objectives['aides'] ?? 0.0;
    return _section(
      title: '📌 Vos besoins mensuels',
      subtitle: 'Combien devez-vous gagner pour vivre ?',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE), width: 1)),
            child: const Row(
              children: [
                Text('💡', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les aides (APL, RSA) réduisent l\'objectif Uber. Saisir "Charges" crée automatiquement une facture globale que vous pouvez cocher comme payée.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _inputField(label: '🏠 Factures à payer', value: _objectives['fixes']!, onChanged: (v) { setState(() { _objectives['fixes'] = v; _autoCreateSyntheticBill(v); }); }, suffix: '€/mois')),
              SizedBox(width: 12),
              Expanded(child: _inputField(label: '🍔 Perso', value: _objectives['perso']!, onChanged: (v) { setState(() { _objectives['perso'] = v; }); }, suffix: '€/mois')),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _inputField(label: '🐷 Épargne', value: _objectives['epargne']!, onChanged: (v) { setState(() { _objectives['epargne'] = v; }); }, suffix: '€/mois')),
              SizedBox(width: 12),
              Expanded(child: _inputField(label: '💰 Aides (APL, RSA...)', value: _objectives['aides']!, onChanged: (v) { setState(() { _objectives['aides'] = v; }); }, suffix: '€/mois')),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { _saveState(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Besoins enregistrés'))); },
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1A73E8), foregroundColor: context.cardBackground, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Valider mes besoins'),
            ),
          ),
          if (calc['targetCA']! > 0) ...[
            SizedBox(height: 16),
            Builder(builder: (ctx) {
              final target = calc['targetCA']!;
              final current = calc['livraisonCA'] ?? 0.0;
              final reached = current >= target;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: reached ? [const Color(0xFFD1FAE5), const Color(0xFFA7F3D0)] : [const Color(0xFFFEE2E2), const Color(0xFFFECACA)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(reached ? '🎉 Objectif CA Uber atteint' : '🎯 Objectif CA Uber', style: TextStyle(fontSize: 14, color: reached ? const Color(0xFF065F46) : const Color(0xFF991B1B), fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text('${reached ? '' : '-'}${_formatCurrency(target)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: reached ? const Color(0xFF065F46) : const Color(0xFFDC2626))),
                    Text(reached ? 'Bravo ! Continuez comme ça.' : 'à gagner en livraisons (après ${_formatCurrency(_objectives['aides'] ?? 0)} d\'aides déduites)', style: TextStyle(fontSize: 12, color: reached ? const Color(0xFF047857) : const Color(0xFFB91C1C)), textAlign: TextAlign.center),
                  ],
                ),
              );
            }),
          ],
          if (_objectives['fixes']! > 0) ...[
            SizedBox(height: 12),
            Builder(builder: (ctx) {
              final ok = totalBills >= _objectives['fixes']!;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ok ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(ok ? Icons.check_circle : Icons.info_outline, color: ok ? const Color(0xFF10B981) : const Color(0xFFD97706), size: 18),
                        SizedBox(width: 6),
                        Text('Factures détaillées', style: TextStyle(fontSize: 12, color: ok ? const Color(0xFF065F46) : const Color(0xFF92400E), fontWeight: FontWeight.w700)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total : ${_formatCurrency(totalBills)}', style: TextStyle(fontSize: 12, color: ok ? const Color(0xFF065F46) : const Color(0xFF92400E))),
                        Text('Objectif : ${_formatCurrency(_objectives['fixes']!)}', style: TextStyle(fontSize: 12, color: ok ? const Color(0xFF065F46) : const Color(0xFF92400E))),
                      ],
                    ),
                    if (!ok) ...[
                      SizedBox(height: 4),
                      Text('Manque ${_formatCurrency(_objectives['fixes']! - totalBills)} à détailler', style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildActionSection(Map<String, double> calc) {
    return _section(
      title: '✏️ Étape 2 : Saisie',
      subtitle: 'Ajoutez vos opérations',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _actionButton(icon: '💰', label: '+ Revenu', color: Colors.green, onTap: _showAddIncomeDialog)),
              SizedBox(width: 12),
              Expanded(child: _actionButton(icon: '⛽', label: '− Dépense', color: Colors.red, onTap: _showAddExpenseDialog)),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.cardBackground, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: context.shadowColor, blurRadius: 5, offset: Offset(0, 2))]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickStat('CA', calc['totalCA']!, const Color(0xFF1A73E8)),
                _quickStat('Total sorties', (calc['paidExpenses'] ?? 0) + (calc['unpaidBills'] ?? 0), Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required String icon, required String label, required Color color, required VoidCallback onTap}) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.12), color.withOpacity(0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: TextStyle(fontSize: compact ? 22 : 26)),
              SizedBox(width: 6),
              Flexible(
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: compact ? 12 : 14, color: color), overflow: TextOverflow.ellipsis, softWrap: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickStat(String label, double value, Color color) {
    return Column(
      children: [Text(_formatCurrency(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)), Text(label, style: TextStyle(fontSize: 10, color: context.textSecondary))],
    );
  }

  Widget _buildResultSection(Map<String, double> calc) {
    final netBalance = calc['netBalance'] ?? 0.0;
    final netAfterBills = calc['netAfterBills'] ?? netBalance;
    final netNeeds = calc['netNeeds'] ?? 0.0;
    final targetCA = calc['targetCA'] ?? 0.0;
    final livraisonCA = calc['livraisonCA'] ?? 0.0;
    final unpaidBills = calc['unpaidBills'] ?? 0.0;
    final remainingForGoal = (targetCA - livraisonCA).clamp(0.0, double.infinity);
    final remainingBills = unpaidBills;
    String detailLabel;
    if (netNeeds == 0) {
      detailLabel = 'Définissez vos besoins dans l\'étape 1';
    } else if (netAfterBills >= netNeeds) {
      final surplus = netAfterBills - netNeeds;
      detailLabel = '✓ Objectif atteint (+${_formatCurrency(surplus)} au-dessus)';
    } else {
      final manque = netNeeds - netAfterBills;
      detailLabel = '⚠️ Manque ${_formatCurrency(manque)} pour couvrir les ${_formatCurrency(netNeeds)} de besoins nets';
    }
    return _section(
      title: '📊 Votre résultat',
      subtitle: 'Situation en temps réel',
      child: Column(
        children: [
          _resultCard(
            label: unpaidBills > 0 ? '💰 NET après factures' : '💰 NET en poche',
            value: netAfterBills,
            detail: detailLabel,
            isPrimary: false,
          ),
          if (targetCA > 0) ...[
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: livraisonCA >= targetCA ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: livraisonCA >= targetCA ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE), width: 1),
              ),
              child: Row(
                children: [
                  Icon(livraisonCA >= targetCA ? Icons.check_circle : Icons.flag, color: livraisonCA >= targetCA ? const Color(0xFF10B981) : const Color(0xFF1A73E8), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(livraisonCA >= targetCA ? 'Objectif Uber atteint' : 'Objectif Uber à gagner', style: TextStyle(fontSize: 12, color: livraisonCA >= targetCA ? const Color(0xFF065F46) : const Color(0xFF1E40AF), fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text(livraisonCA >= targetCA
                            ? 'Tu as gagné ${_formatCurrency(livraisonCA)} de Uber (cible : ${_formatCurrency(targetCA)})'
                            : 'Reste ${_formatCurrency(remainingForGoal)} à gagner (${_formatCurrency(livraisonCA)} / ${_formatCurrency(targetCA)})', style: TextStyle(fontSize: 12, color: livraisonCA >= targetCA ? const Color(0xFF047857) : const Color(0xFF1E3A8A))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (unpaidBills > 0) ...[
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A), width: 1)),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Text('Factures en attente :', style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
                  Spacer(),
                  Text(_formatCurrency(remainingBills), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                ],
              ),
            ),
          ],
          SizedBox(height: 14),
          _buildBillsSection(),
          SizedBox(height: 14),
          _progressBar(calc),
          SizedBox(height: 14),
          _buildSavingsPotential(),
          SizedBox(height: 14),
          _buildTips(calc),
          _buildChartsSection(),
        ],
      ),
    );
  }

  Widget _buildSavingsPotential() {
    final nonEssential = _currentMonthData.entries.where((e) => e.type == 'expense' && e.nonEssential).toList();
    if (nonEssential.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
        ),
        child: Row(
          children: const [
            Text('🌿', style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Économies possibles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF065F46))),
                  SizedBox(height: 2),
                  Text('Aucune dépense non essentielle', style: TextStyle(fontSize: 12, color: Color(0xFF047857))),
                ],
              ),
            ),
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
          ],
        ),
      );
    }
    final total = nonEssential.fold(0.0, (s, e) => s + e.amount);
    final sorted = [...nonEssential]..sort((a, b) => b.amount.compareTo(a.amount));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🌿', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Expanded(
                child: Text('Économies possibles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF065F46)), overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(20)),
                child: Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text('En supprimant ces dépenses, vous pourriez économiser :', style: TextStyle(fontSize: 12, color: Color(0xFF047857))),
          SizedBox(height: 12),
          ...sorted.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                SizedBox(width: 10),
                Expanded(child: Text(e.label, style: const TextStyle(fontSize: 13, color: Color(0xFF064E3B)), overflow: TextOverflow.ellipsis)),
                SizedBox(width: 8),
                Text(_formatCurrency(e.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTips(Map<String, double> calc) {
    final tips = <Map<String, String>>[];
    final nonEssentialTotal = _currentMonthData.entries.where((e) => e.type == 'expense' && e.nonEssential).fold(0.0, (s, e) => s + e.amount);
    final netBalance = calc['netBalance'] ?? 0;
    final livraisonCA = calc['livraisonCA'] ?? 0;
    final targetCA = calc['targetCA'] ?? 0;

    if (livraisonCA >= targetCA && targetCA > 0) {
      tips.add({'icon': '🎉', 'text': 'Bravo ! Vous avez atteint votre objectif !'});
    } else if (livraisonCA < targetCA && targetCA > 0) {
      final remaining = targetCA - livraisonCA;
      tips.add({'icon': '🎯', 'text': 'Encore ${_formatCurrency(remaining)} de livraisons à gagner'});
    }
    if (nonEssentialTotal > 0) {
      tips.add({'icon': '✂️', 'text': 'Économisez ${_formatCurrency(nonEssentialTotal)} en supprimant le non essentiel'});
    }
    if (netBalance < 0) {
      tips.add({'icon': '⚠️', 'text': 'Il vous manque ${_formatCurrency(-netBalance)} pour être à l\'équilibre'});
    }

    if (tips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Conseils', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF92400E))),
            ],
          ),
          SizedBox(height: 8),
          ...tips.take(3).map((t) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['icon']!, style: const TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Expanded(child: Text(t['text']!, style: const TextStyle(fontSize: 13, color: Color(0xFF78350F)), overflow: TextOverflow.ellipsis, maxLines: 2)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    final entries = _currentMonthData.entries;
    if (entries.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDay.day;

    final dailyCA = List<double>.filled(daysInMonth, 0);
    final dailyExpenses = List<double>.filled(daysInMonth, 0);
    for (final e in entries) {
      if (e.date.year == now.year && e.date.month == now.month) {
        final day = e.date.day - 1;
        if (e.type == 'income') {
          dailyCA[day] += e.amount;
        } else {
          dailyExpenses[day] += e.amount;
        }
      }
    }

    double cumCA = 0;
    double cumExp = 0;
    final cumCASpots = <FlSpot>[];
    final cumExpSpots = <FlSpot>[];
    for (int i = 0; i < daysInMonth; i++) {
      cumCA += dailyCA[i];
      cumExp += dailyExpenses[i];
      cumCASpots.add(FlSpot((i + 1).toDouble(), cumCA));
      cumExpSpots.add(FlSpot((i + 1).toDouble(), cumExp));
    }

    final uberTotal = entries.where((e) => e.type == 'income' && e.source != 'autre').fold<double>(0, (s, e) => s + e.amount);
    final aidesTotal = entries.where((e) => e.type == 'income' && e.source == 'autre').fold<double>(0, (s, e) => s + e.amount);
    final billsTotal = entries.where((e) => e.type == 'expense' && e.isBill).fold<double>(0, (s, e) => s + e.amount);
    final otherExpTotal = entries.where((e) => e.type == 'expense' && !e.isBill).fold<double>(0, (s, e) => s + e.amount);

    final hasPieData = uberTotal + aidesTotal + billsTotal + otherExpTotal > 0;
    final hasLineData = entries.any((e) => e.type == 'income' || e.type == 'expense');

    if (!hasPieData && !hasLineData) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: context.shadowColor, blurRadius: 12, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('📊', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Flexible(
                child: Text('Graphiques du mois', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.textPrimary), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (hasLineData) ...[
            Text('Évolution cumulée', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textSecondary)),
            SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 100),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9)))),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 5, getTitlesWidget: (v, m) {
                      if (v == 1 || v == daysInMonth.toDouble() || v % 10 == 0) {
                        return Padding(padding: EdgeInsets.only(top: 4), child: Text(v.toInt().toString(), style: TextStyle(fontSize: 9, color: context.textSecondary)));
                      }
                      return const SizedBox.shrink();
                    })),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 1, maxX: daysInMonth.toDouble(), minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: cumCASpots,
                      isCurved: true,
                      color: const Color(0xFF10B981),
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: const Color(0xFF10B981).withOpacity(0.15)),
                    ),
                    LineChartBarData(
                      spots: cumExpSpots,
                      isCurved: true,
                      color: const Color(0xFFEF4444),
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: const Color(0xFFEF4444).withOpacity(0.15)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _legendDot(const Color(0xFF10B981), 'Revenus'),
                SizedBox(width: 16),
                _legendDot(const Color(0xFFEF4444), 'Dépenses'),
              ],
            ),
            SizedBox(height: 16),
          ],
          if (hasPieData) ...[
            Text('Répartition', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textSecondary)),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                height: 110,
                width: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 20,
                    sections: [
                      if (uberTotal > 0) PieChartSectionData(value: uberTotal, color: const Color(0xFF10B981), radius: 32, title: '', showTitle: false),
                      if (aidesTotal > 0) PieChartSectionData(value: aidesTotal, color: const Color(0xFF3B82F6), radius: 32, title: '', showTitle: false),
                      if (billsTotal > 0) PieChartSectionData(value: billsTotal, color: const Color(0xFFF59E0B), radius: 32, title: '', showTitle: false),
                      if (otherExpTotal > 0) PieChartSectionData(value: otherExpTotal, color: const Color(0xFFEF4444), radius: 32, title: '', showTitle: false),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (uberTotal > 0) _legendRow('🚚 Uber', uberTotal, const Color(0xFF10B981)),
                if (aidesTotal > 0) _legendRow('💵 Aides', aidesTotal, const Color(0xFF3B82F6)),
                if (billsTotal > 0) _legendRow('📋 Factures', billsTotal, const Color(0xFFF59E0B)),
                if (otherExpTotal > 0) _legendRow('💸 Autres', otherExpTotal, const Color(0xFFEF4444)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
      ],
    );
  }

  Widget _legendRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: 6),
          Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: context.textSecondary), overflow: TextOverflow.ellipsis)),
          Text(_formatCurrency(value), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildBillsSection() {
    final bills = _currentMonthData.entries.where((e) => e.isBill).toList();
    if (bills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor, width: 1),
        ),
        child: Row(
          children: [
            const Text('📋', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aucune facture', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.textSecondary)),
                  SizedBox(height: 2),
                  Text('Cochez "C\'est une facture" à l\'ajout d\'une dépense', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final unpaidBills = bills.where((b) => !b.billPaid).toList();
    final paidBills = bills.where((b) => b.billPaid).toList();
    final totalBills = bills.fold(0.0, (s, b) => s + b.amount);
    final paidAmount = paidBills.fold(0.0, (s, b) => s + b.amount);
    final allPaid = unpaidBills.isEmpty;
    final remaining = totalBills - paidAmount;
    final progress = totalBills > 0 ? (paidAmount / totalBills).clamp(0.0, 1.0) : 0.0;
    final accentColor = allPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(allPaid ? '✓' : '📋', style: TextStyle(fontSize: 18, color: accentColor)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(allPaid ? 'Factures payées' : 'Factures à payer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.textPrimary)),
                    SizedBox(height: 2),
                    Text('${paidBills.length}/${bills.length} payée(s)', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatCurrency(paidAmount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
                  Text('sur ${_formatCurrency(totalBills)}', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                ],
              ),
            ],
          ),
          SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, backgroundColor: context.dividerColor, valueColor: AlwaysStoppedAnimation<Color>(accentColor), minHeight: 8),
          ),
          if (!allPaid) ...[
            SizedBox(height: 8),
            Text('Reste à payer : ${_formatCurrency(remaining)}', style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
          ],
          SizedBox(height: 12),
          ...unpaidBills.map((b) => _billTile(b)),
          if (unpaidBills.isNotEmpty && paidBills.isNotEmpty) ...[
            SizedBox(height: 14),
            Row(
              children: [
                Text('✓', style: TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w700)),
                SizedBox(width: 6),
                Text('Payées', style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
              ],
            ),
            SizedBox(height: 4),
          ],
          ...paidBills.map((b) => _billTile(b)),
        ],
      ),
    );
  }

  Widget _billTile(Entry bill) {
    return Dismissible(
      key: Key('bill-${bill.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Supprimer la facture ?'),
            content: Text('"${bill.label}" (${_formatCurrency(bill.amount)}) sera supprimée${bill.billRecurring ? '. Les futures occurrences ne seront PAS créées' : ''}.', softWrap: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        setState(() => _currentMonthData.entries.removeWhere((e) => e.id == bill.id));
        _saveState();
        _syncChargesWithBills();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: () {
          setState(() => bill.billPaid = !bill.billPaid);
          _saveState();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: bill.billPaid ? Color(0xFFF0FDF4) : context.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bill.billPaid ? Color(0xFFBBF7D0) : context.borderColor, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: bill.billPaid ? const Color(0xFF10B981) : Colors.transparent,
                  border: Border.all(color: bill.billPaid ? const Color(0xFF10B981) : const Color(0xFFD1D5DB), width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: bill.billPaid ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            bill.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: bill.billPaid ? TextDecoration.lineThrough : null,
                              color: bill.billPaid ? context.textSecondary : context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (bill.billRecurring) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                            child: const Text('🔄', style: TextStyle(fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Text(
                _formatCurrency(bill.amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: bill.billPaid ? context.textSecondary : context.textPrimary,
                  decoration: bill.billPaid ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultCard({required String label, required double value, required String detail, required bool isPrimary, double? targetValue}) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    final target = targetValue ?? 0;
    final isPositive = target > 0 ? value >= target : value >= 0;
    final color = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final bgColor = isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isPrimary ? [context.cardBackground, bgColor] : [context.cardBackground, context.surfaceVariant], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isPrimary ? color.withOpacity(0.3) : context.borderColor, width: isPrimary ? 1.5 : 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: isPrimary ? color.withOpacity(0.15) : context.dividerColor, borderRadius: BorderRadius.circular(10)),
                child: Text(isPrimary ? (isPositive ? '✓' : '⚠️') : '💰', style: TextStyle(fontSize: 18, color: isPrimary ? color : null)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 13, color: isPrimary ? color : context.textSecondary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(_formatCurrency(value), style: TextStyle(fontSize: isPrimary ? 32 : 26, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
          SizedBox(height: 4),
          Text(detail, style: TextStyle(fontSize: 12, color: context.textSecondary), softWrap: true),
        ],
      ),
    );
  }

  Widget _progressBar(Map<String, double> calc) {
    final livraisonCA = calc['livraisonCA'] ?? 0.0;
    final otherIncome = calc['otherIncome'] ?? 0.0;
    final targetCA = calc['targetCA'] ?? 0.0;
    final percent = targetCA > 0 ? (livraisonCA / targetCA * 100).clamp(0, 100) : 0.0;
    final progress = targetCA > 0 ? (livraisonCA / targetCA).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF1A73E8).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Text('🎯', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text('Progression livraison', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.textPrimary), overflow: TextOverflow.ellipsis),
              ),
              Text('${percent.round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A73E8))),
            ],
          ),
          SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, backgroundColor: context.dividerColor, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)), minHeight: 10),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatCurrency(livraisonCA), style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600)),
              Text('Objectif ${_formatCurrency(targetCA)}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ],
          ),
          if (otherIncome > 0) ...[
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: context.dividerColor, borderRadius: BorderRadius.circular(8)),
              child: Text('+ ${_formatCurrency(otherIncome)} autres revenus (hors progression)', style: TextStyle(fontSize: 11, color: context.textSecondary), softWrap: true, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final entries = [..._currentMonthData.entries]..sort((a, b) => b.date.compareTo(a.date));
    final nonEssential = entries.where((e) => e.type == 'expense' && e.nonEssential).toList();
    final shown = entries.take(20).toList();
    final hasMore = entries.length > 20;

    return _section(
      title: '📋 Historique',
      subtitle: '${entries.length} opération(s)',
      action: TextButton(onPressed: _confirmClear, child: const Text('🗑️ Tout effacer', style: TextStyle(color: Colors.red))),
      child: Column(
        children: [
          if (nonEssential.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Colors.green, width: 4))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 Économies possibles', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                  SizedBox(height: 8),
                  ...nonEssential.take(5).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text('✂️'),
                        SizedBox(width: 8),
                        Expanded(child: Text('${e.label} (${_formatCurrency(e.amount)})', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 20), onPressed: () => _deleteEntry(e.id)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          if (entries.isEmpty)
            Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [Text('📝', style: TextStyle(fontSize: 48)), SizedBox(height: 8), Text('Aucune opération', style: TextStyle(color: context.textSecondary))],
              ),
            )
          else ...[
            Container(
              constraints: const BoxConstraints(maxHeight: 420),
              decoration: BoxDecoration(
                color: context.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) => _entryItem(shown[i]),
                ),
              ),
            ),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Affichage des 20 plus récentes sur ${entries.length} opérations. Faites défiler la page pour voir le reste.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _entryItem(Entry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: entry.isCarryOver ? Color(0xFFF0FDF4) : context.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: entry.nonEssential
                ? const Color(0xFFF59E0B)
                : entry.type == 'income'
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(entry.isCarryOver ? '🔄' : (entry.type == 'income' ? (entry.source == 'autre' ? '💵' : '💰') : (entry.isBill ? '📋' : '💸')), style: const TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(entry.date),
                  style: TextStyle(fontSize: 10, color: context.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(width: 6),
          Text('${entry.type == 'income' ? '+' : '-'}${_formatCurrency(entry.amount)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: entry.type == 'income' ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
          if (!entry.isCarryOver) ...[
            InkWell(onTap: () => _showEditDialog(entry), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.edit, color: Color(0xFF1A73E8), size: 16))),
            InkWell(onTap: () => _deleteEntry(entry.id), child: Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, color: context.textSecondary, size: 16))),
          ],
        ],
      ),
    );
  }

  Widget _section({required String title, required String subtitle, required Widget child, Widget? action, Color? accentColor}) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 360;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: context.shadowColor, blurRadius: 12, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (accentColor != null) ...[
                Container(width: 4, height: 28, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
                SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: compact ? 14 : 16, fontWeight: FontWeight.w700, color: context.textPrimary), overflow: TextOverflow.ellipsis, softWrap: true),
                    SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: compact ? 11 : 12, color: context.textSecondary), overflow: TextOverflow.ellipsis, softWrap: true),
                  ],
                ),
              ),
              if (action != null) action,
            ],
          ),
          SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildCheckRow(String label, bool value, void Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13), softWrap: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({required String label, required double value, required Function(double) onChanged, required String suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
        SizedBox(height: 8),
        TextFormField(
          initialValue: value > 0 ? (value == value.roundToDouble() ? value.toInt().toString() : value.toString()) : '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          decoration: InputDecoration(suffixText: suffix, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
          onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
        ),
      ],
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  const _SettingsDialog({required this.currentThemeMode, this.onThemeModeChanged});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late ThemeMode _mode = widget.currentThemeMode;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.settings_outlined, color: AppColors.brand),
          SizedBox(width: 8),
          Text('Réglages'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apparence', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          _themeOption(ThemeMode.system, Icons.brightness_auto, 'Système', 'Suit les réglages de ton téléphone'),
          _themeOption(ThemeMode.light, Icons.light_mode, 'Clair', 'Toujours en mode clair'),
          _themeOption(ThemeMode.dark, Icons.dark_mode, 'Sombre', 'Toujours en mode sombre'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
      ],
    );
  }

  Widget _themeOption(ThemeMode mode, IconData icon, String title, String subtitle) {
    final selected = _mode == mode;
    return InkWell(
      onTap: () {
        setState(() => _mode = mode);
        widget.onThemeModeChanged?.call(mode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mode == ThemeMode.system ? '🌗 Suit le système' : mode == ThemeMode.dark ? '🌙 Mode sombre activé' : '☀️ Mode clair activé'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.brand : context.borderColor, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.brand : context.textSecondary),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppColors.brand, size: 20),
          ],
        ),
      ),
    );
  }
}

