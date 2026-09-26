<?php

namespace App\Http\Resources;

use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Product */
class ProductResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $specs = $this->relationLoaded('specs')
            ? $this->specs->pluck('spec_value', 'spec_key')
            : collect();

        return [
            'id' => $this->id,
            'store_id' => $this->store_id,
            'category' => $this->whenLoaded('category', fn () => [
                'id' => $this->category->id,
                'name' => $this->category->name,
            ]),
            'sku' => $this->sku,
            'name' => $this->name,
            'description' => $this->description,
            'price' => (float) $this->price,
            'image_url' => $this->image_url,
            'is_available' => $this->is_available,
            'specs' => $specs,
            'stock_available' => $this->whenLoaded('inventory', fn () => $this->inventory?->stock_available),
        ];
    }
}
