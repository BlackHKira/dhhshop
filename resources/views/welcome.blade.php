<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ config('app.name', 'Laravel') }}</title>
    @vite('resources/css/app.css')
</head>
<body class="min-h-screen bg-neutral-100 text-neutral-900 antialiased">
    <main class="mx-auto flex min-h-screen max-w-3xl flex-col items-center justify-center px-6 text-center">
        <h1 class="text-3xl font-bold leading-tight sm:text-4xl">
            {{ config('app.name', 'Backend') }}
        </h1>
        <p class="mt-6 text-lg leading-relaxed text-neutral-600">
            Ứng dụng bán hàng đồ điện tử đa nền tảng bằng Flutter, tích hợp AI Chatbot tư vấn mua sắm.
        </p>
        <div class="mt-10 flex flex-col gap-4 sm:flex-row">
            <a href="#" class="rounded-lg bg-blue-600 px-6 py-3 font-medium text-white hover:bg-blue-700">
                Mở Web App
            </a>
            <a href="#" class="rounded-lg border border-neutral-300 bg-white px-6 py-3 font-medium text-neutral-700 hover:bg-neutral-50">
                Tải APK Android
            </a>
        </div>
        <p class="mt-12 text-sm text-neutral-400">
            API: <code class="rounded bg-neutral-200 px-1.5 py-0.5">GET /health</code> &middot; Flutter client tại <code class="rounded bg-neutral-200 px-1.5 py-0.5">client/</code>
        </p>
    </main>
</body>
</html>