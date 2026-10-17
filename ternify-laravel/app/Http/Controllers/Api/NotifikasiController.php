<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Domba;
use App\Models\RekamMedis;
use App\Models\Perkawinan;
use Illuminate\Http\Request;
use Carbon\Carbon;

class NotifikasiController extends Controller
{
    /**
     * GET /api/notifikasi
     * Menghasilkan daftar notifikasi berdasarkan data peternakan user.
     */
    public function index(Request $request)
    {
        $userId = $request->user()->id;
        $now    = Carbon::today();

        $notifikasi = collect();

        // ─────────────────────────────────────────────────────────────────
        // 1. VAKSINASI DOMBA
        //    Logika: vaksinasi = null / belum divaksin → berikan reminder.
        //    Jika vaksinasi sudah diisi, cek apakah > 6 bulan lalu (booster).
        // ─────────────────────────────────────────────────────────────────
        $dombaList = Domba::where('user_id', $userId)
            ->where('status_ketersediaan', 'tersedia')
            ->get();

        foreach ($dombaList as $domba) {
            $earTag = $domba->ear_tag;

            // Belum pernah divaksin
            if (empty($domba->vaksinasi)) {
                $notifikasi->push([
                    'id'       => 'vaks_null_' . $domba->id_domba,
                    'tipe'     => 'vaksinasi',
                    'prioritas'=> 'tinggi',
                    'judul'    => 'Vaksinasi Belum Dilakukan',
                    'pesan'    => 'Domba ' . $earTag . ' belum pernah divaksinasi. Segera jadwalkan vaksinasi.',
                    'ear_tag'  => $earTag,
                    'ikon'     => 'vaccine',
                    'waktu'    => now()->toIso8601String(),
                    'dibaca'   => false,
                ]);
            }
        }

        // ─────────────────────────────────────────────────────────────────
        // 2. JADWAL PEMERIKSAAN (Rekam Medis)
        //    Logika: jika pemeriksaan terakhir > 30 hari lalu → reminder.
        //    Domba sakit yang belum ada rekam medis baru → prioritas tinggi.
        // ─────────────────────────────────────────────────────────────────
        foreach ($dombaList as $domba) {
            $earTag = $domba->ear_tag;

            $rekamTerakhir = RekamMedis::where('id_domba', $domba->id_domba)
                ->orderBy('tanggal_pemeriksaan', 'desc')
                ->first();

            if ($rekamTerakhir) {
                $tglPemeriksaan = Carbon::parse($rekamTerakhir->tanggal_pemeriksaan);
                $selisihHari    = $now->diffInDays($tglPemeriksaan, false); // negatif = sudah lewat
                $hariLewat      = abs($selisihHari);

                // Status sakit → pemeriksaan wajib rutin (reminder setiap 7 hari)
                if (
                    in_array(strtolower($rekamTerakhir->status_kesehatan), ['sakit', 'dalam perawatan', 'perawatan', 'karantina'])
                    && $hariLewat >= 7
                ) {
                    $notifikasi->push([
                        'id'       => 'periksa_sakit_' . $domba->id_domba,
                        'tipe'     => 'pemeriksaan',
                        'prioritas'=> 'tinggi',
                        'judul'    => 'Pemeriksaan Domba Sakit',
                        'pesan'    => 'Domba ' . $earTag . ' berstatus sakit dan belum diperiksa ' . $hariLewat . ' hari. Segera lakukan pemeriksaan ulang.',
                        'ear_tag'  => $earTag,
                        'ikon'     => 'medical',
                        'waktu'    => now()->toIso8601String(),
                        'dibaca'   => false,
                    ]);
                }
                // Pemeriksaan rutin (> 30 hari)
                elseif ($hariLewat >= 30 && $hariLewat < 37) {
                    $notifikasi->push([
                        'id'       => 'periksa_rutin_' . $domba->id_domba,
                        'tipe'     => 'pemeriksaan',
                        'prioritas'=> 'sedang',
                        'judul'    => 'Jadwal Pemeriksaan Rutin',
                        'pesan'    => 'Jadwal pemeriksaan domba ' . $earTag . ' sudah ' . $hariLewat . ' hari yang lalu. Segera lakukan pemeriksaan rutin.',
                        'ear_tag'  => $earTag,
                        'ikon'     => 'medical',
                        'waktu'    => now()->toIso8601String(),
                        'dibaca'   => false,
                    ]);
                }
            } else {
                // Belum pernah diperiksa sama sekali
                $notifikasi->push([
                    'id'       => 'periksa_baru_' . $domba->id_domba,
                    'tipe'     => 'pemeriksaan',
                    'prioritas'=> 'sedang',
                    'judul'    => 'Belum Ada Rekam Medis',
                    'pesan'    => 'Domba ' . $earTag . ' belum memiliki rekam medis. Lakukan pemeriksaan awal segera.',
                    'ear_tag'  => $earTag,
                    'ikon'     => 'medical',
                    'waktu'    => now()->toIso8601String(),
                    'dibaca'   => false,
                ]);
            }
        }

        // ─────────────────────────────────────────────────────────────────
        // 3. PERKIRAAN KELAHIRAN (Perkawinan bunting)
        //    Logika: perkawinan status 'bunting' dengan tanggal_perkiraan_lahir
        //    dalam 14 hari ke depan → beri notif
        // ─────────────────────────────────────────────────────────────────
        $perkawinanBunting = Perkawinan::where('user_id', $userId)
            ->where('status_perkawinan', 'bunting')
            ->whereNotNull('tanggal_perkiraan_lahir')
            ->get();

        foreach ($perkawinanBunting as $kawin) {
            $tglLahir     = Carbon::parse($kawin->tanggal_perkiraan_lahir);
            $sisaHari     = $now->diffInDays($tglLahir, false); // positif = belum, negatif = sudah lewat
            $earTagBetina = $kawin->ear_tag_betina;

            if ($sisaHari < 0) {
                // Lewat tanggal perkiraan lahir tapi belum update status
                $lewat = abs((int)$sisaHari);
                $notifikasi->push([
                    'id'       => 'lahir_lewat_' . $kawin->id,
                    'tipe'     => 'kelahiran',
                    'prioritas'=> 'tinggi',
                    'judul'    => 'Tanggal Kelahiran Terlewat!',
                    'pesan'    => 'Perkiraan lahir induk ' . $earTagBetina . ' sudah terlewat ' . $lewat . ' hari. Segera periksa dan perbarui status.',
                    'ear_tag'  => $earTagBetina,
                    'ikon'     => 'baby',
                    'waktu'    => now()->toIso8601String(),
                    'dibaca'   => false,
                ]);
            } elseif ($sisaHari <= 3) {
                $notifikasi->push([
                    'id'       => 'lahir_segera_' . $kawin->id,
                    'tipe'     => 'kelahiran',
                    'prioritas'=> 'tinggi',
                    'judul'    => 'Kelahiran Sangat Dekat!',
                    'pesan'    => 'Induk ' . $earTagBetina . ' diperkirakan akan melahirkan dalam ' . (int)$sisaHari . ' hari lagi. Siapkan kandang khusus.',
                    'ear_tag'  => $earTagBetina,
                    'ikon'     => 'baby',
                    'waktu'    => now()->toIso8601String(),
                    'dibaca'   => false,
                ]);
            } elseif ($sisaHari <= 7) {
                $notifikasi->push([
                    'id'       => 'lahir_dekat_' . $kawin->id,
                    'tipe'     => 'kelahiran',
                    'prioritas'=> 'sedang',
                    'judul'    => 'Perkiraan Kelahiran Minggu Ini',
                    'pesan'    => 'Perkiraan lahir dari induk ' . $earTagBetina . ' ' . (int)$sisaHari . ' hari lagi. Persiapkan perlengkapan kelahiran.',
                    'ear_tag'  => $earTagBetina,
                    'ikon'     => 'baby',
                    'waktu'    => now()->toIso8601String(),
                    'dibaca'   => false,
                ]);
            } elseif ($sisaHari <= 14) {
                $notifikasi->push([
                    'id'       => 'lahir_14_' . $kawin->id,
                    'tipe'     => 'kelahiran',
                    'prioritas'=> 'rendah',
                    'judul'    => 'Persiapan Kelahiran',
                    'pesan'    => 'Induk ' . $earTagBetina . ' diperkirakan melahirkan ' . (int)$sisaHari . ' hari lagi. Mulai persiapan.',
                    'ear_tag'  => $earTagBetina,
                    'ikon'     => 'baby',
                    'waktu'    => now()->toIso8601String(),
                    'dibaca'   => false,
                ]);
            }
        }

        // ─────────────────────────────────────────────────────────────────
        // 4. BERAT BADAN (Monitoring Berat)
        //    Logika: jika belum ada riwayat berat dalam 30 hari → reminder
        // ─────────────────────────────────────────────────────────────────
        foreach ($dombaList as $domba) {
            $earTag = $domba->ear_tag;

            $beratTerakhir = RekamMedis::where('id_domba', $domba->id_domba)
                ->whereNotNull('berat')
                ->orderBy('tanggal_pemeriksaan', 'desc')
                ->first();

            if (!$beratTerakhir) {
                // Belum pernah ada data berat
                $notifikasi->push([
                    'id'       => 'berat_null_' . $domba->id_domba,
                    'tipe'     => 'berat',
                    'prioritas'=> 'rendah',
                    'judul'    => 'Data Berat Belum Ada',
                    'pesan'    => 'Domba ' . $earTag . ' belum memiliki data berat badan. Lakukan penimbangan awal.',
                    'ear_tag'  => $earTag,
                    'ikon'     => 'scale',
                    'waktu'    => now()->toIso8601String(),
                    'dibaca'   => false,
                ]);
            } else {
                $tglBerat  = Carbon::parse($beratTerakhir->tanggal_pemeriksaan);
                $hariLewat = $now->diffInDays($tglBerat, false);
                if (abs($hariLewat) >= 30 && abs($hariLewat) < 37) {
                    $notifikasi->push([
                        'id'       => 'berat_lama_' . $domba->id_domba,
                        'tipe'     => 'berat',
                        'prioritas'=> 'rendah',
                        'judul'    => 'Penimbangan Berat Badan',
                        'pesan'    => 'Data berat domba ' . $earTag . ' sudah ' . abs((int)$hariLewat) . ' hari yang lalu. Lakukan penimbangan ulang.',
                        'ear_tag'  => $earTag,
                        'ikon'     => 'scale',
                        'waktu'    => now()->toIso8601String(),
                        'dibaca'   => false,
                    ]);
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────
        // 5. DOMBA SAKIT
        //    Notifikasi khusus untuk domba yang berstatus sakit
        // ─────────────────────────────────────────────────────────────────
        $dombaSakit = $dombaList->where('status', 'Sakit');
        foreach ($dombaSakit as $domba) {
            $earTag = $domba->ear_tag;
            // Cek apakah sudah ada notif pemeriksaan_sakit untuk domba ini (hindari duplikat)
            $sudahAda = $notifikasi->contains('id', 'periksa_sakit_' . $domba->id_domba);
            if (!$sudahAda) {
                $notifikasi->push([
                    'id'       => 'sakit_' . $domba->id_domba,
                    'tipe'     => 'kesehatan',
                    'prioritas'=> 'tinggi',
                    'judul'    => 'Domba Membutuhkan Perhatian',
                    'pesan'    => 'Domba ' . $earTag . ' saat ini berstatus sakit. Segera lakukan penanganan medis.',
                    'ear_tag'  => $earTag,
                    'ikon'     => 'alert',
                    'waktu'    => now()->toIso8601String(),
                    'dibaca'   => false,
                ]);
            }
        }

        // Urutkan: tinggi → sedang → rendah
        $prioritasOrder = ['tinggi' => 0, 'sedang' => 1, 'rendah' => 2];
        $sorted = $notifikasi->sortBy(fn($n) => $prioritasOrder[$n['prioritas']] ?? 9)->values();

        return response()->json([
            'success' => true,
            'total'   => $sorted->count(),
            'tinggi'  => $sorted->where('prioritas', 'tinggi')->count(),
            'data'    => $sorted,
        ]);
    }
}
