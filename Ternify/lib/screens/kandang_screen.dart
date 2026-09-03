import 'package:flutter/material.dart';
import '../models/kandang_model.dart';
import '../models/rekam_medis_model.dart';
import '../models/perkawinan_model.dart';
import '../repositories/kandang_repository.dart';
import '../services/api_service.dart';
import '../widgets/app_popup.dart';
import 'weight_monitoring_screen.dart';

import '../models/domba_model.dart';
import'../repositories/domba_repository.dart';

class KandangScreen extends StatefulWidget {
  const KandangScreen({super.key});

  @override
  State<KandangScreen> createState() => _KandangScreenState();
}

class _KandangScreenState extends State<KandangScreen> {
  static const Color navyDark = Color(0xFF1A2B45);
  static const Color beigeLight = Color(0xFFFAF7F2);
  static const Color textMuted = Color(0xFF8A9BB0);
  static const Color cardWhite = Colors.white;
  static const Color redAccent = Color(0xFFD94F4F);

  // Pre-computed opacity colors
  static const Color _whiteOpacity55 = Color(0x8CFFFFFF);
  static const Color _whiteOpacity10 = Color(0x1AFFFFFF);
  static const Color _whiteOpacity60 = Color(0x99FFFFFF);
  static const Color _blackOpacity05 = Color(0x0D000000);
  static const Color _blackOpacity06 = Color(0x0F000000);

final DombaRepository _dombaRepo = DombaRepository();
void _showAssignDombaSheet(Kandang kandang) {
  showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AssignDombaSheet(
      kandang: kandang,
      dombaRepo: _dombaRepo,
      kandangRepo: _repo,
    ),
  ).then((result) {
    if (result == true) {
      _loadAll();
    }
  });
}

void _showDombaKandangSheet(Kandang kandang) {
  showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DombaKandangSheet(
      kandang: kandang,
      kandangRepo: _repo,
      dombaRepo: _dombaRepo,
      onAddMore: () {
        Navigator.pop(context);
        _showAssignDombaSheet(kandang);
      },
    ),
  ).then((_) {
    // Always reload to sync domba counts after management
    _loadAll();
  });
}

  final KandangRepository _repo = KandangRepository();

  List<Kandang> _kandangList = [];
  Map<String, int> _stats = {'total_kandang': 0, 'total_domba': 0};
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final results = await Future.wait([
        _repo.fetchKandang(),
        _repo.fetchStatistik(),
      ]);
      if (mounted) {
        setState(() {
          _kandangList = results[0] as List<Kandang>;
          _stats = results[1] as Map<String, int>;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beigeLight,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? _buildError()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCards(),
                          const SizedBox(height: 18),
                          ..._kandangList.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildKandangCard(e.value, e.key),
                            ),
                          ),
                          _buildTambahKandang(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: textMuted),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadAll, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  // â”€â”€ AppBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildAppBar() {
    final total = _stats['total_kandang'] ?? 0;
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
                      'Kandang',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total kandang aktif',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _whiteOpacity55,
                      ),
                    ),
                  ],
                ),
              ),
              _notifButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notifButton() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _whiteOpacity10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.notifications_outlined,
            color: Colors.white70,
            size: 20,
          ),
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B6B),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Summary Cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSummaryCards() {
    final statsDisplay = [
      {'label': 'Total Kandang', 'value': '${_stats['total_kandang'] ?? 0}', 'tappable': false},
      {'label': 'Aktif', 'value': '${_stats['total_kandang'] ?? 0}', 'tappable': false},
      {'label': 'Total Domba', 'value': '${_stats['total_domba_semua'] ?? _stats['total_domba'] ?? 0}', 'tappable': true},
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statsDisplay.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final isFirst = i == 0;
          final isTappable = statsDisplay[i]['tappable'] == true;
          final card = Container(
            width: 118,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: isFirst
                  ? const Border(bottom: BorderSide(color: navyDark, width: 3))
                  : isTappable
                      ? const Border(bottom: BorderSide(color: Color(0xFFFF9800), width: 3))
                      : null,
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
                Row(
                  children: [
                    Text(
                      statsDisplay[i]['value'] as String,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),
                    if (isTappable) ...[
                      const Spacer(),
                      Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                    ],
                  ],
                ),
                const Spacer(),
                Text(
                  statsDisplay[i]['label'] as String,
                  style: const TextStyle(fontSize: 11.5, color: textMuted),
                ),
              ],
            ),
          );

          if (isTappable) {
            return GestureDetector(
              onTap: _showSemuaDombaSheet,
              child: card,
            );
          }
          return card;
        },
      ),
    );
  }

  void _showSemuaDombaSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SemuaDombaSheet(kandangRepo: _repo),
    );
  }

  // â”€â”€ Kandang Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildKandangCard(Kandang k, int index) {
    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: _blackOpacity06,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              color: navyDark,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  k.namaKandang,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${k.idKandang} Â· ${k.tipeKandang ?? '-'}',
                  style: TextStyle(fontSize: 12, color: _whiteOpacity55),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                _statBox('${k.jumlahDomba}', 'Domba'),
                const SizedBox(width: 8),
                _statBox('${k.kapasitas}', 'Kapasitas'),
                const SizedBox(width: 8),
                _statBox('${k.persentaseIsiDisplay}%', 'Isi'),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: k.persentaseIsi,
                minHeight: 6,
                backgroundColor: const Color(0xFFEEE9DF),
                valueColor: const AlwaysStoppedAnimation<Color>(navyDark),
              ),
            ),
          ),

          // Tipe kandang info
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text(
              k.tipeKandang ?? '-',
              style: const TextStyle(fontSize: 12, color: textMuted),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                _actionButton(
                  'Edit',
                  Colors.white,
                  navyDark,
                  const Color(0xFFBFB8A8),
                  onTap: () => _showFormSheet(kandang: k),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  'Domba',
                  const Color(0xFFEAE4D8),
                  navyDark,
                  Colors.transparent,
                onTap: () => _showDombaKandangSheet(k),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  'Hapus',
                  redAccent,
                  Colors.white,
                  redAccent,
                  onTap: () => _showDeleteDialog(k),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0E8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: navyDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 11, color: textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    String label,
    Color bg,
    Color fg,
    Color border, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 1.3),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€ Tambah Kandang Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildTambahKandang() {
    return GestureDetector(
      onTap: () => _showFormSheet(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFFF0ECE4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFB8A8), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _whiteOpacity60,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: navyDark, size: 20),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tambah Kandang Baru',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: navyDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Form Sheet (Tambah & Edit) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showFormSheet({Kandang? kandang}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KandangFormSheet(
        kandang: kandang,
        onSave: (payload) async {
          try {
            if (kandang == null) {
              await _repo.createKandang(payload);
            } else {
              await _repo.updateKandang(kandang.idKandang, payload);
            }
            if (mounted) {
              Navigator.pop(context);
              AppPopup.show(
                context,
                message: kandang == null
                    ? 'Kandang berhasil ditambahkan.'
                    : 'Kandang berhasil diperbarui.',
              );
              _loadAll();
            }
          } catch (e) {
            if (mounted) {
              AppPopup.show(context, message: e.toString(), isError: true);
            }
          }
        },
      ),
    );
  }

  // â”€â”€ Delete Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showDeleteDialog(Kandang k) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus ${k.namaKandang}?',
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 17,
            color: navyDark,
          ),
        ),
        content: Text(
          k.jumlahDomba > 0
              ? 'Kandang ini masih berisi ${k.jumlahDomba} domba. Pindahkan domba terlebih dahulu sebelum menghapus.'
              : 'Data kandang ini akan dihapus secara permanen.',
          style: const TextStyle(fontSize: 13.5, color: textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: textMuted)),
          ),
          if (k.jumlahDomba == 0)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _repo.deleteKandang(k.idKandang);
                  if (mounted) {
                    AppPopup.show(
                      context,
                      message: 'Kandang berhasil dihapus.',
                    );
                    _loadAll();
                  }
                } catch (e) {
                  if (mounted) {
                    AppPopup.show(
                      context,
                      message: e.toString(),
                      isError: true,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text('Hapus'),
            ),
        ],
      ),
    );
  }
}

