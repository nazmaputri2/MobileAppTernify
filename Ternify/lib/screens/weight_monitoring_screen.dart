import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

// ─── Model internal ──────────────────────────────────────────────────────────
class _MonthlyBerat {
  final int year;
  final int month;
  final String label;
  final double berat;

  const _MonthlyBerat({
    required this.year,
    required this.month,
    required this.label,
    required this.berat,
  });
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class WeightMonitoringScreen extends StatefulWidget {
  final String idDomba;
  final String earTag;

  const WeightMonitoringScreen({
    super.key,
    required this.idDomba,
    required this.earTag,
  });

  @override
  State<WeightMonitoringScreen> createState() => _WeightMonitoringScreenState();
}

class _WeightMonitoringScreenState extends State<WeightMonitoringScreen>
    with SingleTickerProviderStateMixin {
  // ── Constants ───────────────────────────────────────────────────────────────
  static const Color navyDark  = Color(0xFF1A2B45);
  static const Color navyMid   = Color(0xFF243655);
  static const Color beigeLight = Color(0xFFFAF7F2);
  static const Color textMuted = Color(0xFF8A9BB0);
  static const Color accent    = Color(0xFF4A90E2);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentRed   = Color(0xFFE53935);
  static const Color accentOrange = Color(0xFFFF9800);

  // ── State ───────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;
  List<_MonthlyBerat> _monthly = [];
  double? _beratSekarang;
  double? _perubahanBerat;
  double? _rataRataPertumbuhan;
  bool _growthAlert = false;
  int? _lastIncreaseDays;
  int _touchedIndex = -1;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _touchedIndex = -1;
    });
    try {
      final data = await ApiService.fetchBeratHistory(widget.idDomba);
      final rawMonthly = (data['monthly'] as List? ?? []);
      setState(() {
        _monthly = rawMonthly.map((m) => _MonthlyBerat(
          year: (m['year'] as num).toInt(),
          month: (m['month'] as num).toInt(),
          label: m['label'] as String,
          berat: (m['berat'] as num).toDouble(),
        )).toList();
        _beratSekarang = data['berat_sekarang'] != null
            ? (data['berat_sekarang'] as num).toDouble()
            : null;
        _perubahanBerat = data['perubahan_berat'] != null
            ? (data['perubahan_berat'] as num).toDouble()
            : null;
        _rataRataPertumbuhan = data['rata_rata_pertumbuhan'] != null
            ? (data['rata_rata_pertumbuhan'] as num).toDouble()
            : null;
        _growthAlert = data['growth_alert'] as bool? ?? false;
        _lastIncreaseDays = data['last_increase_days'] as int?;
        _isLoading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _formatChange(double? val, {String suffix = ' kg'}) {
    if (val == null) return '-';
    final sign = val >= 0 ? '+' : '';
    return '$sign${val.toStringAsFixed(1)}$suffix';
  }

  Color _changeColor(double? val) {
    if (val == null) return textMuted;
    return val >= 0 ? accentGreen : accentRed;
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beigeLight,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: FadeTransition(
                          opacity: _fadeAnim,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                            children: [
                              if (_growthAlert) ...[
                                _buildGrowthAlert(),
                                const SizedBox(height: 16),
                              ],
                              if (_beratSekarang != null) ...[
                                _buildCurrentWeightCard(),
                                const SizedBox(height: 16),
                              ],
                              _buildStatsRow(),
                              const SizedBox(height: 16),
                              _buildChartCard(),
                              const SizedBox(height: 16),
                              if (_monthly.isNotEmpty) _buildHistoryTable(),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white70,
                    size: 16,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monitoring Berat',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.earTag,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha(153),
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Growth Alert ─────────────────────────────────────────────────────────────
  Widget _buildGrowthAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFFBF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentOrange.withAlpha(80), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentOrange.withAlpha(25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentOrange.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: accentOrange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Growth Alert',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentOrange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '⚠️  Perhatian',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Berat Domba ${widget.earTag} tidak mengalami peningkatan dalam '
                  '${_lastIncreaseDays ?? 30} hari terakhir.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: navyDark,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentOrange.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 13, color: accentOrange),
                      SizedBox(width: 6),
                      Text(
                        'Periksa kondisi pakan & kesehatan domba',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Current Weight Card ───────────────────────────────────────────────────────
  Widget _buildCurrentWeightCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, Color(0xFF2C4169)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: navyDark.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.monitor_weight_outlined, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BERAT SEKARANG',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withAlpha(160),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_beratSekarang!.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_perubahanBerat != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Total perubahan',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withAlpha(140),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (_perubahanBerat! >= 0 ? accentGreen : accentRed).withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatChange(_perubahanBerat),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _perubahanBerat! >= 0 ? const Color(0xFF81C784) : const Color(0xFFEF9A9A),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Perubahan Berat',
            value: _formatChange(_perubahanBerat),
            icon: Icons.trending_up_rounded,
            color: _changeColor(_perubahanBerat),
            sub: 'total keseluruhan',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Rata-rata Pertumbuhan',
            value: _formatChange(_rataRataPertumbuhan, suffix: ' kg/bln'),
            icon: Icons.show_chart_rounded,
            color: accent,
            sub: 'per bulan',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: 'Total Catatan',
            value: '${_monthly.length}',
            icon: Icons.bar_chart_rounded,
            color: navyDark,
            sub: 'bulan tercatat',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.w600),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 9, color: textMuted),
          ),
        ],
      ),
    );
  }

  // ── Chart ────────────────────────────────────────────────────────────────────
  Widget _buildChartCard() {
    if (_monthly.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Belum ada data berat tercatat',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 4),
            Text(
              'Tambahkan rekam medis dengan berat badan\nuntuk melihat grafik pertumbuhan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    final spots = _monthly.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.berat);
    }).toList();

    final allWeights = _monthly.map((m) => m.berat).toList();
    final minY = allWeights.reduce(math.min);
    final maxY = allWeights.reduce(math.max);
    final padding = math.max((maxY - minY) * 0.3, 5.0);
    final chartMinY = math.max(0.0, minY - padding);
    final chartMaxY = maxY + padding;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.show_chart_rounded, size: 18, color: accent),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Grafik Pertumbuhan Berat',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: navyDark,
                  ),
                ),
                const Spacer(),
                Text(
                  'per bulan',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.only(right: 18, left: 8, bottom: 8),
              child: LineChart(
                duration: const Duration(milliseconds: 400),
                LineChartData(
                  minY: chartMinY,
                  maxY: chartMaxY,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      if (response?.lineBarSpots != null &&
                          response!.lineBarSpots!.isNotEmpty) {
                        setState(() {
                          _touchedIndex = response.lineBarSpots!.first.spotIndex;
                        });
                      } else if (event is FlPanEndEvent || event is FlTapUpEvent) {
                        setState(() => _touchedIndex = -1);
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => navyDark,
                      getTooltipItems: (spots) => spots.map((s) {
                        final idx = s.spotIndex;
                        final m = _monthly[idx];
                        return LineTooltipItem(
                          '${m.label}\n',
                          const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: '${m.berat.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: math.max((chartMaxY - chartMinY) / 4, 1),
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: const Color(0xFFF0EDE8),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: math.max((chartMaxY - chartMinY) / 4, 1),
                        getTitlesWidget: (v, _) => Text(
                          '${v.toStringAsFixed(0)} kg',
                          style: const TextStyle(fontSize: 9, color: textMuted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _monthly.length <= 6 ? 1 : (_monthly.length / 4).ceilToDouble(),
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= _monthly.length) return const SizedBox.shrink();
                          final dt = _monthly[idx];
                          final monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                              'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${monthNames[dt.month]}\n${dt.year.toString().substring(2)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                color: _touchedIndex == idx ? navyDark : textMuted,
                                fontWeight: _touchedIndex == idx
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: accent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) {
                          final isTouched = idx == _touchedIndex;
                          return FlDotCirclePainter(
                            radius: isTouched ? 6 : 4,
                            color: isTouched ? accent : Colors.white,
                            strokeWidth: 2.5,
                            strokeColor: accent,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            accent.withAlpha(60),
                            accent.withAlpha(0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── History Table ─────────────────────────────────────────────────────────────
  Widget _buildHistoryTable() {
    final reversed = _monthly.reversed.toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Riwayat Berat',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: navyDark,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDE8)),
          ...reversed.asMap().entries.map((e) {
            final idx = e.key;
            final m = e.value;
            // Previous in reversed list = newer in original, for delta calculation
            // Find this item in original list
            final origIdx = _monthly.indexOf(m);
            double? delta;
            if (origIdx > 0) {
              delta = m.berat - _monthly[origIdx - 1].berat;
            }
            final isLast = idx == reversed.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(bottom: BorderSide(color: Color(0xFFF5F2EE), width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: navyDark,
                      ),
                    ),
                  ),
                  if (delta != null) ...[
                    Text(
                      '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: 11,
                        color: delta >= 0 ? accentGreen : accentRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    '${m.berat.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: navyDark,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textMuted),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: navyDark),
            child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
