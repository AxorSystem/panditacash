<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import api from '@/lib/api';

const router = useRouter();

const form = ref({
  telefono: '',
  nombre: '',
  principal: 10000,
  tasa_mensual_pct: 15,
  plazo_meses: 3,
  mora_diaria: 50,
  notas: '',
});

const sim = ref<{ interes_mensual: number; monto_entregado: number; total_a_pagar: number; ganancia_total: number } | null>(null);
const guardando = ref(false);
const error = ref('');

async function simular() {
  if (!form.value.principal || !form.value.tasa_mensual_pct || !form.value.plazo_meses) return;
  try {
    const r = await api.post('/prestamos/simular', {
      principal: form.value.principal,
      tasa_mensual: form.value.tasa_mensual_pct / 100,
      plazo_meses: form.value.plazo_meses,
    });
    sim.value = r.data;
  } catch { sim.value = null; }
}

watch(() => [form.value.principal, form.value.tasa_mensual_pct, form.value.plazo_meses], simular, { immediate: true });

async function crear() {
  if (!form.value.telefono || !form.value.nombre) { error.value = 'Falta teléfono y nombre'; return; }
  error.value = '';
  guardando.value = true;
  try {
    const r = await api.post('/prestamos', {
      telefono: form.value.telefono,
      nombre: form.value.nombre,
      principal: form.value.principal,
      tasa_mensual: form.value.tasa_mensual_pct / 100,
      plazo_meses: form.value.plazo_meses,
      mora_diaria: form.value.mora_diaria,
      notas: form.value.notas,
    });
    router.push(`/mama/prestamo/${r.data.id}`);
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Error';
  } finally { guardando.value = false; }
}

function fmt(n: number) { return '$' + Math.round(n).toLocaleString('es-MX'); }
</script>

<template>
  <div class="px-4 py-4 pb-16 space-y-4">
    <div class="flex items-center gap-3">
      <button @click="router.back()" class="text-panda-700 text-lg">←</button>
      <h1 class="text-2xl font-extrabold">Nuevo préstamo</h1>
    </div>

    <!-- Datos del cliente -->
    <div class="card p-5 space-y-3">
      <div class="text-sm font-bold text-slate-500 uppercase tracking-wider">Cliente</div>
      <label for="np-nombre" class="block">
        <span class="text-sm font-semibold text-slate-600">Nombre completo</span>
        <input id="np-nombre" v-model="form.nombre" placeholder="Ej: Liliana Martínez" class="input mt-1" />
      </label>
      <label for="np-tel" class="block">
        <span class="text-sm font-semibold text-slate-600">WhatsApp (10 dígitos)</span>
        <input id="np-tel" v-model="form.telefono" type="tel" inputmode="numeric" placeholder="55 XXXX XXXX" class="input mt-1" />
      </label>
    </div>

    <!-- Términos -->
    <div class="card p-5 space-y-3">
      <div class="text-sm font-bold text-slate-500 uppercase tracking-wider">Términos</div>
      <label for="np-principal" class="block">
        <span class="text-sm font-semibold text-slate-600">Monto del préstamo</span>
        <input id="np-principal" v-model.number="form.principal" type="number" step="500" class="input mt-1 text-2xl font-bold" />
      </label>
      <div class="grid grid-cols-2 gap-3">
        <label for="np-tasa" class="block">
          <span class="text-sm font-semibold text-slate-600">Interés / mes</span>
          <div class="relative mt-1">
            <input id="np-tasa" v-model.number="form.tasa_mensual_pct" type="number" step="1" min="1" max="50" class="input pr-8" />
            <span class="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 font-bold">%</span>
          </div>
        </label>
        <label for="np-plazo" class="block">
          <span class="text-sm font-semibold text-slate-600">Plazo</span>
          <div class="relative mt-1">
            <input id="np-plazo" v-model.number="form.plazo_meses" type="number" step="1" min="1" max="24" class="input pr-16" />
            <span class="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 font-bold text-sm">meses</span>
          </div>
        </label>
      </div>
      <label for="np-mora" class="block">
        <span class="text-sm font-semibold text-slate-600">Mora por día de retraso</span>
        <input id="np-mora" v-model.number="form.mora_diaria" type="number" step="10" class="input mt-1" />
        <span class="text-xs text-slate-400">0 si no cobrarás mora</span>
      </label>
      <label for="np-notas" class="block">
        <span class="text-sm font-semibold text-slate-600">Notas privadas (opcional)</span>
        <textarea id="np-notas" v-model="form.notas" rows="2" class="input mt-1" placeholder="Ej: cliente puntual, vecina de la Sra. Rosa..."></textarea>
      </label>
    </div>

    <!-- Simulación -->
    <div v-if="sim" class="card p-5 space-y-2 bg-gradient-to-br from-panda-50 to-white border-panda-200">
      <div class="text-sm font-bold text-panda-700 uppercase tracking-wider">Cálculo</div>
      <div class="flex justify-between text-sm">
        <span class="text-slate-600">Interés mensual</span>
        <span class="font-semibold">{{ fmt(sim.interes_mensual) }}</span>
      </div>
      <div class="flex justify-between text-lg border-t border-panda-100 pt-2">
        <span class="text-slate-700 font-bold">Entregar en efectivo</span>
        <span class="font-extrabold text-panda-700">{{ fmt(sim.monto_entregado) }}</span>
      </div>
      <div class="flex justify-between text-sm">
        <span class="text-slate-600">Cliente pagará total</span>
        <span>{{ fmt(sim.total_a_pagar) }}</span>
      </div>
      <div class="flex justify-between text-sm border-t border-panda-100 pt-2">
        <span class="text-emerald-700 font-bold">Ganancia total</span>
        <span class="text-emerald-700 font-extrabold">{{ fmt(sim.ganancia_total) }}</span>
      </div>
    </div>

    <p v-if="error" class="text-red-600 text-sm text-center bg-red-50 p-3 rounded-xl">{{ error }}</p>

    <button @click="crear" :disabled="guardando" class="btn-primary w-full text-lg py-4">
      {{ guardando ? 'Creando...' : '✓ Aprobar y crear préstamo' }}
    </button>
  </div>
</template>
