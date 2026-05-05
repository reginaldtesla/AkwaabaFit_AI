<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;

class AiController extends Controller
{
    public function mockScan(): JsonResponse
    {
        return response()->json([
            'prediction' => 'Fufu',
            'confidence' => 96
        ]);
    }
}