<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE roles ADD CONSTRAINT roles_scope_check CHECK (scope in ('system', 'store'))");
        DB::statement("ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_type_check CHECK (type in ('purchase', 'reserve', 'sale_online', 'adjustment', 'return', 'release'))");
        DB::statement("ALTER TABLE carts ADD CONSTRAINT carts_status_check CHECK (status in ('active', 'converted', 'abandoned'))");
        DB::statement("ALTER TABLE orders ADD CONSTRAINT orders_status_check CHECK (status in ('pending', 'confirmed', 'packing', 'shipping', 'delivering', 'delivered', 'completed', 'canceled'))");
        DB::statement("ALTER TABLE orders ADD CONSTRAINT orders_payment_method_check CHECK (payment_method in ('cod', 'bank_transfer'))");
        DB::statement("ALTER TABLE orders ADD CONSTRAINT orders_payment_status_check CHECK (payment_status in ('unpaid', 'paid', 'refunded'))");
        DB::statement("ALTER TABLE deliveries ADD CONSTRAINT deliveries_status_check CHECK (status in ('shipping', 'delivering', 'delivered', 'failed'))");
        DB::statement("ALTER TABLE payments ADD CONSTRAINT payments_method_check CHECK (method in ('cod', 'bank_transfer'))");
        DB::statement("ALTER TABLE payments ADD CONSTRAINT payments_status_check CHECK (status in ('pending', 'paid', 'refunded'))");
        DB::statement("ALTER TABLE chat_conversations ADD CONSTRAINT chat_conversations_status_check CHECK (status in ('active', 'closed'))");
        DB::statement("ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_role_check CHECK (role in ('user', 'assistant', 'system'))");
    }

    public function down(): void
    {
        foreach ([
            'roles' => 'roles_scope_check',
            'stock_movements' => 'stock_movements_type_check',
            'carts' => 'carts_status_check',
            'orders' => 'orders_status_check',
            'orders' => 'orders_payment_method_check',
            'orders' => 'orders_payment_status_check',
            'deliveries' => 'deliveries_status_check',
            'payments' => 'payments_method_check',
            'payments' => 'payments_status_check',
            'chat_conversations' => 'chat_conversations_status_check',
            'chat_messages' => 'chat_messages_role_check',
        ] as $table => $constraint) {
            DB::statement("ALTER TABLE {$table} DROP CONSTRAINT IF EXISTS {$constraint}");
        }
    }
};
