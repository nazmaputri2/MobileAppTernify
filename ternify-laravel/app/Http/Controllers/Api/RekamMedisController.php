<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\RekamMedis;
use App\Models\Domba;
use Illuminate\Http\Request;

class RekamMedisController extends Controller
{
    /**
     * GET /api/rekam-medis?ear_tag=xxx
     * Ambil daftar rekam medis (filter by ear_tag).
     */
    public function index(Request $request)
    {
        $userId = $request->user()->id;
        $query = RekamMedis::where('user_id', $userId)
            ->orderBy('tanggal_pemeriksaan', 'desc')
            ->orderBy('created_at', 'desc');

        if ($request->has('ear_tag') && $request->ear_tag) {
            $query->where('ear_tag', $request->ear_tag);
        }

        if ($request->has('id_domba') && $request->id_domba) {
            $query->where('id_domba', $request->id_domba);
        }

        $records = $query->get();

        return response()->json([
            'success' => true,
            'data'    => $records,
        ]);
    }

    /**
     * POST /api/rekam-medis
     * Simpan rekam medis baru (dari scan atau manual).
     */
    public function store(Request $request)
    {
        $request->validate([
            'ear_tag'              => 'required|string',
            'tanggal_pemeriksaan'  => 'required|date',
            'berat'                => 'nullable|numeric',
            'suhu_tubuh'           => 'nullable|numeric',
            'status_kesehatan'     => 'nullable|string|max:100',
            'vaksinasi'            => 'nullable|string|max:100',
            'obat'                 => 'nullable|string',
            'catatan'              => 'nullable|string',
        ]);

        $userId = $request->user()->id;

        // Try to find the associated domba by ear_tag
        $domba = Domba::where('user_id', $userId)
            ->where('ear_tag', $request->ear_tag)
            ->first();

        $record = RekamMedis::create([
            'user_id'              => $userId,
            'id_domba'             => $domba?->id_domba,
            'ear_tag'              => $request->ear_tag,
            'tanggal_pemeriksaan'  => $request->tanggal_pemeriksaan,
            'berat'                => $request->berat,
            'suhu_tubuh'           => $request->suhu_tubuh,
            'status_kesehatan'     => $request->status_kesehatan,
            'vaksinasi'            => $request->vaksinasi,
            'obat'                 => $request->obat,
            'catatan'              => $request->catatan,
        ]);

        // Also update the domba's weight and status if provided
        if ($domba) {
            $updates = [];
            if ($request->filled('berat')) {
                $updates['berat'] = $request->berat;
            }
            if ($request->filled('status_kesehatan')) {
                $statusKesehatanStr = strtolower($request->status_kesehatan);
                if (\Illuminate\Support\Str::contains($statusKesehatanStr, 'bunting')) {
                    $updates['status'] = 'Bunting';
                } elseif (\Illuminate\Support\Str::contains($statusKesehatanStr, 'sehat')) {
                    $updates['status'] = 'Sehat';
                } else {
                    // Any other status in a medical record implies sick
                    $updates['status'] = 'Sakit';
                }
            }
            if ($request->filled('vaksinasi')) {
                $updates['vaksinasi'] = $request->vaksinasi;
            }
            if (!empty($updates)) {
                $domba->update($updates);
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Rekam medis berhasil disimpan.',
            'data'    => $record,
        ], 201);
    }

