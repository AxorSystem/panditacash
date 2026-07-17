<script setup lang="ts">
import { ref, onMounted } from 'vue';
import api from '@/lib/api';

interface Pago {
  id: number; prestamo_id: number; numero_pago: number; monto_esperado: number;
  fecha_programada: string; mora_diaria: number; cliente_nombre: string; cliente_tel: string;
  dias_retraso: number; mora_acumulada: number; total_a_cobrar: number;
  urgencia: 'vencido' | 'hoy' | 'pronto' | 'futuro';
}
interface Stats {
  prestado_activo: number;
  por_cobrar_hoy: number; por_cobrar_hoy_n: number;
  vencidos: number; vencidos_n: number;
  proximos_7d: number; proximos_7d_n: number;
  solicitudes_pendientes: number;
}

const stats = ref<Stats | null>(null);
const pagos = ref<Pago[]>([]);
const cargando = ref(true);

async function cargar() {
  cargando.value = true;
  try {
    const r = await api.get('/prestamos/dashboard');
    stats.value = r.data.stats;
    pagos.value = r.data.pagos_pendientes;
  } finally { cargando.value = false; }
}

onMounted(cargar);

function fmt(n: number) {
  return '$' + Math.round(n).toLocaleString('es-MX');
}
function fmtDia(d: string) {
  const f = new Date(d);
  return f.toLocaleDateString('es-MX', { day: '2-digit', month: 'short' });
}
</script>

<template>
  <div class="px-4 py-4 pb-24">
    <div v-if="cargando" class="text-center py-16 text-slate-400">Cargando...</div>

    <div v-else-if="stats" class="space-y-4">
      <!-- Alerta grande si hay vencidos -->
      <div v-if="stats.vencidos_n > 0" class="card p-5 bg-red-50 border-red-200">
        <div class="flex items-center gap-3">
          <div class="text-4xl">🚨</div>
          <div class="flex-1">
            <div class="text-sm text-red-800 font-bold uppercase tracking-wider">Ya vencidos</div>
            <div class="text-3xl font-extrabold text-red-700">{{ fmt(stats.vencidos) }}</div>
            <div class="text-sm text-red-600">{{ stats.vencidos_n }} {{ stats.vencidos_n === 1 ? 'persona' : 'personas' }}</div>
          </div>
        </div>
      </div>

      <!-- KPIs principales -->
      <div class="grid grid-cols-2 gap-3">
        <div class="card p-4">
          <div class="text-xs text-slate-500 font-medium uppercase tracking-wider">Vence hoy</div>
          <div class="text-2xl font-extrabold text-panda-700 mt-1">{{ fmt(stats.por_cobrar_hoy) }}</div>
          <div class="text-xs text-slate-500 mt-0.5">{{ stats.por_cobrar_hoy_n }} pagos</div>
        </div>
        <div class="card p-4">
          <div class="text-xs text-slate-500 font-medium uppercase tracking-wider">Próx. 7 días</div>
          <div class="text-2xl font-extrabold text-amber-600 mt-1">{{ fmt(stats.proximos_7d) }}</div>
          <div class="text-xs text-slate-500 mt-0.5">{{ stats.proximos_7d_n }} pagos</div>
        </div>
        <div class="card p-4 col-span-2">
          <div class="text-xs text-slate-500 font-medium uppercase tracking-wider">Prestado activo</div>
          <div class="text-3xl font-extrabold mt-1">{{ fmt(stats.prestado_activo) }}</div>
        </div>
      </div>

      <!-- Botón grande solicitudes -->
      <router-link v-if="stats.solicitudes_pendientes > 0" to="/mama/solicitudes" class="card p-4 flex items-center gap-3 bg-panda-100 border-panda-300 active:scale-[0.98] transition">
        <div class="text-3xl">📩</div>
        <div class="flex-1">
          <div class="font-bold text-panda-800">{{ stats.solicitudes_pendientes }} {{ stats.solicitudes_pendientes === 1 ? 'solicitud nueva' : 'solicitudes nuevas' }}</div>
          <div class="text-sm text-panda-700">Toca para revisar</div>
        </div>
        <div class="text-panda-700">→</div>
      </router-link>

      <!-- Lista de pagos pendientes -->
      <div class="space-y-3">
        <div class="text-sm font-bold text-slate-500 uppercase tracking-wider px-1 pt-2">Por cobrar</div>
        <div v-if="pagos.length === 0" class="card p-8 text-center text-slate-400">
          <div class="text-4xl mb-2">✨</div>
          Todo al corriente
        </div>
        <router-link v-for="p in pagos" :key="p.id" :to="`/mama/prestamo/${p.prestamo_id}`" class="card p-4 flex items-center gap-3 active:scale-[0.98] transition"
          :class="{
            'border-red-300 bg-red-50': p.urgencia === 'vencido',
            'border-amber-300 bg-amber-50': p.urgencia === 'hoy',
            'border-panda-200': p.urgencia === 'pronto' || p.urgencia === 'futuro',
          }">
          <div class="flex-1 min-w-0">
            <div class="font-bold text-lg text-slate-900 truncate">{{ p.cliente_nombre }}</div>
            <div class="flex items-center gap-2 mt-1 flex-wrap">
              <span v-if="p.urgencia === 'vencido'" class="chip-danger">🚨 Vencido {{ p.dias_retraso }}d</span>
              <span v-else-if="p.urgencia === 'hoy'" class="chip-warn">📅 Hoy</span>
              <span v-else class="chip-muted">{{ fmtDia(p.fecha_programada) }}</span>
              <span v-if="p.mora_acumulada > 0" class="chip-danger">+{{ fmt(p.mora_acumulada) }} mora</span>
            </div>
          </div>
          <div class="text-right">
            <div class="text-lg font-extrabold">{{ fmt(p.total_a_cobrar) }}</div>
            <div class="text-xs text-slate-500">Pago {{ p.numero_pago }}</div>
          </div>
        </router-link>
      </div>
    </div>

    <!-- Botón flotante nuevo préstamo -->
    <router-link to="/mama/nuevo" class="fixed bottom-6 right-6 max-w-md mx-auto z-20 bg-gradient-to-r from-panda-500 to-panda-600 text-white font-bold px-6 py-4 rounded-full shadow-2xl shadow-panda-500/40 active:scale-95 transition flex items-center gap-2">
      <span class="text-2xl">+</span> Nuevo préstamo
    </router-link>
  </div>
</template>
