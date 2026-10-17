import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../repositories/domba_repository.dart';
import '../repositories/kandang_repository.dart';
import '../services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // warna statis
  static const Color navyDark = Color(0xFF1A2B45);
  static const Color beigeLight = Color(0xFFFAF7F2);
  static const Color textMuted = Color(0xFF8A9BB0);
  static const Color cardWhite = Colors.white;
  static const Color healthy = Color(0xFF1A2B45);
  static const Color pregnant = Color(0xFFCFBFA5);
  static const Color sick = Color(0xFFD0D5DD);

  // Warna pra-kalkulasi
  static const Color _whiteOpacity55 = Color(0x8CFFFFFF);
  static const Color _whiteOpacity10 = Color(0x1AFFFFFF);
  static const Color _whiteOpacity15 = Color(0x26FFFFFF);
  static const Color _whiteOpacity20 = Color(0x33FFFFFF);
  static const Color _blackOpacity05 = Color(0x0D000000);
  static const Color _blackOpacity04 = Color(0x0A000000);

  // Repositories
  final DombaRepository _dombaRepo = DombaRepository();
  final KandangRepository _kandangRepo = KandangRepository();

  // State
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _userData;

  // Data dari API
  int _totalDomba = 0;
  int _totalJantan = 0;
  int _totalBetina = 0;
  int _totalKandang = 0;
  int _statusSehat = 0;
  int _statusBunting = 0;
  int _statusSakit = 0;
  List<Map<String, dynamic>> _dombaTerbaru = [];
  int _unreadNotifCount = 0;
  final NotificationService _notifService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notifService.requestPermission();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch semua data secara paralel
      final dombaStatsFuture = _dombaRepo.fetchStatistik();
      final kandangStatsFuture = _kandangRepo.fetchStatistik();
      final userDataFuture = ApiService.getSavedUser();

      final dombaStats = await dombaStatsFuture;
      final kandangStats = await kandangStatsFuture;
      final userData = await userDataFuture;

      if (!mounted) return;

      final status = dombaStats['status'] as Map<String, dynamic>? ?? {};
      final terbaruRaw = dombaStats['domba_terbaru'] as List? ?? [];

      setState(() {
        _totalDomba = (dombaStats['total_domba'] as num?)?.toInt() ?? 0;
        _totalJantan = (dombaStats['total_jantan'] as num?)?.toInt() ?? 0;
        _totalBetina = (dombaStats['total_betina'] as num?)?.toInt() ?? 0;
        _totalKandang = kandangStats['total_kandang'] ?? 0;

        _statusSehat = (status['sehat'] as num?)?.toInt() ?? 0;
        _statusBunting = (status['bunting'] as num?)?.toInt() ?? 0;
        _statusSakit = (status['sakit'] as num?)?.toInt() ?? 0;

        _dombaTerbaru = terbaruRaw
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();

        _userData = userData;
        _isLoading = false;
      });

      // Ambil notifikasi setelah dashboard load untuk menghitung unread
      final notifItems = await _notifService.fetchNotifikasi();
      if (mounted) {
        setState(() {
          _unreadNotifCount = notifItems.where((n) => !n.dibaca).length;
        });
        // Tampilkan sistem pop-up untuk yang penting
        await _notifService.pushPriorityNotifications(notifItems);
      }

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String get _todayFormatted {
    final now = DateTime.now();
    final days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    final months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month]} ${now.year}';
  }

  String get _userInitials {
    final nama = _userData?['nama_lengkap'] as String? ?? '';
    if (nama.isEmpty) return '?';
    final parts = nama.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return nama[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beigeLight,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: navyDark),
                  )
                : _errorMessage != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _loadDashboardData,
                    color: navyDark,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RepaintBoundary(child: _buildSummaryCards()),
                          const SizedBox(height: 16),
                          RepaintBoundary(child: _buildWeightChart()),
                          const SizedBox(height: 16),
                          RepaintBoundary(child: _buildHealthStatus()),
                          const SizedBox(height: 20),
                          RepaintBoundary(child: _buildRecentDomba()),
                          const SizedBox(height: 20),
                          RepaintBoundary(child: _buildAlerts()),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: navyDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: navyDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2B45), Color(0xFF243655)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _todayFormatted,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _whiteOpacity55,
                      ),
                    ),
                  ],
                ),
              ),

              // Bell
              GestureDetector(
                onTap: () async {
                  await Navigator.pushNamed(context, '/notifikasi');
                  // Update counter setelah kembali dari halaman notifikasi
                  final count = await _notifService.getUnreadCount();
                  if (mounted && count != _unreadNotifCount) {
                    setState(() => _unreadNotifCount = count);
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _whiteOpacity10,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _whiteOpacity20, width: 1),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      if (_unreadNotifCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD92D20), // Merah mencolok
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _whiteOpacity15,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _whiteOpacity20, width: 1),
                ),
                child: Center(
                  child: Text(
                    _userInitials,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: navyDark,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 125,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            children: [
              // Card 1: Total Domba
              _buildMetricCard(
                title: 'Total Domba',
                value: '$_totalDomba',
                icon: Icons.pets_outlined,
                iconColor: const Color(0xFF1E88E5), // Professional Blue
                subtext: '$_totalJantan Jantan  •  $_totalBetina Betina',
                subtextColor: const Color(0xFF667085),
              ),
              const SizedBox(width: 12),
              
              // Card 2: Kandang
              _buildMetricCard(
                title: 'Kandang Aktif',
                value: '$_totalKandang',
                icon: Icons.home_work_outlined,
                iconColor: const Color(0xFF039855), // Professional Green
                subtext: _totalKandang > 0 ? 'Sedang digunakan' : 'Data kosong',
                subtextColor: _totalKandang > 0 ? const Color(0xFF039855) : const Color(0xFF667085),
              ),
              const SizedBox(width: 12),

              // Card 3: Perawatan
              _buildMetricCard(
                title: 'Perhatian Khusus',
                value: '$_statusSakit',
                icon: _statusSakit > 0 ? Icons.error_outline : Icons.check_circle_outline,
                iconColor: _statusSakit > 0 ? const Color(0xFFD92D20) : const Color(0xFF039855), // Red / Green
                subtext: _statusSakit > 0 ? 'Domba butuh dicek' : 'Semua ternak sehat',
                subtextColor: _statusSakit > 0 ? const Color(0xFFD92D20) : const Color(0xFF039855),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String subtext,
    required Color subtextColor,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECF0), width: 1.5), // Clean thin grey border
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000), // Barely visible shadow for depth
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF475467), // Modern grey text
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: navyDark, // Keeping app identity
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtext,
            style: TextStyle(
              color: subtextColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    // Distribusi gender sebagai chart sederhana
    final total = _totalDomba > 0 ? _totalDomba : 1;
    final jantanFrac = _totalJantan / total;
    final betinaFrac = _totalBetina / total;

    final data = [
      {
        'label': 'Jantan',
        'value': _totalJantan,
        'frac': jantanFrac,
        'color': const Color(0xFF2D4A6E),
      },
      {
        'label': 'Betina',
        'value': _totalBetina,
        'frac': betinaFrac,
        'color': const Color(0xFFCFBFA5),
      },
      {
        'label': 'Sehat',
        'value': _statusSehat,
        'frac': _statusSehat / total,
        'color': const Color(0xFF4CAF50),
      },
      {
        'label': 'Bunting',
        'value': _statusBunting,
        'frac': _statusBunting / total,
        'color': const Color(0xFFFF9800),
      },
      {
        'label': 'Sakit',
        'value': _statusSakit,
        'frac': _statusSakit / total,
        'color': const Color(0xFFE53935),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: _blackOpacity05,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribusi Domba',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: navyDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(data.length, (i) {
                final d = data[i];
                final h = (d['frac'] as double).clamp(0.05, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${d['value']}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: navyDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: h,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: d['color'] as Color,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d['label'] as String,
                          style: const TextStyle(
                            fontSize: 10,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthStatus() {
    final total = _statusSehat + _statusBunting + _statusSakit;
    final safeTotal = total > 0 ? total : 1;
    final sehatPct = (_statusSehat / safeTotal * 100).round();
    final buntingPct = (_statusBunting / safeTotal * 100).round();
    final sakitPct = (_statusSakit / safeTotal * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: _blackOpacity05,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Kesehatan',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: navyDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Donut chart
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _DonutPainter(
                    sehat: _statusSehat,
                    bunting: _statusBunting,
                    sakit: _statusSakit,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: navyDark,
                          ),
                        ),
                        const Text(
                          'ekor',
                          style: TextStyle(fontSize: 10, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Legend
              Expanded(
                child: Column(
                  children: [
                    _buildLegendRow(
                      'Sehat',
                      '$_statusSehat ($sehatPct%)',
                      healthy,
                    ),
                    const SizedBox(height: 10),
                    _buildLegendRow(
                      'Bunting',
                      '$_statusBunting ($buntingPct%)',
                      pregnant,
                    ),
                    const SizedBox(height: 10),
                    _buildLegendRow(
                      'Sakit',
                      '$_statusSakit ($sakitPct%)',
                      sick,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: textMuted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: navyDark,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentDomba() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Domba Terbaru',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: navyDark,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/data-domba'),
              child: const Text(
                'Lihat Semua →',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2D5A8E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_dombaTerbaru.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: _blackOpacity04,
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Belum ada data domba',
                style: TextStyle(fontSize: 13, color: textMuted),
              ),
            ),
          )
        else
          ...List.generate(_dombaTerbaru.length, (i) {
            final item = _dombaTerbaru[i];
            final earTag = item['ear_tag'] ?? '-';
            final status = item['status'] ?? 'Sehat';
            final jk = item['jenis_kelamin'] ?? '';
            final createdAt = item['created_at'] ?? '';

            // Format tanggal
            String dateLabel = '-';
            try {
              if (createdAt.isNotEmpty) {
                final dt = DateTime.parse(createdAt);
                final months = [
                  'Jan',
                  'Feb',
                  'Mar',
                  'Apr',
                  'Mei',
                  'Jun',
                  'Jul',
                  'Agu',
                  'Sep',
                  'Okt',
                  'Nov',
                  'Des',
                ];
                dateLabel =
                    '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
              }
            } catch (_) {}

            // Status color
            Color statusColor;
            Color statusBg;
            if (status == 'Sakit') {
              statusColor = const Color(0xFFE53935);
              statusBg = const Color(0x1AE53935);
            } else if (status == 'Bunting') {
              statusColor = const Color(0xFFFF9800);
              statusBg = const Color(0x1AFF9800);
            } else {
              statusColor = const Color(0xFF4CAF50);
              statusBg = const Color(0x1A4CAF50);
            }

            // Ikon jenis kelamin
            IconData jkIcon = jk == 'betina' ? Icons.female : Icons.male;

            return GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/data-domba'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: _blackOpacity04,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDE6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(jkIcon, size: 18, color: textMuted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            earTag,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: navyDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dateLabel · ${jk == 'jantan' ? 'Jantan' : 'Betina'}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Colors.grey.shade300,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAlerts() {
    // Generate alerts dari data nyata
    final List<Map<String, dynamic>> alerts = [];

    if (_statusSakit > 0) {
      alerts.add({
        'message':
            '⚠️  $_statusSakit domba dengan status sakit perlu perhatian',
        'bg': const Color(0xFFFFF3CD),
        'border': const Color(0x4DE6A817),
        'route': '/data-domba',
      });
    }

    if (_statusBunting > 0) {
      alerts.add({
        'message':
            '🐑  $_statusBunting domba bunting — pastikan perawatan ekstra',
        'bg': const Color(0xFFE8F5E9),
        'border': const Color(0x4D4CAF50),
        'route': '/data-domba',
      });
    }

    if (alerts.isEmpty) {
      alerts.add({
        'message': '✔  Semua domba dalam kondisi baik — tidak ada peringatan',
        'bg': const Color(0xFFF0F0F0),
        'border': const Color(0x4D888888),
        'route': null,
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Peringatan',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: navyDark,
          ),
        ),
        const SizedBox(height: 10),
        ...alerts.map((a) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: a['route'] != null
                  ? () => Navigator.pushNamed(context, a['route'] as String)
                  : null,
              child: _buildAlertCard(
                a['message'] as String,
                a['bg'] as Color,
                a['border'] as Color,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAlertCard(String message, Color bg, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: navyDark, height: 1.4),
      ),
    );
  }
}

// Notif dot widget — const untuk menghindari rebuild
// Dihapus

// ── Donut chart painter ──
class _DonutPainter extends CustomPainter {
  final int sehat;
  final int bunting;
  final int sakit;

  _DonutPainter({
    required this.sehat,
    required this.bunting,
    required this.sakit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 10.0;

    final total = sehat + bunting + sakit;
    if (total == 0) {
      // Draw empty circle
      final emptyPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = const Color(0xFFE0E0E0);
      canvas.drawCircle(center, radius, emptyPaint);
      return;
    }

    final segments = [
      {'fraction': sehat / total, 'color': const Color(0xFF1A2B45)},
      {'fraction': bunting / total, 'color': const Color(0xFFCFBFA5)},
      {'fraction': sakit / total, 'color': const Color(0xFFD0D5DD)},
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;
    const gap = 0.05;

    for (final seg in segments) {
      final fraction = seg['fraction'] as double;
      if (fraction <= 0) continue;
      final sweepAngle = fraction * 2 * math.pi - gap;
      paint.color = seg['color'] as Color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += fraction * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.sehat != sehat ||
      oldDelegate.bunting != bunting ||
      oldDelegate.sakit != sakit;
}
