<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import api from '@/lib/api';

const router = useRouter();
const form = ref({
  monto_solicitado: 5000,
  plazo_meses: 3,
  motivo: '',
});
const guardando = ref(false);
const listo = ref(false);
const error = ref('');

async function enviar() {
  if (!form.value.monto_solicitado || !form.value.plazo_meses) return;
  guardando.value = true;
  error.value = '';
  try {
    await api.post('/solicitudes', form.value);
    listo.value = true;
    setTimeout(() => router.push('/mi-prestamo'), 2500);
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Error';
  } finally { guardando.value = false; }
}
</script>

<template>
  <div class="px-4 py-4 pb-16 space-y-4">
    <div class="flex items-center gap-3">
      <button @click="router.back()" class="text-panda-700 text-lg">←</button>
      <h1 class="text-2xl font-extrabold">Solicitar préstamo</h1>
    </div>

    <div v-if="listo" class="card p-8 text-center space-y-3 bg-emerald-50 border-emerald-200">
      <div class="text-6xl">✅</div>
      <div class="text-lg font-bold">Solicitud enviada</div>
      <p class="text-sm text-slate-600">Mamá revisará tu solicitud pronto. Te avisaremos por WhatsApp.</p>
    </div>

    <template v-else>
      <div class="card p-5 space-y-4">
        <label for="sol-monto" class="block">
          <span class="text-sm font-semibold text-slate-600">¿Cuánto necesitas?</span>
          <input id="sol-monto" v-model.number="form.monto_solicitado" type="number" step="500" min="500" class="input mt-1 text-3xl font-bold text-center" />
        </label>

        <label for="sol-plazo" class="block">
          <span class="text-sm font-semibold text-slate-600">¿En cuántos meses lo pagarás?</span>
          <div class="grid grid-cols-4 gap-2 mt-2">
            <button v-for="n in [1, 2, 3, 4, 6, 8, 10, 12]" :key="n" @click="form.plazo_meses = n"
              class="py-3 rounded-2xl font-bold transition"
              :class="form.plazo_meses === n ? 'bg-panda-500 text-white' : 'bg-white border-2 border-panda-200 text-slate-700'">
              {{ n }}
            </button>
          </div>
        </label>

        <label for="sol-motivo" class="block">
          <span class="text-sm font-semibold text-slate-600">¿Para qué? (opcional)</span>
          <textarea id="sol-motivo" v-model="form.motivo" rows="3" class="input mt-1" placeholder="Ej: Emergencia médica, pago de renta..." />
        </label>
      </div>

      <p v-if="error" class="text-red-600 text-sm text-center">{{ error }}</p>

      <button @click="enviar" :disabled="guardando" class="btn-primary w-full text-lg py-4">
        {{ guardando ? 'Enviando...' : 'Enviar solicitud' }}
      </button>
      <p class="text-xs text-center text-slate-500">Mamá revisará y responderá en menos de 24 horas.</p>
    </template>
  </div>
</template>
