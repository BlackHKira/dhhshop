<template>
    <main class="flex min-h-screen items-center justify-center bg-gray-50 px-4">
        <div class="w-full max-w-md">
            <h1 class="text-center text-2xl font-bold text-gray-900">Đăng nhập</h1>
            <p class="mt-2 text-center text-sm text-gray-600">
                Chưa có tài khoản?
                <RouterLink to="/register" class="font-medium text-gray-900 hover:underline">Đăng ký</RouterLink>
            </p>

            <form class="mt-8 space-y-6" @submit.prevent="submit">
                <div>
                    <label for="email" class="block text-sm font-medium text-gray-700">Email</label>
                    <input
                        id="email"
                        v-model="form.email"
                        type="email"
                        required
                        autocomplete="email"
                        class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-gray-900 focus:outline-none focus:ring-gray-900"
                    />
                </div>

                <div>
                    <label for="password" class="block text-sm font-medium text-gray-700">Mật khẩu</label>
                    <input
                        id="password"
                        v-model="form.password"
                        type="password"
                        required
                        autocomplete="current-password"
                        class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-gray-900 focus:outline-none focus:ring-gray-900"
                    />
                </div>

                <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

                <button
                    type="submit"
                    :disabled="auth.loading"
                    class="w-full rounded-md bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-700 disabled:opacity-50"
                >
                    {{ auth.loading ? 'Đang đăng nhập...' : 'Đăng nhập' }}
                </button>
            </form>
        </div>
    </main>
</template>

<script setup>
import { reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const router = useRouter();
const auth = useAuthStore();
const form = reactive({ email: '', password: '' });
const error = ref('');

async function submit() {
    error.value = '';
    try {
        await auth.login(form);
        router.push({ name: 'home' });
    } catch (e) {
        error.value = e.response?.data?.message ?? 'Đăng nhập thất bại.';
    }
}
</script>