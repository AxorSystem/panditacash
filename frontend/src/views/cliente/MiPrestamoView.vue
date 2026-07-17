<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useAuthStore } from '@/stores/auth';
import api from '@/lib/api';

const auth = useAuthStore();
const data = ref<any>(null);
const cargando = ref(true);
const avisando = ref(false);
const mensajeAviso = ref('');

async function cargar() {
  cargando.value = true;
  const r = await api.get('/mi/resumen');
  data.value = r.data;
  cargando.value = false;
}
onMounted(cargar);

async function avisarPago() {
  if (!data.value?.proximo_pago) return;
  avisando.value = true;
  try {
    await api.post('/mi/avisar-pago', { pago_id: data.value.proximo_pago.id });
    mensajeAviso.value = '✅ Le avisamos a mamá que ya pagaste. Ella lo confirmará pronto.';
  } finally { avisando.value = false; }
}

function fmt(n: number) { return '$' + Math.round(n).toLocaleString('es-MX'); }
function fmtDia(d: string) { return new Date(d).toLocaleDateString('es-MX', { day: '2-digit', month: 'long' }); }
function diasHasta(d: string): number {
  const hoy = new Date(); hoy.setHours(0, 0, 0, 0);
  const f = new Date(d); f.setHours(0, 0, 0, 0);
  return Math.round((f.getTime() - hoy.getTime()) / 86400000);
}
</script>

<template>
  <div v-if="cargando" class="text-center py-20 text-slate-400">Cargando...</div>
  <div v-else class="px-4 py-4 pb-16 space-y-4">
    <div class="pt-2">
      <div class="text-lg text-slate-500">Hola,</div>
      <div class="text-3xl font-extrabold">{{ auth.user?.nombre }} 👋</div>
    </div>

    <!-- Sin préstamo activo -->
    <div v-if="!data.prestamo_activo" class="card p-8 text-center space-y-3">
      <div class="text-6xl">🐼</div>
      <div class="text-lg font-bold">No tienes préstamos activos</div>
      <p class="text-sm text-slate-500">¿Necesitas dinero? Solicita un préstamo a mamá.</p>
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
          {{ data.proximo_pago.dias_retraso > 0 ? '🚨 Vencido' : 'Próximo pago' }}
        </div>
        <div class="text-5xl font-extrabold my-2">{{ fmt(data.proximo_pago.total) }}</div>
        <div class="text-slate-700">
          <div v-if="data.proximo_pago.dias_retraso > 0" class="text-red-600 font-bold">
            Debiste pagar hace {{ data.proximo_pago.dias_retraso }} días
          </div>
          <div v-else-if="diasHasta(data.proximo_pago.fecha_programada) === 0" class="font-bold">Vence HOY</div>
          <div v-else-if="diasHasta(data.proximo_pago.fecha_programada) === 1" class="font-bold">Vence mañana</div>
          <div v-else>Vence en {{ diasHasta(data.proximo_pago.fecha_programada) }} días — {{ fmtDia(data.proximo_pago.fecha_programada) }}</div>
        </div>
        <div v-if="data.proximo_pago.mora > 0" class="text-sm text-red-600 mt-2">
          + {{ fmt(data.proximo_pago.mora) }} de mora acumulada
        </div>

        <button v-if="!mensajeAviso" @click="avisarPago" :disabled="avisando" class="btn-primary w-full mt-4">
          {{ avisando ? 'Avisando...' : '✋ Ya pagué' }}
        </button>
        <p v-else class="text-sm text-emerald-700 text-center bg-emerald-50 py-3 rounded-xl mt-4">{{ mensajeAviso }}</p>
      </div>

      <!-- Resumen del préstamo -->
      <div class="card p-5 space-y-2">
        <div class="text-sm font-bold text-slate-500 uppercase tracking-wider">Tu préstamo</div>
        <div class="text-3xl font-extrabold">{{ fmt(data.prestamo_activo.principal) }}</div>
        <div class="text-sm text-slate-600">
          📅 {{ data.prestamo_activo.plazo_meses }} meses · {{ (data.prestamo_activo.tasa_mensual * 100).toFixed(0) }}% / mes
        </div>
        <div class="grid grid-cols-2 gap-3 mt-3">
          <div class="bg-emerald-50 rounded-xl p-3">
            <div class="text-xs text-emerald-700 font-bold uppercase">Ya pagaste</div>
            <div class="text-xl font-extrabold text-emerald-800">{{ fmt(data.total_pagado) }}</div>
          </div>
          <div class="bg-amber-50 rounded-xl p-3">
            <div class="text-xs text-amber-700 font-bold uppercase">Te falta</div>
            <div class="text-xl font-extrabold text-amber-800">{{ fmt(data.total_pendiente) }}</div>
          </div>
        </div>
      </div>

      <router-link :to="`/mama/prestamo/${data.prestamo_activo.id}`" class="text-center block text-sm text-panda-700 py-2">
        Ver historial completo →
      </router-link>
    </template>

    <!-- Solicitud pendiente -->
    <div v-if="data.solicitud_pendiente && data.prestamo_activo" class="card p-4 bg-panda-50 border-panda-200">
      <div class="text-sm text-panda-800">📩 Solicitud pendiente: <b>{{ fmt(data.solicitud_pendiente.monto_solicitado) }}</b></div>
    </div>
  </div>
</template>