    /**
     * GET /api/domba/{id}/rekam-medis
     * Ambil rekam medis berdasarkan id domba.
     */
    public function byDomba(Request $request, string $idDomba)
    {
        $userId = $request->user()->id;

        $records = RekamMedis::where('user_id', $userId)
            ->where('id_domba', $idDomba)
            ->orderBy('tanggal_pemeriksaan', 'desc')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data'    => $records,
        ]);
    }

    /**
     * GET /api/domba/{id}/berat-history
     * Riwayat berat domba dari rekam medis, dikelompokkan per bulan.
     * Juga menghitung perubahan berat, rata-rata pertumbuhan, dan growth alert.
     */
    public function beratHistory(Request $request, string $idDomba)
    {
        $userId = $request->user()->id;

        // Verify domba belongs to user
        $domba = Domba::where('user_id', $userId)->where('id_domba', $idDomba)->first();
        if (!$domba) {
            return response()->json(['success' => false, 'message' => 'Domba tidak ditemukan.'], 404);
        }

        // Fetch all rekam medis with berat, ordered oldest first
        $records = RekamMedis::where('user_id', $userId)
            ->where('id_domba', $idDomba)
            ->whereNotNull('berat')
            ->orderBy('tanggal_pemeriksaan', 'asc')
            ->get(['tanggal_pemeriksaan', 'berat']);

        // Group by year-month, take the last (most recent) record of each month
        $monthlyMap = [];
        foreach ($records as $r) {
            $key = \Carbon\Carbon::parse($r->tanggal_pemeriksaan)->format('Y-m');
            $monthlyMap[$key] = (float) $r->berat;
        }

        // Build monthly list for chart
        $monthly = [];
        foreach ($monthlyMap as $ym => $berat) {
            $dt = \Carbon\Carbon::createFromFormat('Y-m', $ym);
            $monthly[] = [
                'year'  => (int) $dt->year,
                'month' => (int) $dt->month,
                'label' => $dt->translatedFormat('M Y'),
                'berat' => $berat,
            ];
        }

        // Analytics
        $beratCount = count($monthly);
        $perubahanBerat = null;
        $rataRataPertumbuhan = null;
        $growthAlert = false;
        $lastIncreaseDays = null;

        if ($beratCount >= 2) {
            $first = $monthly[0]['berat'];
            $last  = $monthly[$beratCount - 1]['berat'];
            $perubahanBerat = round($last - $first, 2);
            $rataRataPertumbuhan = round($perubahanBerat / ($beratCount - 1), 2);
        }

        // Growth Alert: check if no weight increase in last 30 days
        // Compare the most recent record vs the one 30+ days ago
        if ($records->count() >= 2) {
            $latest = $records->last();
            $latestDate = \Carbon\Carbon::parse($latest->tanggal_pemeriksaan);
            $threshold  = $latestDate->copy()->subDays(30);

            // Find the most recent record that is at least 30 days before the latest
            $older = $records->filter(function ($r) use ($threshold) {
                return \Carbon\Carbon::parse($r->tanggal_pemeriksaan)->lte($threshold);
            })->last();

            if ($older) {
                $lastIncreaseDays = (int) \Carbon\Carbon::parse($older->tanggal_pemeriksaan)
                    ->diffInDays($latestDate);
                if ((float) $latest->berat <= (float) $older->berat) {
                    $growthAlert = true;
                }
            }
        }

        return response()->json([
            'success' => true,
            'data' => [
                'ear_tag'             => $domba->ear_tag,
                'berat_sekarang'      => $domba->berat,
                'monthly'             => $monthly,
                'perubahan_berat'     => $perubahanBerat,
                'rata_rata_pertumbuhan' => $rataRataPertumbuhan,
                'growth_alert'        => $growthAlert,
                'last_increase_days'  => $lastIncreaseDays,
            ],
        ]);
    }

    /**
     * GET /api/rekam-medis/{id}
     * Detail satu rekam medis.
     */
    public function show(Request $request, int $id)
    {
        $record = RekamMedis::where('user_id', $request->user()->id)
            ->findOrFail($id);

        return response()->json([
            'success' => true,
            'data'    => $record,
        ]);
    }

    /**
     * DELETE /api/rekam-medis/{id}
     */
    public function destroy(Request $request, int $id)
    {
        $record = RekamMedis::where('user_id', $request->user()->id)
            ->findOrFail($id);

        $record->delete();

        return response()->json([
            'success' => true,
            'message' => 'Rekam medis berhasil dihapus.',
        ]);
    }
}
