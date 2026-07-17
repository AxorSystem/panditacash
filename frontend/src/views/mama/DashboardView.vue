<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import api from '@/lib/api';
import { fmt, fmtDiaCorto } from '@/lib/format';

interface Pago {
  id: number; prestamo_id: number; numero_pago: number;
  cliente_nombre: string; cliente_tel: string; usuario_id: number;
  monto_esperado: number; fecha_programada: string;
  capital_pendiente: number; mora_pendiente: number; total_pendiente: number;
  mora_bruta: number; dias_retraso: number;
  urgencia: 'vencido' | 'hoy' | 'pronto' | 'futuro';
}
interface Stats {
  prestado_activo: number;
  por_cobrar_hoy: number; por_cobrar_hoy_n: number;
  vencidos: number; vencidos_n: number;
  proximos_7d: number; proximos_7d_n: number;
  total_pendiente: number;
  solicitudes_pendientes: number;
  prestamos_activos_n: number;
  clientes_activos_n: number;
}

const stats = ref<Stats | null>(null);
const pagos = ref<Pago[]>([]);
const cargando = ref(true);
const filtro = ref<'urgentes' | 'todos'>('urgentes');

async function cargar() {
  cargando.value = true;
  try {
    const r = await api.get('/prestamos/dashboard');
    stats.value = r.data.stats;
    pagos.value = r.data.pagos_pendientes;
  } finally { cargando.value = false; }
}
onMounted(cargar);

const pagosFiltrados = computed(() => {
  if (filtro.value === 'urgentes') {
    return pagos.value.filter(p => p.urgencia !== 'futuro');
  }
  return pagos.value;
});
</script>

