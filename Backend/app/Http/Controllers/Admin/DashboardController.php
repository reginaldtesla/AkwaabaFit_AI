<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Support\AdminStats;
use Illuminate\View\View;

class DashboardController extends Controller
{
    public function index(): View
    {
        return view('admin.dashboard', [
            'stats' => AdminStats::summary(),
            'users' => AdminStats::recentUsers(),
            'generatedAt' => now(),
        ]);
    }
}
