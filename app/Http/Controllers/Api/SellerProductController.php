<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Store;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class SellerProductController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $products = Product::query()
            ->with(['category', 'inventory'])
            ->where('store_id', $this->activeStore()->id)
            ->orderByDesc('created_at')
            ->get();

        return ProductResource::collection($products);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);

        $store = $this->activeStore();
        $product = Product::create([
            'store_id' => $store->id,
            'category_id' => $data['category_id'],
            'sku' => $data['sku'],
            'name' => $this->sanitizeText((string) $data['name']),
            'description' => $this->sanitizeText((string) $data['description']),
            'price' => $data['price'],
            'image_url' => null,
            'is_available' => $data['is_available'],
            'sort_order' => $data['sort_order'] ?? 0,
        ]);

        $this->syncSpecs($product, $data['specs'] ?? []);
        $stock = $data['stock'] ?? 0;
        if ($stock > 0) {
            $product->inventory()->create([
                'store_id' => $store->id,
                'stock_on_hand' => $stock,
                'stock_reserved' => 0,
            ]);
            StockMovement::create([
                'store_id' => $store->id,
                'product_id' => $product->id,
                'type' => 'purchase',
                'quantity' => $stock,
                'reason' => 'Nhập kho khi tạo sản phẩm',
                'actor_id' => $request->user()->id,
                'created_at' => now(),
            ]);
        }

        return (new ProductResource($product->load(['category', 'inventory', 'specs'])))
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function update(Request $request, Product $product): ProductResource
    {
        abort_unless($this->belongsToActiveStore($product), Response::HTTP_FORBIDDEN, 'Không thuộc cửa hàng của bạn.');

        $data = $this->validated($request, $product);

        $product->update([
            'category_id' => $data['category_id'],
            'sku' => $data['sku'],
            'name' => $this->sanitizeText((string) $data['name']),
            'description' => $this->sanitizeText((string) $data['description']),
            'price' => $data['price'],
            'is_available' => $data['is_available'],
            'sort_order' => $data['sort_order'] ?? $product->sort_order,
        ]);

        $product->specs()->delete();
        $this->syncSpecs($product, $data['specs'] ?? []);

        if ($product->inventory === null && ($data['stock'] ?? 0) > 0) {
            $product->inventory()->create([
                'store_id' => $product->store_id,
                'stock_on_hand' => $data['stock'],
                'stock_reserved' => 0,
            ]);
        }

        return new ProductResource($product->load(['category', 'inventory', 'specs']));
    }

    public function uploadImage(Request $request, Product $product): JsonResponse
    {
        abort_unless($this->belongsToActiveStore($product), Response::HTTP_FORBIDDEN, 'Không thuộc cửa hàng của bạn.');

        $request->validate([
            'image' => ['required', 'image', 'mimes:jpeg,png,webp', 'max:4096'],
        ]);

        $storage = Storage::disk('public');
        $oldPath = null;
        if ($product->image_url !== null && str_starts_with($product->image_url, '/storage/product-images/')) {
            $oldPath = 'product-images/'.basename($product->image_url);
        }

        $path = $request->file('image')->store('product-images', 'public');
        if ($oldPath !== null && $storage->exists($oldPath)) {
            $storage->delete($oldPath);
        }

        $product->update(['image_url' => Storage::disk('public')->url($path)]);

        return response()->json(['image_url' => $product->image_url]);
    }

    public function destroy(Request $request, Product $product): JsonResponse
    {
        abort_unless($this->belongsToActiveStore($product), Response::HTTP_FORBIDDEN, 'Không thuộc cửa hàng của bạn.');

        $product->delete();

        return response()->json(['message' => 'Đã xóa sản phẩm.'], Response::HTTP_OK);
    }

    /**
     * @return array<string, mixed>
     */
    private function validated(Request $request, ?Product $product = null): array
    {
        $data = $request->validate([
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'sku' => [
                'required', 'string', 'max:64',
                Rule::unique('products', 'sku')->where('store_id', $this->activeStore()->id)->ignore($product),
            ],
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'price' => ['required', 'numeric', 'min:0', 'max:999999999'],
            'is_available' => ['sometimes', 'boolean'],
            'sort_order' => ['sometimes', 'integer'],
            'stock' => ['sometimes', 'integer', 'min:0', 'max:1000000'],
            'specs' => ['sometimes', 'array'],
            'specs.*.key' => ['required_with:specs', 'string', 'max:50'],
            'specs.*.value' => ['required_with:specs', 'string', 'max:255'],
        ]);

        $data['category_id'] ??= null;
        $data['description'] = (string) ($data['description'] ?? '');
        $data['sort_order'] ??= 0;
        $data['stock'] ??= 0;
        $data['is_available'] = (bool) ($data['is_available'] ?? true);
        $data['specs'] = $this->normalizeSpecs($data['specs'] ?? []);

        return $data;
    }

    /**
     * @param  array<int, array{key?: string, value?: string}>  $specs
     * @return array<int, array{spec_key: string, spec_value: string}>
     */
    private function normalizeSpecs(array $specs): array
    {
        $out = [];
        foreach ($specs as $spec) {
            $key = trim((string) ($spec['key'] ?? ''));
            $value = trim((string) ($spec['value'] ?? ''));
            if ($key === '' || $value === '') {
                continue;
            }
            $out[] = ['spec_key' => $this->sanitizeText($key), 'spec_value' => $this->sanitizeText($value)];
        }

        return $out;
    }

    /**
     * @param  array<int, array{spec_key?: string, spec_value?: string}>  $specs
     */
    private function syncSpecs(Product $product, array $specs): void
    {
        $existing = collect($product->specs()->get()->keyBy('spec_key'));
        $incoming = collect($specs)->keyBy('spec_key');

        foreach ($incoming as $key => $spec) {
            if ($existing->has($key)) {
                $existing[$key]->update(['spec_value' => $spec['spec_value']]);
            } else {
                $product->specs()->create($spec);
            }
        }

        $product->specs()->whereIn('spec_key', $existing->keys()->diff($incoming->keys()))->delete();
    }

    private function activeStore(): Store
    {
        return Store::query()->where('is_active', true)->firstOrFail();
    }

    private function belongsToActiveStore(Product $product): bool
    {
        return $product->store_id === $this->activeStore()->id;
    }

    private function sanitizeText(string $value): string
    {
        $value = trim($value);

        if ($value === '') {
            return $value;
        }

        $value = preg_replace('/<(\/)?(script|style|iframe|object|embed|form|link|meta)(\s[^>]*)?>.*?<\/\2\s*>/is', '', $value) ?? $value;

        return trim(strip_tags($value));
    }
}
