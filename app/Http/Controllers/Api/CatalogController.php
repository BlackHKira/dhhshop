<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class CatalogController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $query = Product::with(['category', 'inventory'])
            ->whereHas('store', fn ($q) => $q->where('is_active', true))
            ->where('is_available', true);

        if ($request->filled('search')) {
            $query->where('name', 'ilike', '%'.$this->escapeLike($request->string('search')->toString()).'%');
        }

        if ($request->filled('category')) {
            $query->where('category_id', $request->integer('category'));
        }

        $sort = match ($request->string('sort')->toString()) {
            'price_asc' => ['price', 'asc'],
            'price_desc' => ['price', 'desc'],
            'newest' => ['created_at', 'desc'],
            default => ['sort_order', 'asc'],
        };
        $query->orderBy($sort[0], $sort[1]);

        return ProductResource::collection(
            $query->paginate($request->integer('per_page', 20))
        );
    }

    public function show(Product $product): ProductResource
    {
        $product->load(['category', 'inventory', 'specs']);

        return new ProductResource($product);
    }

    private function escapeLike(string $value): string
    {
        return str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $value);
    }
}
