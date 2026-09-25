<template>
    <main class="min-h-screen bg-white">
        <header class="border-b border-gray-200">
            <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
                <div class="flex h-16 items-center justify-between">
                    <h1 class="text-xl font-semibold text-gray-900">Website bán đồ điện tử</h1>
                    <nav class="flex items-center gap-4">
                        <RouterLink to="/" class="text-sm text-gray-600 hover:text-gray-900">Trang chủ</RouterLink>
                        <template v-if="auth.user">
                            <span class="text-sm text-gray-600">{{ auth.user.name }}</span>
                            <button
                                type="button"
                                class="text-sm text-gray-600 hover:text-gray-900"
                                @click="auth.logout()"
                            >
                                Đăng xuất
                            </button>
                        </template>
                        <template v-else>
                            <RouterLink
                                to="/login"
                                class="text-sm font-medium text-gray-900 hover:text-gray-600"
                            >
                                Đăng nhập
                            </RouterLink>
                            <RouterLink
                                to="/register"
                                class="rounded-md bg-gray-900 px-3 py-2 text-sm font-medium text-white hover:bg-gray-700"
                            >
                                Đăng ký
                            </RouterLink>
                        </template>
                    </nav>
                </div>
            </div>
        </header>

        <section class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
            <div class="max-w-2xl">
                <h2 class="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
                    Đồ án tốt nghiệp đang được xây dựng
                </h2>
                <p class="mt-4 text-lg text-gray-600">
                    Hệ thống website bán đồ điện tử kèm chatbot tư vấn. Ứng dụng đã scaffold xong —
                    các module (đăng nhập, catalog, giỏ hàng, chat...) sẽ được triển khai trong các phase tiếp theo.
                </p>
            </div>
        </section>
    </main>
</template>

<script setup>
import { useAuthStore } from '../stores/auth';

const auth = useAuthStore();
</script>