class _AssignDombaSheet extends StatefulWidget {
  final Kandang kandang;
  final DombaRepository dombaRepo;
  final KandangRepository kandangRepo;

  const _AssignDombaSheet({
    required this.kandang,
    required this.dombaRepo,
    required this.kandangRepo,
  });

  @override
  State<_AssignDombaSheet> createState() => _AssignDombaSheetState();
}

class _AssignDombaSheetState extends State<_AssignDombaSheet> {
  static const Color navyDark = Color(0xFF1A2B45);
  static const Color beigeLight = Color(0xFFFAF7F2);
  static const Color textMuted = Color(0xFF8A9BB0);

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<Domba> _dombaList = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadDomba();
  }

  Future<void> _loadDomba() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.dombaRepo.fetchBelumKandang();

      if (mounted) {
        setState(() {
          _dombaList = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) {
      AppPopup.show(
        context,
        message: 'Pilih minimal 1 domba.',
        isError: true,
      );
      return;
    }

    final sisaKapasitas = widget.kandang.kapasitas - widget.kandang.jumlahDomba;

    if (_selectedIds.length > sisaKapasitas) {
      AppPopup.show(
        context,
        message: 'Jumlah domba melebihi sisa kapasitas kandang.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.kandangRepo.assignDombaToKandang(
        idKandang: widget.kandang.idKandang,
        dombaIds: _selectedIds.toList(),
      );

      if (mounted) {
        AppPopup.show(
          context,
          message: 'Domba berhasil dimasukkan ke kandang.',
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(
          context,
          message: e.toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sisaKapasitas = widget.kandang.kapasitas - widget.kandang.jumlahDomba;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: beigeLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFD5CFBF),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tambah Domba ke ${widget.kandang.namaKandang}',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: navyDark,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: navyDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sisa kapasitas: $sisaKapasitas domba',
              style: const TextStyle(
                fontSize: 12.5,
                color: textMuted,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : _dombaList.isEmpty
                        ? const Center(
                            child: Text(
                              'Belum ada domba hasil scan yang belum masuk kandang.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _dombaList.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: Color(0xFFE8E3DA),
                            ),
                            itemBuilder: (context, index) {
                              final d = _dombaList[index];
                              final selected = _selectedIds.contains(d.idDomba);

                              return CheckboxListTile(
                                value: selected,
                                activeColor: navyDark,
                                onChanged: _isSaving
                                    ? null
                                    : (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedIds.add(d.idDomba);
                                          } else {
                                            _selectedIds.remove(d.idDomba);
                                          }
                                        });
                                      },
                                title: Text(
                                  d.earTag,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: navyDark,
                                  ),
                                ),
                                subtitle: Text(
                                  '${d.idBangsa ?? '-'} Â· ${d.jenisKelaminLabel}',
                                  style: const TextStyle(color: textMuted),
                                ),
                              );
                            },
                          ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: navyDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Simpan ${_selectedIds.length} Domba',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Domba Kandang Sheet (Kelola Domba di Kandang) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DombaKandangSheet extends StatefulWidget {
  final Kandang kandang;
  final KandangRepository kandangRepo;
  final DombaRepository dombaRepo;
  final VoidCallback onAddMore;

  const _DombaKandangSheet({
    required this.kandang,
    required this.kandangRepo,
    required this.dombaRepo,
    required this.onAddMore,
  });

  @override
  State<_DombaKandangSheet> createState() => _DombaKandangSheetState();
}

class _DombaKandangSheetState extends State<_DombaKandangSheet> {
  static const Color navyDark = Color(0xFF1A2B45);
  static const Color beigeLight = Color(0xFFFAF7F2);
  static const Color textMuted = Color(0xFF8A9BB0);
  static const Color redAccent = Color(0xFFD94F4F);

  bool _isLoading = true;
  String? _errorMessage;
  List<Domba> _dombaList = [];
  bool _dataChanged = false;

  @override
  void initState() {
    super.initState();
    _loadDomba();
  }

  Future<void> _loadDomba() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.kandangRepo.fetchDombaByKandang(
        widget.kandang.idKandang,
      );
      if (mounted) {
        setState(() => _dombaList = result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _genderColor(String jk) {
    return jk == 'jantan' ? const Color(0xFF2196F3) : const Color(0xFFE91E63);
  }

  Color _genderBg(String jk) {
    return jk == 'jantan' ? const Color(0xFFE3F2FD) : const Color(0xFFFCE4EC);
  }

  void _showDetailModal(Domba d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailDombaModal(
        domba: d,
        genderColor: _genderColor,
        genderBg: _genderBg,
        onEdit: () {
          Navigator.pop(context);
          _openEditForm(d);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmRemoveFromKandang(d);
        },
      ),
    );
  }

  void _openEditForm(Domba domba) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DombaFormModal(domba: domba),
    );
    if (result == true) {
      _dataChanged = true;
      _loadDomba();
    }
  }

  Future<void> _confirmRemoveFromKandang(Domba d) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus ${d.earTag}?',
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 17,
            color: navyDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Pilih alasan:', style: TextStyle(fontSize: 12.5, color: textMuted)),
            ),
            const SizedBox(height: 10),
            _simpleOption(ctx, Icons.logout_rounded, 'Keluarkan dari Kandang', const Color(0xFFFF9800), 'dikeluarkan'),
            const SizedBox(height: 6),
            _simpleOption(ctx, Icons.sell_outlined, 'Domba Terjual', const Color(0xFF2196F3), 'terjual'),
            const SizedBox(height: 6),
            _simpleOption(ctx, Icons.heart_broken_outlined, 'Domba Mati', redAccent, 'mati'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: textMuted)),
          ),
        ],
      ),
    );

    if (reason != null) {
      try {
        await widget.kandangRepo.removeDombaFromKandang(
          idKandang: widget.kandang.idKandang,
          dombaIds: [d.idDomba],
          reason: reason,
        );
        if (mounted) {
          _dataChanged = true;
          final messages = {
            'dikeluarkan': 'Domba "${d.earTag}" berhasil dikeluarkan dari kandang.',
            'terjual': 'Domba "${d.earTag}" ditandai sebagai terjual.',
            'mati': 'Domba "${d.earTag}" ditandai sebagai mati.',
          };
          AppPopup.show(
            context,
            message: messages[reason] ?? 'Domba berhasil diproses.',
          );
          _loadDomba();
        }
      } catch (e) {
        if (mounted) {
          AppPopup.show(context, message: e.toString(), isError: true);
        }
      }
    }
  }

  Widget _simpleOption(BuildContext ctx, IconData icon, String label, Color color, String value) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(ctx, value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: color,
                )),
              ),
              Icon(Icons.chevron_right, size: 18, color: color.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sisaKapasitas = widget.kandang.kapasitas - widget.kandang.jumlahDomba;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _dataChanged) {
          // Signal parent to reload
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
        decoration: const BoxDecoration(
          color: beigeLight,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD5CFBF),
                borderRadius: BorderRadius.circular(999),
              ),
            ),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Domba di ${widget.kandang.namaKandang}',
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: navyDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_dombaList.length} domba Â· Sisa kapasitas: $sisaKapasitas',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, _dataChanged),
                  icon: const Icon(Icons.close, color: navyDark),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 40, color: Colors.red),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _loadDomba,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      : _dombaList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.pets_outlined,
                                    size: 48,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Belum ada domba di kandang ini.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: textMuted),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tambahkan domba menggunakan tombol di bawah.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _dombaList.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Color(0xFFE8E3DA),
                              ),
                              itemBuilder: (context, index) {
                                final d = _dombaList[index];
                                return _buildDombaItem(d);
                              },
                            ),
            ),
            const SizedBox(height: 14),

            // Add more button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: sisaKapasitas > 0 ? widget.onAddMore : null,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  sisaKapasitas > 0
                      ? 'Tambah Domba ke Kandang'
                      : 'Kandang Sudah Penuh',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCCC7BB),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDombaItem(Domba d) {
    return InkWell(
      onTap: () => _showDetailModal(d),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            // Gender icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _genderBg(d.jenisKelamin),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                d.jenisKelamin == 'jantan' ? Icons.male : Icons.female,
                size: 22,
                color: _genderColor(d.jenisKelamin),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.earTag,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: navyDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${d.idBangsa ?? '-'} Â· ${d.jenisKelaminLabel} Â· ${d.umur}',
                    style: const TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            ),

            // Gender badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _genderBg(d.jenisKelamin),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                d.jenisKelaminLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _genderColor(d.jenisKelamin),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Chevron
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ Detail Domba Modal (dipakai dari Kandang) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DetailDombaModal extends StatefulWidget {
  final Domba domba;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Color Function(String) genderColor;
  final Color Function(String) genderBg;

  const _DetailDombaModal({
    required this.domba,
    required this.onEdit,
    required this.onDelete,
    required this.genderColor,
    required this.genderBg,
  });

  @override
  State<_DetailDombaModal> createState() => _DetailDombaModalState2();
}

class _DetailDombaModalState2 extends State<_DetailDombaModal> {
  static const Color navyDark = Color(0xFF1A2B45);
  static const Color textMuted = Color(0xFF8A9BB0);
  static const Color redAccent = Color(0xFFD94F4F);

  List<RekamMedis> _rekamMedis = [];
  bool _isLoadingMedis = true;
  bool _showAllMedis = false;
  List<Perkawinan> _perkawinan = [];
  bool _isLoadingKawin = true;

  @override
  void initState() {
    super.initState();
    _loadRekamMedis();
  }

  Future<void> _loadRekamMedis() async {
    try {
      final data = await ApiService.fetchRekamMedisByEarTag(widget.domba.earTag);
      if (mounted) {
        setState(() {
          _rekamMedis = data.map((e) => RekamMedis.fromJson(e)).toList();
          _isLoadingMedis = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMedis = false);
    }
    _loadPerkawinan();
  }

  Future<void> _loadPerkawinan() async {
    try {
      final data = await ApiService.fetchPerkawinanByEarTag(widget.domba.earTag);
      if (mounted) {
        setState(() {
          _perkawinan = data.map((e) => Perkawinan.fromJson(e)).toList();
          _isLoadingKawin = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingKawin = false);
    }
  }

  Color _statusColor(String? s) {
    switch (s?.toLowerCase()) {
      case 'sehat': return const Color(0xFF4CAF50);
      case 'bunting': case 'hamil': return const Color(0xFFFF9800);
      case 'sakit': case 'dalam perawatan': case 'perawatan': case 'karantina': return const Color(0xFFE53935);
      default: return textMuted;
    }
  }

  Color _statusBg(String? s) {
    switch (s?.toLowerCase()) {
      case 'sehat': return const Color(0x1A4CAF50);
      case 'bunting': case 'hamil': return const Color(0x1AFF9800);
      case 'sakit': case 'dalam perawatan': case 'perawatan': case 'karantina': return const Color(0x1AE53935);
      default: return const Color(0xFFF5F0E8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final domba = widget.domba;
    final genderClr = widget.genderColor(domba.jenisKelamin);
    final genderBg  = widget.genderBg(domba.jenisKelamin);
    final screenH   = MediaQuery.of(context).size.height;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F2),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Fixed header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                child: Row(
                  children: [
                    const Text(
                      'Detail Domba',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: navyDark,
                      ),
                    ),
                    const Spacer(),
                    // Gender badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: genderBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        domba.jenisKelaminLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: genderClr,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAE4D8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close, size: 16, color: navyDark),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFEFEBE3)),

              // ── Scrollable content ──
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(
                    16, 16, 16,
                    MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  children: [
                    // Identity card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EFE4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: genderBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              domba.jenisKelamin == 'jantan'
                                  ? Icons.male
                                  : Icons.female,
                              size: 28,
                              color: genderClr,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  domba.earTag,
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: navyDark,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${domba.idBangsa ?? '-'} · ${domba.jenisKelaminLabel} · ${domba.umur}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Info grid — 3 rows × 2 columns, fully responsive
                    Row(
                      children: [
                        Expanded(child: _infoBox('Umur', domba.umur)),
                        const SizedBox(width: 10),
                        Expanded(child: _infoBox('Berat',
                            domba.berat != null ? '${domba.berat} kg' : '-')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _infoBox('Status', domba.status ?? '-')),
                        const SizedBox(width: 10),
                        Expanded(child: _infoBox('Vaksinasi', domba.vaksinasi ?? '-')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _infoBox('Induk', domba.namaInduk)),
                        const SizedBox(width: 10),
                        Expanded(child: _infoBox('Pejantan', domba.namaPejantan)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Monitoring Berat Badan
                    _buildWeightMonitoringButton(),
                    const SizedBox(height: 20),

                    // Rekam Medis
                    _buildRekamMedisSection(),
                    const SizedBox(height: 20),

                    // Perkawinan
                    _buildPerkawinanSection(),
                    const SizedBox(height: 20),

                    // Action buttons — di dalam list agar selalu tampil saat discroll
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text(
                              'Edit',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: navyDark,
                              side: const BorderSide(
                                  color: Color(0xFFBFB8A8), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onDelete,
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text(
                              'Hapus',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: redAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenH * 0.02),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Weight Monitoring Button ──
  Widget _buildWeightMonitoringButton() {
    final domba = widget.domba;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _openWeightMonitoring(domba),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2B45), Color(0xFF2C4A7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Color(0x25000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.monitor_weight_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monitoring Berat Badan',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      domba.berat != null
                          ? 'Berat saat ini: ${domba.berat!.toStringAsFixed(1)} kg  ·  Lihat grafik pertumbuhan'
                          : 'Lihat grafik & analitik pertumbuhan',
                      style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(170)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withAlpha(170), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  void _openWeightMonitoring(Domba domba) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeightMonitoringScreen(
          idDomba: domba.idDomba,
          earTag: domba.earTag,
        ),
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E3DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: navyDark,
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Rekam Medis Section â”€â”€
  Widget _buildRekamMedisSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medical_services_outlined, size: 16, color: Color(0xFF1976D2)),
              ),
              const SizedBox(width: 10),
              const Text('Rekam Medis', style: TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: navyDark)),
              const Spacer(),
              if (_rekamMedis.length > 1)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAllMedis = !_showAllMedis;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
                    child: Text(_showAllMedis ? 'Sembunyikan' : 'Lihat selengkapnya', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1976D2))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingMedis)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
          else if (_rekamMedis.isEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E3DA))),
              child: Column(children: [
                Icon(Icons.note_add_outlined, size: 32, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                const Text('Belum ada catatan rekam medis', style: TextStyle(fontSize: 13, color: textMuted)),
                const SizedBox(height: 4),
                const Text('Scan catatan medis untuk menambahkan data', style: TextStyle(fontSize: 11, color: textMuted)),
              ]),
            )
          else ...[
            _buildLatestMedisCard(_rekamMedis.first),
            if (_rekamMedis.length > 1 && _showAllMedis) ...[
              const SizedBox(height: 12),
              const Text('RIWAYAT SEBELUMNYA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: textMuted)),
              const SizedBox(height: 8),
              ...List.generate(
                _rekamMedis.length - 1,
                (i) => _buildMedisHistoryItem(_rekamMedis[i + 1]),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLatestMedisCard(RekamMedis rm) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E3DA)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.fiber_new_rounded, size: 14, color: Color(0xFF4CAF50)), SizedBox(width: 4), Text('Terbaru', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50)))])),
          const Spacer(),
          Text(rm.tanggalDisplay, style: const TextStyle(fontSize: 12, color: textMuted)),
        ]),
        const SizedBox(height: 12),
        if (rm.statusKesehatan != null) ...[
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _statusBg(rm.statusKesehatan), borderRadius: BorderRadius.circular(8)),
            child: Text(rm.statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(rm.statusKesehatan)))),
          const SizedBox(height: 12),
        ],
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (rm.berat != null) _medisChip(Icons.monitor_weight_outlined, '${rm.berat} kg'),
          if (rm.suhuTubuh != null) _medisChip(Icons.thermostat_outlined, '${rm.suhuTubuh}Â°C'),
          if (rm.vaksinasi != null) _medisChip(Icons.vaccines_outlined, rm.vaksinasi!),
          if (rm.obat != null) _medisChip(Icons.medication_outlined, rm.obat!),
        ]),
        if (rm.catatan != null && rm.catatan!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF9F6F1), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.notes_outlined, size: 14, color: textMuted), const SizedBox(width: 8),
              Expanded(child: Text(rm.catatan!, style: const TextStyle(fontSize: 12, color: navyDark, height: 1.4))),
            ])),
        ],
      ]),
    );
  }

  Widget _buildMedisHistoryItem(RekamMedis rm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEAE4D8))),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _statusColor(rm.statusKesehatan), shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(rm.tanggalDisplay, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: navyDark)),
        const SizedBox(width: 10),
        if (rm.statusKesehatan != null)
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _statusBg(rm.statusKesehatan), borderRadius: BorderRadius.circular(4)),
            child: Text(rm.statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(rm.statusKesehatan)))),
        const Spacer(),
        if (rm.berat != null) Text('${rm.berat} kg', style: const TextStyle(fontSize: 12, color: textMuted)),
      ]),
    );
  }

  Widget _medisChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF5F0E8), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: navyDark), const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: navyDark)),
      ]),
    );
  }

  // â”€â”€ Perkawinan Section â”€â”€
  Color _kawinColor(String? s) {
    switch (s?.toLowerCase()) {
      case 'kawin': return const Color(0xFF2196F3);
      case 'bunting': return const Color(0xFFFF9800);
      case 'lahir': return const Color(0xFF4CAF50);
      case 'gagal': return const Color(0xFFFF6B6B);
      default: return textMuted;
    }
  }
  Color _kawinBg(String? s) {
    switch (s?.toLowerCase()) {
      case 'kawin': return const Color(0xFFE3F2FD);
      case 'bunting': return const Color(0xFFFFF3E0);
      case 'lahir': return const Color(0xFFE8F5E9);
      case 'gagal': return const Color(0xFFFFEBEE);
      default: return const Color(0xFFF5F0E8);
    }
  }

  Widget _buildPerkawinanSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.favorite_outline, size: 16, color: Color(0xFFE91E63))),
          const SizedBox(width: 10),
          const Text('Data Perkawinan', style: TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: navyDark)),
          const Spacer(),
          if (_perkawinan.isNotEmpty)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(10)),
              child: Text('${_perkawinan.length} catatan', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE91E63)))),
        ]),
        const SizedBox(height: 12),
        if (_isLoadingKawin)
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
        else if (_perkawinan.isEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E3DA))),
            child: Column(children: [
              Icon(Icons.favorite_border, size: 32, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              const Text('Belum ada data perkawinan', style: TextStyle(fontSize: 13, color: textMuted)),
            ]))
        else ...[
          _buildLatestKawinCard(_perkawinan.first),
          if (_perkawinan.length > 1) ...[
            const SizedBox(height: 12),
            const Text('RIWAYAT SEBELUMNYA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: textMuted)),
            const SizedBox(height: 8),
            ...List.generate(_perkawinan.length - 1 > 4 ? 4 : _perkawinan.length - 1, (i) => _buildKawinItem(_perkawinan[i + 1])),
          ],
        ],
      ]),
    );
  }

  Widget _buildLatestKawinCard(Perkawinan p) {
    final domba = widget.domba;
    final isBetina = domba.earTag == p.earTagBetina;
    final pasanganTag = isBetina ? p.earTagJantan : p.earTagBetina;
    final roleLabel = isBetina ? 'Betina' : 'Pejantan';
    final pasanganRole = isBetina ? 'Pejantan' : 'Betina';
    return Container(width: double.infinity, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E3DA)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _kawinBg(p.statusPerkawinan), borderRadius: BorderRadius.circular(6)),
            child: Text(p.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kawinColor(p.statusPerkawinan)))),
          const Spacer(),
          Text(p.tanggalKawinDisplay, style: const TextStyle(fontSize: 12, color: textMuted)),
        ]),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF9F6F1), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(child: Column(children: [
              Icon(isBetina ? Icons.female : Icons.male, size: 20, color: isBetina ? const Color(0xFFE91E63) : const Color(0xFF2196F3)),
              const SizedBox(height: 4),
              Text(domba.earTag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: navyDark)),
              Text(roleLabel, style: const TextStyle(fontSize: 10, color: textMuted)),
            ])),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.favorite, size: 16, color: Color(0xFFE91E63))),
            Expanded(child: Column(children: [
              Icon(!isBetina ? Icons.female : Icons.male, size: 20, color: !isBetina ? const Color(0xFFE91E63) : const Color(0xFF2196F3)),
              const SizedBox(height: 4),
              Text(pasanganTag, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: navyDark)),
              Text(pasanganRole, style: const TextStyle(fontSize: 10, color: textMuted)),
            ])),
          ])),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _medisChip(Icons.science_outlined, p.metodeLabel),
          if (p.tanggalPerkiraanLahir != null) _medisChip(Icons.event_outlined, 'Lahir: ${p.tanggalLahirDisplay}'),
          if (p.jumlahAnak != null) _medisChip(Icons.child_care_outlined, '${p.jumlahAnak} anak'),
        ]),
        if (p.catatan != null && p.catatan!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF9F6F1), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.notes_outlined, size: 14, color: textMuted), const SizedBox(width: 8),
              Expanded(child: Text(p.catatan!, style: const TextStyle(fontSize: 12, color: navyDark, height: 1.4))),
            ])),
        ],
      ]),
    );
  }

  Widget _buildKawinItem(Perkawinan p) {
    final domba = widget.domba;
    final isBetina = domba.earTag == p.earTagBetina;
    final pasanganTag = isBetina ? p.earTagJantan : p.earTagBetina;
    return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEAE4D8))),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _kawinColor(p.statusPerkawinan), shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(p.tanggalKawinDisplay, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: navyDark)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _kawinBg(p.statusPerkawinan), borderRadius: BorderRadius.circular(4)),
          child: Text(p.statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kawinColor(p.statusPerkawinan)))),
        const Spacer(),
        const Icon(Icons.favorite, size: 10, color: Color(0xFFE91E63)), const SizedBox(width: 4),
        Text(pasanganTag, style: const TextStyle(fontSize: 11, color: textMuted)),
      ]),
    );
  }
}

