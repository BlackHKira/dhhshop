<template>
    <main class="flex min-h-screen items-center justify-center bg-gray-50 px-4">
        <div class="w-full max-w-md">
            <h1 class="text-center text-2xl font-bold text-gray-900">Đăng ký</h1>
            <p class="mt-2 text-center text-sm text-gray-600">
                Đã có tài khoản?
                <RouterLink to="/login" class="font-medium text-gray-900 hover:underline">Đăng nhập</RouterLink>
            </p>

            <form class="mt-8 space-y-6" @submit.prevent="submit">
                <div>
                    <label for="name" class="block text-sm font-medium text-gray-700">Họ và tên</label>
                    <input
                        id="name"
                        v-model="form.name"
                        type="text"
                        required
                        class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-gray-900 focus:outline-none focus:ring-gray-900"
                    />
                </div>

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
                        autocomplete="new-password"
                        minlength="8"
                        class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-gray-900 focus:outline-none focus:ring-gray-900"
                    />
                </div>

                <div>
                    <label for="password_confirmation" class="block text-sm font-medium text-gray-700">
                        Nhập lại mật khẩu
                    </label>
                    <input
                        id="password_confirmation"
                        v-model="form.password_confirmation"
                        type="password"
                        required
                        autocomplete="new-password"
                        class="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-gray-900 focus:outline-none focus:ring-gray-900"
                    />
                </div>

                <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

                <button
                    type="submit"
                    :disabled="auth.loading"
                    class="w-full rounded-md bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-700 disabled:opacity-50"
                >
                    {{ auth.loading ? 'Đang đăng ký...' : 'Đăng ký' }}
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
const form = reactive({ name: '', email: '', password: '', password_confirmation: '' });
const error = ref('');

async function submit() {
    error.value = '';
    try {
        await auth.register(form);
        router.push({ name: 'home' });
    } catch (e) {
        error.value = e.response?.data?.message ?? 'Đăng ký thất bại.';
    }
}
</script>