<template>
  <div class="px-4 py-4 space-y-4">
    <div v-if="cargando" class="text-center py-16 text-slate-400">Cargando…</div>

    <template v-else-if="stats">
      <!-- Header con saludo -->
      <div class="pt-2">
        <div class="text-slate-500 text-sm">Hola mamá 👋</div>
        <div class="text-2xl font-extrabold">Buenos días</div>
      </div>

      <!-- Alerta grande si hay vencidos -->
      <router-link v-if="stats.vencidos_n > 0" to="#" class="block card p-5 bg-red-50 border-red-200">
        <div class="flex items-center gap-3">
          <div class="text-4xl">🚨</div>
          <div class="flex-1 min-w-0">
            <div class="text-xs text-red-800 font-bold uppercase tracking-wider">Deben pagarte YA</div>
            <div class="text-3xl font-extrabold text-red-700">{{ fmt(stats.vencidos) }}</div>
            <div class="text-sm text-red-600">{{ stats.vencidos_n }} {{ stats.vencidos_n === 1 ? 'persona atrasada' : 'personas atrasadas' }}</div>
          </div>
        </div>
      </router-link>

      <!-- KPIs -->
      <div class="grid grid-cols-2 gap-3">
        <div class="card p-4">
          <div class="text-xs text-slate-500 font-bold uppercase tracking-wider">Vence hoy</div>
          <div class="text-2xl font-extrabold text-panda-700 mt-1">{{ fmt(stats.por_cobrar_hoy) }}</div>
          <div class="text-xs text-slate-500 mt-0.5">{{ stats.por_cobrar_hoy_n }} pagos</div>
        </div>
        <div class="card p-4">
          <div class="text-xs text-slate-500 font-bold uppercase tracking-wider">Próx. 7 días</div>
          <div class="text-2xl font-extrabold text-amber-600 mt-1">{{ fmt(stats.proximos_7d) }}</div>
          <div class="text-xs text-slate-500 mt-0.5">{{ stats.proximos_7d_n }} pagos</div>
        </div>
        <div class="card p-4">
          <div class="text-xs text-slate-500 font-bold uppercase tracking-wider">Prestado activo</div>
          <div class="text-2xl font-extrabold mt-1">{{ fmt(stats.prestado_activo) }}</div>
          <div class="text-xs text-slate-500 mt-0.5">{{ stats.prestamos_activos_n }} préstamos</div>
        </div>
        <div class="card p-4">
          <div class="text-xs text-slate-500 font-bold uppercase tracking-wider">Clientes activos</div>
          <div class="text-2xl font-extrabold mt-1">{{ stats.clientes_activos_n }}</div>
          <div class="text-xs text-slate-500 mt-0.5">con pagos pendientes</div>
        </div>
      </div>

      <!-- Solicitudes -->
      <router-link v-if="stats.solicitudes_pendientes > 0" to="/mama/solicitudes" class="card p-4 flex items-center gap-3 bg-panda-100 border-panda-300 active:scale-[0.98] transition">
        <div class="text-3xl">📩</div>
        <div class="flex-1">
          <div class="font-bold text-panda-800">{{ stats.solicitudes_pendientes }} {{ stats.solicitudes_pendientes === 1 ? 'solicitud nueva' : 'solicitudes nuevas' }}</div>
          <div class="text-sm text-panda-700">Toca para revisar</div>
        </div>
        <div class="text-panda-700 text-2xl">→</div>
      </router-link>

      <!-- Filtro -->
      <div class="flex gap-2">
        <button @click="filtro = 'urgentes'"
          class="flex-1 py-2 rounded-full font-bold text-sm transition"
          :class="filtro === 'urgentes' ? 'bg-panda-500 text-white' : 'bg-white border border-panda-200 text-slate-600'">
          Urgentes ({{ pagos.filter(p => p.urgencia !== 'futuro').length }})
        </button>
        <button @click="filtro = 'todos'"
          class="flex-1 py-2 rounded-full font-bold text-sm transition"
          :class="filtro === 'todos' ? 'bg-panda-500 text-white' : 'bg-white border border-panda-200 text-slate-600'">
          Todos ({{ pagos.length }})
        </button>
      </div>

      <!-- Lista de pagos pendientes -->
      <div class="space-y-2">
        <div v-if="pagosFiltrados.length === 0" class="card p-8 text-center text-slate-400">
          <div class="text-4xl mb-2">✨</div>
          {{ filtro === 'urgentes' ? 'Nada urgente' : 'Todo al corriente' }}
        </div>
        <router-link v-for="p in pagosFiltrados" :key="p.id" :to="`/mama/prestamo/${p.prestamo_id}`" class="card p-4 flex items-center gap-3 active:scale-[0.98] transition"
          :class="{
            'border-red-300 bg-red-50': p.urgencia === 'vencido',
            'border-amber-300 bg-amber-50': p.urgencia === 'hoy',
            'border-panda-200': p.urgencia === 'pronto' || p.urgencia === 'futuro',
          }">
          <div class="flex-1 min-w-0">
            <div class="font-bold text-lg text-slate-900 truncate">{{ p.cliente_nombre }}</div>
            <div class="flex items-center gap-2 mt-1 flex-wrap">
              <span v-if="p.urgencia === 'vencido'" class="chip-danger">🚨 {{ p.dias_retraso }}d atrasado</span>
              <span v-else-if="p.urgencia === 'hoy'" class="chip-warn">📅 HOY</span>
              <span v-else class="chip-muted">📅 {{ fmtDiaCorto(p.fecha_programada) }}</span>
              <span v-if="p.mora_pendiente > 0" class="chip-danger">+{{ fmt(p.mora_pendiente) }} mora</span>
              <span v-if="p.monto_esperado > p.capital_pendiente" class="chip-warn">⚠️ Parcial</span>
            </div>
          </div>
          <div class="text-right">
            <div class="text-lg font-extrabold">{{ fmt(p.total_pendiente) }}</div>
            <div class="text-xs text-slate-500">Pago {{ p.numero_pago }}</div>
          </div>
        </router-link>
      </div>
    </template>

    <!-- Botón flotante nuevo préstamo -->
    <router-link to="/mama/nuevo" class="fixed bottom-24 right-6 max-w-md mx-auto z-30 bg-gradient-to-r from-panda-500 to-panda-600 text-white font-bold px-5 py-3 rounded-full shadow-2xl shadow-panda-500/40 active:scale-95 transition flex items-center gap-1">
      <span class="text-xl leading-none">+</span> Nuevo préstamo
    </router-link>
  </div>
</template>
