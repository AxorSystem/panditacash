import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from './stores/auth';

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', name: 'login', component: () => import('./views/LoginView.vue'), meta: { public: true } },
    { path: '/', name: 'home', component: () => import('./views/HomeView.vue') },

    // Mamá — bottom tabs
    { path: '/mama', name: 'mama-dashboard', component: () => import('./views/mama/DashboardView.vue'), meta: { admin: true } },
    { path: '/mama/clientes', name: 'mama-clientes', component: () => import('./views/mama/ClientesView.vue'), meta: { admin: true } },
    { path: '/mama/cliente/:id', name: 'mama-cliente-detalle', component: () => import('./views/mama/ClienteDetalleView.vue'), meta: { admin: true }, props: true },
    { path: '/mama/movimientos', name: 'mama-movimientos', component: () => import('./views/mama/MovimientosView.vue'), meta: { admin: true } },
    { path: '/mama/ganancias', name: 'mama-ganancias', component: () => import('./views/mama/GananciasView.vue'), meta: { admin: true } },
    { path: '/mama/nuevo', name: 'mama-nuevo', component: () => import('./views/mama/NuevoPrestamoView.vue'), meta: { admin: true } },
    { path: '/mama/prestamo/:id', name: 'mama-prestamo', component: () => import('./views/mama/PrestamoDetalleView.vue'), meta: { admin: true }, props: true },
    { path: '/mama/solicitudes', name: 'mama-solicitudes', component: () => import('./views/mama/SolicitudesView.vue'), meta: { admin: true } },

    // Cliente
    { path: '/mi-prestamo', name: 'mi-prestamo', component: () => import('./views/cliente/MiPrestamoView.vue') },
    { path: '/solicitar', name: 'solicitar', component: () => import('./views/cliente/SolicitarView.vue') },

    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
});

router.beforeEach((to) => {
  const auth = useAuthStore();
  if (to.meta.public) return;
  if (!auth.isAuth) return { name: 'login' };
  if (to.meta.admin && !auth.esMama) return { name: 'mi-prestamo' };
  if (to.name === 'home') return auth.esMama ? { name: 'mama-dashboard' } : { name: 'mi-prestamo' };
});