// â”€â”€â”€ Domba Form Modal (Edit domba dari Kandang) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DombaFormModal extends StatefulWidget {
  final Domba? domba;

  const _DombaFormModal({this.domba});

  @override
  State<_DombaFormModal> createState() => _DombaFormModalState();
}

class _DombaFormModalState extends State<_DombaFormModal> {
  static const Color navyDark = Color(0xFF1A2B45);
  static const Color beigeLight = Color(0xFFFAF7F2);
  static const Color textMuted = Color(0xFF8A9BB0);

  final _formKey = GlobalKey<FormState>();
  final DombaRepository _repo = DombaRepository();

  late final TextEditingController _earTagCtrl;
  late final TextEditingController _beratCtrl;
  String? _jenisKelamin;
  String? _status;
  String? _vaksinasi;
  String? _idBangsa;
  bool _isSaving = false;

  // Dropdown data
  List<Domba> _betinas = [];
  List<Domba> _jantans = [];
  String? _idInduk;
  String? _idPejantan;
  String? _tanggalLahir;

  @override
  void initState() {
    super.initState();
    _earTagCtrl = TextEditingController(text: widget.domba?.earTag ?? '');
    _beratCtrl = TextEditingController(
      text: widget.domba?.berat?.toString() ?? '',
    );
    _jenisKelamin = widget.domba?.jenisKelamin;
    _status = widget.domba?.status;
    _vaksinasi = widget.domba?.vaksinasi;
    _idBangsa = widget.domba?.idBangsa;
    _idInduk = widget.domba?.idInduk;
    _idPejantan = widget.domba?.idPejantan;
    _tanggalLahir = widget.domba?.tanggalLahir;
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    try {
      final results = await Future.wait([
        _repo.fetchBetina(),
        _repo.fetchJantan(),
      ]);
      if (mounted) {
        setState(() {
          _betinas = results[0];
          _jantans = results[1];
        });
      }
    } catch (_) {}
  }

