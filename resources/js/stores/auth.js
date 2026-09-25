import { defineStore } from 'pinia';
import axios from 'axios';

export const useAuthStore = defineStore('auth', {
    state: () => ({
        user: null,
        loading: false,
    }),

    actions: {
        async fetchUser() {
            this.loading = true;
            try {
                const { data } = await axios.get('/api/user');
                this.user = data;
            } catch (error) {
                this.user = null;
            } finally {
                this.loading = false;
            }
        },

        async login(payload) {
            await axios.post('/api/login', payload);
            await this.fetchUser();
        },

        async register(payload) {
            await axios.post('/api/register', payload);
            await this.fetchUser();
        },

        async logout() {
            await axios.post('/api/logout');
            this.user = null;
        },
    },
});