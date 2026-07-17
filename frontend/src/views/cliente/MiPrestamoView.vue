<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useAuthStore } from '@/stores/auth';
import api from '@/lib/api';
import { fmt, fmtDia, fmtHora, diasHasta } from '@/lib/format';

const auth = useAuthStore();
const data = ref<any>(null);
const cargando = ref(true);

async function cargar() {
  cargando.value = true;
  const r = await api.get('/mi/resumen');
  data.value = r.data;
  cargando.value = false;
}
onMounted(cargar);

const progreso = computed(() => {
  if (!data.value?.prestamo_activo) return 0;
  const done = data.value.pagos.filter((p: any) => p.estado === 'pagado' || p.estado === 'pagado_anticipado').length;
  return Math.round((done / data.value.pagos.length) * 100);
});

const estadoIcon: Record<string, string> = {
  pagado: '✅', pagado_anticipado: '🔒', pendiente: '⏳', parcial: '🟡',
};
const estadoColor: Record<string, string> = {
  pagado: 'text-emerald-700', pagado_anticipado: 'text-emerald-700',
  pendiente: 'text-amber-700', parcial: 'text-orange-700',
};
</script>

<template>
  <div v-if="cargando" class="text-center py-20 text-slate-400">Cargando...</div>
  <div v-else class="px-4 py-4 pb-16 space-y-4">
    <div class="pt-2">
      <div class="text-sm text-slate-500">Hola,</div>
      <div class="text-2xl font-extrabold">{{ auth.user?.nombre }} 👋</div>
    </div>

    <!-- Sin préstamo activo -->
    <div v-if="!data.prestamo_activo" class="card p-8 text-center space-y-3">
      <div class="text-6xl">🐼</div>
      <div class="text-lg font-bold">No tienes préstamos activos</div>
      <p class="text-sm text-slate-500">¿Necesitas dinero? Solicita un préstamo.</p>
      <router-link v-if="!data.solicitud_pendiente" to="/solicitar" class="btn-primary inline-block mt-2">Solicitar préstamo</router-link>
      <div v-else class="bg-panda-100 rounded-2xl p-4 text-sm text-panda-800">
        📩 Ya enviaste una solicitud de <b>{{ fmt(data.solicitud_pendiente.monto_solicitado) }}</b>. Espera respuesta.
      </div>
    </div>

    <!-- Préstamo activo -->
    <template v-else>
      <!-- Próximo pago -->
      <div v-if="data.proximo_pago" class="card p-5"
        :class="data.proximo_pago.dias_retraso > 0 ? 'bg-red-50 border-red-300' : 'bg-gradient-to-br from-panda-50 to-white border-panda-300'">
        <div class="text-xs font-bold uppercase tracking-wider" :class="data.proximo_pago.dias_retraso > 0 ? 'text-red-700' : 'text-panda-700'">
          {{ data.proximo_pago.dias_retraso > 0 ? '🚨 Debes pagar' : 'Tu próximo pago' }}
        </div>
        <div class="text-5xl font-extrabold my-2">{{ fmt(data.proximo_pago.total_pendiente) }}</div>
        <div class="text-slate-700">
          <div v-if="data.proximo_pago.dias_retraso > 0" class="text-red-600 font-bold">
            Debiste pagar hace {{ data.proximo_pago.dias_retraso }} días
          </div>
          <div v-else-if="diasHasta(data.proximo_pago.fecha_programada) === 0" class="font-bold">Vence HOY</div>
          <div v-else-if="diasHasta(data.proximo_pago.fecha_programada) === 1" class="font-bold">Vence mañana</div>
          <div v-else>Vence en {{ diasHasta(data.proximo_pago.fecha_programada) }} días — {{ fmtDia(data.proximo_pago.fecha_programada) }}</div>
        </div>
        <div v-if="Number(data.proximo_pago.mora_pendiente) > 0" class="text-sm text-red-600 mt-2">
          + {{ fmt(data.proximo_pago.mora_pendiente) }} de mora acumulada
        </div>
        <div class="mt-4 p-3 bg-white/80 rounded-xl text-xs text-slate-600 border border-slate-200">
          💡 Contacta a la Sra. Panda para hacer tu pago. Ella lo registrará en el sistema y recibirás confirmación por WhatsApp.
        </div>
      </div>

      <!-- Resumen del préstamo -->
      <div class="card p-5 space-y-3">
        <div class="text-sm font-bold text-slate-500 uppercase tracking-wider">Tu préstamo</div>
        <div class="text-3xl font-extrabold">{{ fmt(data.prestamo_activo.principal) }}</div>
        <div class="text-sm text-slate-600">
          📅 {{ data.prestamo_activo.plazo_meses }} meses · {{ (data.prestamo_activo.tasa_mensual * 100).toFixed(0) }}% / mes
        </div>
        <div class="h-2 bg-panda-100 rounded-full overflow-hidden">
          <div class="h-full bg-gradient-to-r from-emerald-400 to-emerald-600 rounded-full" :style="{ width: progreso + '%' }"></div>
        </div>
        <div class="text-xs text-center text-slate-500">{{ progreso }}% completado</div>
        <div class="grid grid-cols-2 gap-3">
          <div class="bg-emerald-50 rounded-xl p-3">
            <div class="text-xs text-emerald-700 font-bold uppercase">Pagado</div>
            <div class="text-xl font-extrabold text-emerald-800">{{ fmt(data.total_pagado) }}</div>
          </div>
          <div class="bg-amber-50 rounded-xl p-3">
            <div class="text-xs text-amber-700 font-bold uppercase">Falta</div>
            <div class="text-xl font-extrabold text-amber-800">{{ fmt(data.total_pendiente) }}</div>
          </div>
        </div>
      </div>

      <!-- Historial de pagos programados -->
      <div class="space-y-2">
        <div class="text-sm font-bold text-slate-500 uppercase tracking-wider px-1">Tus pagos</div>
        <div v-for="p in data.pagos" :key="p.id" class="card p-3 flex items-center gap-3">
          <div class="text-2xl">{{ estadoIcon[p.estado] || '⏳' }}</div>
          <div class="flex-1 min-w-0">
            <div class="font-bold">Pago {{ p.numero_pago }}</div>
            <div class="text-xs text-slate-500">{{ fmtDia(p.fecha_programada) }}</div>
          </div>
          <div class="text-right">
            <div class="font-extrabold" :class="estadoColor[p.estado]">{{ fmt(p.monto_esperado) }}</div>
            <div class="text-[10px] uppercase font-bold" :class="estadoColor[p.estado]">{{ p.estado }}</div>
          </div>
        </div>
      </div>

      <!-- Historial de cobros -->
      <div v-if="data.movimientos.length > 0" class="space-y-2">
        <div class="text-sm font-bold text-slate-500 uppercase tracking-wider px-1">Tus abonos</div>
        <div v-for="m in data.movimientos" :key="m.id" class="card p-3 flex items-center gap-3">
          <div class="text-xl">💵</div>
          <div class="flex-1 min-w-0">
            <div class="font-bold text-emerald-700">{{ fmt(Number(m.monto_capital) + Number(m.monto_mora)) }}</div>
            <div class="text-xs text-slate-500">{{ fmtHora(m.fecha_pago) }} · {{ m.metodo }}</div>
          </div>
        </div>
      </div>
    </template>

    <div v-if="data.solicitud_pendiente && data.prestamo_activo" class="card p-4 bg-panda-50 border-panda-200">
      <div class="text-sm text-panda-800">📩 Solicitud pendiente: <b>{{ fmt(data.solicitud_pendiente.monto_solicitado) }}</b></div>
    </div>
  </div>
</template>