  Future<void> _pickTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalLahir != null
          ? DateTime.tryParse(_tanggalLahir!) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _tanggalLahir =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_jenisKelamin == null) {
      AppPopup.show(context, message: 'Pilih jenis kelamin.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      'ear_tag': _earTagCtrl.text.trim(),
      'jenis_kelamin': _jenisKelamin,
      'id_bangsa': _idBangsa,
      'berat': double.tryParse(_beratCtrl.text.trim()),
      'status': _status,
      'vaksinasi': _vaksinasi,
      'id_induk': _idInduk,
      'id_pejantan': _idPejantan,
      'tanggal_lahir': _tanggalLahir,
    };

    try {
      if (widget.domba != null) {
        await _repo.updateDomba(widget.domba!.idDomba, payload);
      } else {
        await _repo.createDomba(payload);
      }
      if (mounted) {
        Navigator.pop(context, true);
        AppPopup.show(
          context,
          message: widget.domba != null
              ? 'Domba berhasil diperbarui.'
              : 'Domba berhasil ditambahkan.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context, message: e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _earTagCtrl.dispose();
    _beratCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.domba != null;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: beigeLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD5CFBF),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  isEdit ? 'Edit Domba' : 'Tambah Domba',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: navyDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: navyDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20, 0, 20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _styledField(
                      label: 'Ear Tag',
                      icon: Icons.label_outline,
                      controller: _earTagCtrl,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),
                    _styledDropdown<String>(
                      label: 'Jenis Kelamin',
                      icon: Icons.wc,
                      value: _jenisKelamin,
                      items: const [
                        DropdownMenuItem(value: 'jantan', child: Text('Jantan')),
                        DropdownMenuItem(value: 'betina', child: Text('Betina')),
                      ],
                      onChanged: (v) => setState(() => _jenisKelamin = v),
                    ),
                    const SizedBox(height: 14),
                    _styledDropdown<String>(
                      label: 'Bangsa',
                      icon: Icons.category_outlined,
                      value: _idBangsa,
                      items: ['ETAWA', 'MERINO', 'DORPER', 'LOKAL', 'GARUT']
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) => setState(() => _idBangsa = v),
                    ),
                    const SizedBox(height: 14),
                    _styledField(
                      label: 'Berat (kg)',
                      icon: Icons.monitor_weight_outlined,
                      controller: _beratCtrl,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    _styledDropdown<String>(
                      label: 'Status',
                      icon: Icons.health_and_safety_outlined,
                      value: _status,
                      items: ['sehat', 'sakit', 'karantina', 'bunting']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _status = v),
                    ),
                    const SizedBox(height: 14),
                    _styledDropdown<String>(
                      label: 'Vaksinasi',
                      icon: Icons.vaccines_outlined,
                      value: _vaksinasi,
                      items: ['sudah', 'belum']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _vaksinasi = v),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _pickTanggal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDD8CE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 18, color: textMuted),
                            const SizedBox(width: 12),
                            Text(
                              _tanggalLahir ?? 'Tanggal Lahir',
                              style: TextStyle(
                                fontSize: 14,
                                color: _tanggalLahir != null
                                    ? navyDark
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _styledDropdown<String>(
                      label: 'Induk',
                      icon: Icons.female,
                      value: _idInduk,
                      items: _betinas
                          .map((b) => DropdownMenuItem(
                                value: b.idDomba,
                                child: Text(b.earTag),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _idInduk = v),
                    ),
                    const SizedBox(height: 14),
                    _styledDropdown<String>(
                      label: 'Pejantan',
                      icon: Icons.male,
                      value: _idPejantan,
                      items: _jantans
                          .map((j) => DropdownMenuItem(
                                value: j.idDomba,
                                child: Text(j.earTag),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _idPejantan = v),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEdit ? 'Simpan Perubahan' : 'Tambah Domba',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _styledField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: navyDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: textMuted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDD8CE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDD8CE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navyDark, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 14,
        ),
      ),
    );
  }

  Widget _styledDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: items.any((item) => item.value == value) ? value : null,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: navyDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textMuted, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: textMuted),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDD8CE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDD8CE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navyDark, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 14,
        ),
      ),
    );
  }
}

