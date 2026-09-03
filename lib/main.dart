import 'dart:async';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

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
      title: 'Budget Livreur',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
        useMaterial3: true,
      ),
      home: const HomePage(),
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
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SharedPreferences? _prefs;
  final String _storageKey = 'budget-livreur-flutter-v1';

  Map<String, double> _objectives = {
    'perso': 0,
    'fixes': 0,
    'epargne': 0,
    'urssaf': 22,
  };

  String _transferType = 'weekly';
  Map<String, MonthData> _months = {};
  String _currentMonthKey = '';
  bool _isLoading = true;
  bool _hasError = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    'objectives': GlobalKey(),
    'transfer': GlobalKey(),
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
        const Duration(seconds: 5),
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
          _transferType = data['transferType'] ?? 'weekly';
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveState() async {
    final data = {
      'objectives': _objectives,
      'transferType': _transferType,
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

    final urssafRate = (_objectives['urssaf'] ?? 22) / 100;
    final aides = _objectives['aides'] ?? 0.0;
    final netNeeds = (_objectives['perso'] ?? 0) + (_objectives['fixes'] ?? 0) + (_objectives['epargne'] ?? 0) - aides;
    final netNeedsPositive = netNeeds > 0 ? netNeeds : 0.0;
    final targetCA = urssafRate < 1 ? netNeedsPositive / (1 - urssafRate) : 0.0;
    final urssafToPay = taxableCA * urssafRate;
    final transferFees = _transferType == 'instant' ? incomeDays.length * 0.99 : 0.0;
    final netBalance = livraisonCA - urssafToPay - transferFees + otherIncome - paidExpenses;
    final netAfterBills = netBalance - unpaidBills;

    return {
      'totalCA': totalCA,
      'livraisonCA': livraisonCA,
      'otherIncome': otherIncome,
      'paidExpenses': paidExpenses,
      'unpaidBills': unpaidBills,
      'urssafToPay': urssafToPay,
      'transferFees': transferFees,
      'netBalance': netBalance,
      'netAfterBills': netAfterBills,
      'netNeeds': netNeedsPositive,
      'targetCA': targetCA,
      'carryOver': month.carryOver,
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
      'transferFees': calc['transferFees'] ?? 0.0,
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
              const SizedBox(height: 16),
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
        const SizedBox(height: 12),
        _summaryRow('💰 Revenus', incomes.length, calc['totalCA']!, Colors.green),
        _summaryRow('⛽ Dépenses', expenses.length, (calc['paidExpenses'] ?? 0) + (calc['unpaidBills'] ?? 0), Colors.red),
        const SizedBox(height: 8),
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
        const Divider(),
        _summaryRow('🏛️ URSSAF', null, calc['urssafToPay']!, Colors.orange),
        _summaryRow('💸 Frais virements', null, calc['transferFees']!, Colors.orange),
        const Divider(),
        _summaryRow('💼 Solde net', null, calc['netBalance']!, calc['netBalance']! >= 0 ? Colors.green : Colors.red),
        if (calc['carryOver']! > 0)
          _summaryRow('🔄 Report mois suivant', null, calc['carryOver']!, Colors.blue),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡 Économies réalisées', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
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
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF5F6368))),
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
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: InputDecoration(
                    labelText: 'Montant (€)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerLeft, child: Text('Source du revenu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                const SizedBox(height: 4),
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
                    const SizedBox(width: 8),
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                    child: const Text('ℹ️ Pas de prise en compte URSSAF, hors progression', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0)), softWrap: true),
                  ),
                ],
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  decoration: InputDecoration(
                    labelText: 'Montant (€)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerLeft, child: Text('Source du revenu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  const SizedBox(height: 4),
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
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Soumis à URSSAF (CA imposable)', style: TextStyle(fontSize: 14)),
                    value: taxable,
                    onChanged: source == 'autre' ? null : (v) => setDialogState(() => taxable = v ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                if (entry.type == 'expense') ...[
                  const SizedBox(height: 12),
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
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Chargement...', style: TextStyle(color: Color(0xFF5F6368))),
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
                const Text('⚠️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                const Text(
                  'Erreur de chargement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Impossible de charger les données. Réessayez ou réinstallez l\'application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5F6368)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _hasError = false;
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('💰 Budget Livreur'),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
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
                        const Icon(Icons.check, size: 18, color: Color(0xFF1A73E8)),
                      if (key == _currentMonthKey)
                        const SizedBox(width: 8),
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
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Aide',
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
                        Text(_getMonthLabel(_currentMonthKey), style: const TextStyle(fontSize: 16, color: Color(0xFF5F6368))),
                        if ((calc['targetCA'] ?? 0) > 0) ...[
                          const SizedBox(height: 6),
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
                                  const SizedBox(width: 6),
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
                  const SizedBox(height: 20),
                  Container(key: _sectionKeys['objectives'], child: _buildObjectivesSection(calc)),
                  const SizedBox(height: 16),
                  Container(key: _sectionKeys['transfer'], child: _buildTransferSection()),
                  const SizedBox(height: 16),
                  _buildActionSection(calc),
                  const SizedBox(height: 16),
                  Container(key: _sectionKeys['result'], child: _buildResultSection(calc)),
                  const SizedBox(height: 16),
                  Container(key: _sectionKeys['entries'], child: _buildHistorySection()),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNav() {
    final tabs = [
      {'key': 'objectives', 'icon': '📌', 'label': 'Besoins'},
      {'key': 'transfer', 'icon': '💳', 'label': 'Virement'},
      {'key': 'result', 'icon': '📊', 'label': 'Résultat'},
      {'key': 'entries', 'icon': '📋', 'label': 'Opérations'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
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
                      border: Border.all(color: isActive ? const Color(0xFF1A73E8) : Colors.grey.shade300, width: isActive ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Text(t['icon']!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(t['label']!, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? const Color(0xFF1A73E8) : Colors.grey.shade700)),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _inputField(label: '🏠 Charges', value: _objectives['fixes']!, onChanged: (v) { setState(() { _objectives['fixes'] = v; _autoCreateSyntheticBill(v); }); }, suffix: '€/mois')),
              const SizedBox(width: 12),
              Expanded(child: _inputField(label: '🍔 Perso', value: _objectives['perso']!, onChanged: (v) { setState(() { _objectives['perso'] = v; }); }, suffix: '€/mois')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _inputField(label: '🐷 Épargne', value: _objectives['epargne']!, onChanged: (v) { setState(() { _objectives['epargne'] = v; }); }, suffix: '€/mois')),
              const SizedBox(width: 12),
              Expanded(child: _inputField(label: '🏛️ URSSAF', value: _objectives['urssaf']!, onChanged: (v) { setState(() { _objectives['urssaf'] = v; }); }, suffix: '%')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _inputField(label: '💰 Aides (APL, RSA...)', value: aides, onChanged: (v) { setState(() { _objectives['aides'] = v; }); }, suffix: '€/mois')),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { _saveState(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Besoins enregistrés'))); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Valider mes besoins'),
            ),
          ),
          if (calc['targetCA']! > 0) ...[
            const SizedBox(height: 16),
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
                    const SizedBox(height: 6),
                    Text('${reached ? '' : '-'}${_formatCurrency(target)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: reached ? const Color(0xFF065F46) : const Color(0xFFDC2626))),
                    Text(reached ? 'Bravo ! Continuez comme ça.' : 'à gagner en livraisons (après ${_formatCurrency(_objectives['aides'] ?? 0)} d\'aides déduites)', style: TextStyle(fontSize: 12, color: reached ? const Color(0xFF047857) : const Color(0xFFB91C1C)), textAlign: TextAlign.center),
                  ],
                ),
              );
            }),
          ],
          if (_objectives['fixes']! > 0) ...[
            const SizedBox(height: 12),
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
                        const SizedBox(width: 6),
                        Text('Factures détaillées', style: TextStyle(fontSize: 12, color: ok ? const Color(0xFF065F46) : const Color(0xFF92400E), fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total : ${_formatCurrency(totalBills)}', style: TextStyle(fontSize: 12, color: ok ? const Color(0xFF065F46) : const Color(0xFF92400E))),
                        Text('Objectif : ${_formatCurrency(_objectives['fixes']!)}', style: TextStyle(fontSize: 12, color: ok ? const Color(0xFF065F46) : const Color(0xFF92400E))),
                      ],
                    ),
                    if (!ok) ...[
                      const SizedBox(height: 4),
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

  Widget _buildTransferSection() {
    return _section(
      title: '🏦 Type de virement',
      subtitle: 'Comment recevez-vous votre argent ?',
      child: Column(
        children: [
          _transferOption(value: 'weekly', icon: '📅', title: 'Hebdomadaire', subtitle: 'Gratuit', badge: 'GRATUIT', badgeColor: Colors.green),
          const SizedBox(height: 8),
          _transferOption(value: 'instant', icon: '⚡', title: 'Instantané', subtitle: '0.99€ par virement', badge: '-0.99€', badgeColor: Colors.red),
        ],
      ),
    );
  }

  Widget _transferOption({required String value, required String icon, required String title, required String subtitle, required String badge, required Color badgeColor}) {
    final isSelected = _transferType == value;
    return GestureDetector(
      onTap: () { setState(() => _transferType = value); _saveState(); },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF1A73E8) : Colors.grey.shade300, width: 2),
        ),
        child: Row(
          children: [Text(icon, style: const TextStyle(fontSize: 24)), const SizedBox(width: 12), Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)))],
          )), Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor)),
          )],
        ),
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
              const SizedBox(width: 12),
              Expanded(child: _actionButton(icon: '⛽', label: '− Dépense', color: Colors.red, onTap: _showAddExpenseDialog)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickStat('CA', calc['totalCA']!, const Color(0xFF1A73E8)),
                _quickStat('Dépenses', (calc['paidExpenses'] ?? 0) + (calc['unpaidBills'] ?? 0), Colors.red),
                _quickStat('Frais virem.', calc['transferFees']!, Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required String icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.12), color.withOpacity(0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color), overflow: TextOverflow.ellipsis, softWrap: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickStat(String label, double value, Color color) {
    return Column(
      children: [Text(_formatCurrency(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)), Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF5F6368)))],
    );
  }

  Widget _buildResultSection(Map<String, double> calc) {
    final netBalance = calc['netBalance'] ?? 0.0;
    final netAfterBills = calc['netAfterBills'] ?? netBalance;
    final netNeeds = calc['netNeeds'] ?? 0.0;
    final targetCA = calc['targetCA'] ?? 0.0;
    final livraisonCA = calc['livraisonCA'] ?? 0.0;
    final unpaidBills = calc['unpaidBills'] ?? 0.0;
    final ecart = netAfterBills - netNeeds;
    final ecartLabel = netNeeds > 0
        ? (ecart >= 0
            ? '✓ Besoins couverts (+${_formatCurrency(ecart)})'
            : '⚠️ Manque ${_formatCurrency(-ecart)} pour couvrir les ${_formatCurrency(netNeeds)} de besoins')
        : 'Définissez vos besoins dans l\'étape 1';
    return _section(
      title: '📊 Votre résultat',
      subtitle: 'Situation en temps réel',
      child: Column(
        children: [
          _resultCard(
            label: unpaidBills > 0 ? '💼 NET après factures' : '💼 NET en poche',
            value: netAfterBills,
            detail: ecartLabel,
            isPrimary: false,
          ),
          if (unpaidBills > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Text('💰', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  const Text('NET avant factures :', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const Spacer(),
                  Text(_formatCurrency(netBalance), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF374151))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildBillsSection(),
          const SizedBox(height: 14),
          _progressBar(calc),
          const SizedBox(height: 14),
          _buildSavingsPotential(),
          const SizedBox(height: 14),
          _buildTips(calc),
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
              const Text('🌿', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Économies possibles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF065F46)), overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(20)),
                child: Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('En supprimant ces dépenses, vous pourriez économiser :', style: TextStyle(fontSize: 12, color: Color(0xFF047857))),
          const SizedBox(height: 12),
          ...sorted.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(e.label, style: const TextStyle(fontSize: 13, color: Color(0xFF064E3B)), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
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
    final transferFees = calc['transferFees'] ?? 0;

    if (livraisonCA >= targetCA && targetCA > 0) {
      tips.add({'icon': '🎉', 'text': 'Bravo ! Vous avez atteint votre objectif !'});
    } else if (livraisonCA < targetCA && targetCA > 0) {
      final remaining = targetCA - livraisonCA;
      tips.add({'icon': '🎯', 'text': 'Encore ${_formatCurrency(remaining)} de livraisons à gagner'});
    }
    if (nonEssentialTotal > 0) {
      tips.add({'icon': '✂️', 'text': 'Économisez ${_formatCurrency(nonEssentialTotal)} en supprimant le non essentiel'});
    }
    if (_transferType == 'instant' && transferFees > 5) {
      tips.add({'icon': '💸', 'text': 'Virement hebdo économiserait ${_formatCurrency(transferFees)} ce mois'});
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
          const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Conseils', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF92400E))),
            ],
          ),
          const SizedBox(height: 8),
          ...tips.take(3).map((t) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['icon']!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Text(t['text']!, style: const TextStyle(fontSize: 13, color: Color(0xFF78350F)), overflow: TextOverflow.ellipsis, maxLines: 2)),
              ],
            ),
          )),
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
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: const [
            Text('📋', style: TextStyle(fontSize: 22)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aucune facture', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF374151))),
                  SizedBox(height: 2),
                  Text('Cochez "C\'est une facture" à l\'ajout d\'une dépense', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(allPaid ? 'Factures payées' : 'Factures à payer', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1F2937))),
                    const SizedBox(height: 2),
                    Text('${paidBills.length}/${bills.length} payée(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatCurrency(paidAmount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                  Text('sur ${_formatCurrency(totalBills)}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, backgroundColor: const Color(0xFFF3F4F6), valueColor: AlwaysStoppedAnimation<Color>(accentColor), minHeight: 8),
          ),
          if (!allPaid) ...[
            const SizedBox(height: 8),
            Text('Reste à payer : ${_formatCurrency(remaining)}', style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          ...unpaidBills.map((b) => _billTile(b)),
          if (unpaidBills.isNotEmpty && paidBills.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Row(
              children: [
                Text('✓', style: TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w700)),
                SizedBox(width: 6),
                Text('Payées', style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
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
            color: bill.billPaid ? const Color(0xFFF0FDF4) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bill.billPaid ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB), width: 1),
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
              const SizedBox(width: 12),
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
                              color: bill.billPaid ? const Color(0xFF9CA3AF) : const Color(0xFF1F2937),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (bill.billRecurring) ...[
                          const SizedBox(width: 6),
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
              const SizedBox(width: 8),
              Text(
                _formatCurrency(bill.amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: bill.billPaid ? const Color(0xFF9CA3AF) : const Color(0xFF1F2937),
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
    final target = targetValue ?? 0;
    final isPositive = target > 0 ? value >= target : value >= 0;
    final color = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final bgColor = isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isPrimary ? [Colors.white, bgColor] : [Colors.white, const Color(0xFFFAFBFC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isPrimary ? color.withOpacity(0.3) : const Color(0xFFE5E7EB), width: isPrimary ? 1.5 : 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: isPrimary ? color.withOpacity(0.15) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                child: Text(isPrimary ? (isPositive ? '✓' : '⚠️') : '💰', style: TextStyle(fontSize: 18, color: isPrimary ? color : null)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 13, color: isPrimary ? color : const Color(0xFF6B7280), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(_formatCurrency(value), style: TextStyle(fontSize: isPrimary ? 32 : 26, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)), softWrap: true),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
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
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Progression livraison', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1F2937)), overflow: TextOverflow.ellipsis),
              ),
              Text('${percent.round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A73E8))),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, backgroundColor: const Color(0xFFF3F4F6), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)), minHeight: 10),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatCurrency(livraisonCA), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
              Text('Objectif ${_formatCurrency(targetCA)}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
          if (otherIncome > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
              child: Text('+ ${_formatCurrency(otherIncome)} autres revenus (hors progression)', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)), softWrap: true, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final entries = [..._currentMonthData.entries]..sort((a, b) => b.date.compareTo(a.date));
    final nonEssential = entries.where((e) => e.type == 'expense' && e.nonEssential).toList();

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
                  const Text('💡 Économies possibles', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                  const SizedBox(height: 8),
                  ...nonEssential.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Text('✂️'),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${e.label} (${_formatCurrency(e.amount)})', style: const TextStyle(fontSize: 13))),
                        IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 20), onPressed: () => _deleteEntry(e.id)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [Text('📝', style: TextStyle(fontSize: 48)), SizedBox(height: 8), Text('Aucune opération', style: TextStyle(color: Color(0xFF5F6368)))],
              ),
            )
          else
            ...entries.map((e) => _entryItem(e)),
        ],
      ),
    );
  }

  Widget _entryItem(Entry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: entry.isCarryOver ? const Color(0xFFE8F5E9) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: entry.nonEssential ? Border(left: const BorderSide(color: Colors.orange, width: 4)) : null,
      ),
      child: Row(
        children: [
          Text(entry.isCarryOver ? '🔄' : (entry.type == 'income' ? '💰' : '💸'), style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(entry.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                    if (entry.nonEssential) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                        child: const Text('✂️', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${_formatDate(entry.date)}${entry.type == 'income' && entry.taxable != false ? ' • Soumis URSSAF' : ''}${entry.isCarryOver ? ' • Report auto' : ''}${entry.nonEssential ? ' • ✂️ Économisable' : ''}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                ),
              ],
            ),
          ),
          Text('${entry.type == 'income' ? '+' : '-'}${_formatCurrency(entry.amount)}', style: TextStyle(fontWeight: FontWeight.w700, color: entry.type == 'income' ? Colors.green : Colors.red)),
          if (!entry.isCarryOver) ...[
            IconButton(icon: const Icon(Icons.edit, color: Color(0xFF1A73E8), size: 20), onPressed: () => _showEditDialog(entry)),
            IconButton(icon: const Icon(Icons.close, color: Color(0xFF5F6368), size: 20), onPressed: () => _deleteEntry(entry.id)),
          ],
        ],
      ),
    );
  }

  Widget _section({required String title, required String subtitle, required Widget child, Widget? action, Color? accentColor}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (accentColor != null) ...[
                Container(width: 4, height: 28, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 18),
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
            const SizedBox(width: 8),
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
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368))),
        const SizedBox(height: 8),
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