// â”€â”€â”€ Form Sheet Widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _KandangFormSheet extends StatefulWidget {
  final Kandang? kandang;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _KandangFormSheet({this.kandang, required this.onSave});

  @override
  State<_KandangFormSheet> createState() => _KandangFormSheetState();
}

class _KandangFormSheetState extends State<_KandangFormSheet> {
  static const Color navyDark = Color(0xFF1A2B45);

  final _namaCtrl = TextEditingController();
  final _tipeCtrl = TextEditingController();
  final _kapasitasCtrl = TextEditingController();
  bool _isSaving = false;

  bool get isEdit => widget.kandang != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _namaCtrl.text = widget.kandang!.namaKandang;
      _tipeCtrl.text = widget.kandang!.tipeKandang ?? '';
      _kapasitasCtrl.text = widget.kandang!.kapasitas.toString();
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _tipeCtrl.dispose();
    _kapasitasCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_namaCtrl.text.trim().isEmpty) {
      AppPopup.show(
        context,
        message: 'Nama kandang wajib diisi.',
        isError: true,
      );
      return;
    }
    if (_kapasitasCtrl.text.trim().isEmpty) {
      AppPopup.show(context, message: 'Kapasitas wajib diisi.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      'nama_kandang': _namaCtrl.text.trim(),
      'tipe_kandang': _tipeCtrl.text.trim().isEmpty
          ? null
          : _tipeCtrl.text.trim(),
      'kapasitas': int.tryParse(_kapasitasCtrl.text.trim()) ?? 0,
    };

    await widget.onSave(payload);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit
                  ? 'Edit ${widget.kandang!.namaKandang}'
                  : 'Tambah Kandang Baru',
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: navyDark,
              ),
            ),
            const SizedBox(height: 16),
            _field('Nama Kandang *', _namaCtrl),
            _field('Tipe / Blok', _tipeCtrl),
            _field('Kapasitas *', _kapasitasCtrl, type: TextInputType.number),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navyDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Simpan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType? type,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7A8D),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDD8CE)),
            ),
            child: TextField(
              controller: ctrl,
              keyboardType: type,
              style: const TextStyle(fontSize: 14, color: navyDark),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Semua Domba Sheet (Total Domba) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SemuaDombaSheet extends StatefulWidget {
  final KandangRepository kandangRepo;

  const _SemuaDombaSheet({required this.kandangRepo});

  @override
  State<_SemuaDombaSheet> createState() => _SemuaDombaSheetState();
}

class _SemuaDombaSheetState extends State<_SemuaDombaSheet> {
  static const Color navyDark = Color(0xFF1A2B45);
  static const Color beigeLight = Color(0xFFFAF7F2);
  static const Color textMuted = Color(0xFF8A9BB0);

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _allDomba = [];
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await widget.kandangRepo.fetchSemuaDomba();
      if (mounted) setState(() => _allDomba = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) { case 'terjual': return const Color(0xFF2196F3); case 'mati': return const Color(0xFFD94F4F); default: return const Color(0xFF4CAF50); }
  }
  Color _statusBg(String s) {
    switch (s) { case 'terjual': return const Color(0xFFE3F2FD); case 'mati': return const Color(0xFFFDE8E8); default: return const Color(0xFFE8F5E9); }
  }
  String _statusLabel(String s) {
    switch (s) { case 'terjual': return 'Terjual'; case 'mati': return 'Mati'; default: return 'Tersedia'; }
  }
  IconData _statusIcon(String s) {
    switch (s) { case 'terjual': return Icons.sell_outlined; case 'mati': return Icons.heart_broken_outlined; default: return Icons.check_circle_outline; }
  }
  Color _genderColor(String jk) => jk == 'jantan' ? const Color(0xFF2196F3) : const Color(0xFFE91E63);

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '-';
    try {
      final dt = DateTime.parse(d);
      const m = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) { return d; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: beigeLight,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 44, height: 5, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: const Color(0xFFD5CFBF), borderRadius: BorderRadius.circular(999))),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Semua Domba', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: navyDark)),
            const SizedBox(height: 4),
            Text('${_allDomba.length} domba terdaftar', style: const TextStyle(fontSize: 12.5, color: textMuted)),
          ])),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: navyDark)),
        ]),
        if (!_isLoading && _error == null && _allDomba.isNotEmpty) ...[
          const SizedBox(height: 12), _buildStatusSummary(),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, size: 40, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('Coba Lagi')),
                    ]))
                  : _allDomba.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.pets_outlined, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('Belum ada data domba.', style: TextStyle(color: textMuted)),
                        ]))
                      : ListView.separated(
                          itemCount: _allDomba.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _buildDombaCard(_allDomba[i], i),
                        ),
        ),
      ]),
    );
  }

  Widget _buildStatusSummary() {
    final tersedia = _allDomba.where((d) => (d['status_ketersediaan'] ?? 'tersedia') == 'tersedia').length;
    final terjual = _allDomba.where((d) => d['status_ketersediaan'] == 'terjual').length;
    final mati = _allDomba.where((d) => d['status_ketersediaan'] == 'mati').length;
    return Row(children: [
      _chipSummary('Tersedia', tersedia, const Color(0xFF4CAF50)),
      const SizedBox(width: 8),
      _chipSummary('Terjual', terjual, const Color(0xFF2196F3)),
      const SizedBox(width: 8),
      _chipSummary('Mati', mati, const Color(0xFFD94F4F)),
    ]);
  }

  Widget _chipSummary(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E3DA)),
          boxShadow: [
            BoxShadow(
              color: navyDark.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: navyDark,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDombaCard(Map<String, dynamic> d, int index) {
    final status = (d['status_ketersediaan'] ?? 'tersedia').toString();
    final jk = (d['jenis_kelamin'] ?? '').toString();
    final jkLabel = jk == 'jantan' ? 'Jantan' : jk == 'betina' ? 'Betina' : jk;
    final isExpanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded ? _statusColor(status).withOpacity(0.5) : const Color(0xFFF0EBE1),
            width: isExpanded ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x08000000),
              blurRadius: isExpanded ? 12 : 6,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Sleek Minimal Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE8E3DA)),
                    ),
                    child: Icon(
                      jk == 'jantan' ? Icons.male : Icons.female,
                      size: 20,
                      color: _genderColor(jk),
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['ear_tag']?.toString() ?? '-',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: navyDark,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d['id_bangsa'] ?? '-'} · $jkLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            color: textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Modern Status Indicator & Dropdown
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusBg(status),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _statusColor(status),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetail(d, status),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(Map<String, dynamic> d, String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFF0EBE1)),
          const SizedBox(height: 12),
          _detailContent(d, status),
        ],
      ),
    );
  }

  Widget _detailContent(Map<String, dynamic> d, String status) {
    if (status == 'terjual') {
      return _buildExpandedInfoRow(
        icon: Icons.sell_outlined,
        color: _statusColor(status),
        title: 'Tanggal Terjual',
        value: _fmtDate(d['updated_at']?.toString()),
      );
    }
    if (status == 'mati') {
      return _buildExpandedInfoRow(
        icon: Icons.heart_broken_outlined,
        color: _statusColor(status),
        title: 'Tanggal Kematian',
        value: _fmtDate(d['updated_at']?.toString()),
      );
    }
    
    // tersedia
    final rm = d['rekam_medis_terakhir'] as Map<String, dynamic>?;
    if (rm == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.description_outlined, size: 16, color: textMuted),
          SizedBox(width: 8),
          Text(
            'Belum ada rekam medis.',
            style: TextStyle(fontSize: 12, color: textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medical_services_outlined, size: 16, color: _statusColor(status)),
            const SizedBox(width: 8),
            Text(
              'Rekam Medis Terakhir',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(status), letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _dRow('Tanggal', _fmtDate(rm['tanggal']?.toString())),
        _dRow('Status', rm['status_kesehatan']?.toString() ?? '-'),
        if (rm['catatan'] != null && rm['catatan'].toString().isNotEmpty)
          _dRow('Catatan', rm['catatan'].toString()),
      ],
    );
  }

  Widget _buildExpandedInfoRow({required IconData icon, required Color color, required String title, required String value}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: navyDark)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: textMuted)),
          ),
          const Text(' : ', style: TextStyle(fontSize: 11.5, color: textMuted)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: navyDark),
            ),
          ),
        ],
      ),
    );
  }
}
