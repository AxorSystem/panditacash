<script setup lang="ts">
import { computed } from 'vue';

interface Score {
  nivel: 'nuevo' | 'bronce' | 'plata' | 'oro' | 'bloqueado';
  emoji: string;
  puntualidad_pct: number;
  prestamos_liquidados: number;
  prestamos_activos: number;
  atrasos_totales: number;
  atrasos_serios: number;
  atraso_max_actual: number;
  monto_maximo_sugerido: number;
  activos_maximos: number;
  tasa_sugerida_pct: number;
  razones: string[];
  puede_prestamo_nuevo: boolean;
}
const props = defineProps<{ score: Score; compacto?: boolean }>();

const colores = {
  nuevo:     { bg: 'bg-blue-50 border-blue-200',       text: 'text-blue-800',    chip: 'bg-blue-100 text-blue-800' },
  bronce:    { bg: 'bg-orange-50 border-orange-200',   text: 'text-orange-800',  chip: 'bg-orange-100 text-orange-800' },
  plata:     { bg: 'bg-slate-50 border-slate-300',     text: 'text-slate-800',   chip: 'bg-slate-200 text-slate-800' },
  oro:       { bg: 'bg-panda-50 border-panda-300',     text: 'text-panda-800',   chip: 'bg-panda-100 text-panda-800' },
  bloqueado: { bg: 'bg-red-50 border-red-300',         text: 'text-red-800',     chip: 'bg-red-100 text-red-800' },
};

const c = computed(() => colores[props.score.nivel]);
const nombreNivel = computed(() => props.score.nivel.charAt(0).toUpperCase() + props.score.nivel.slice(1));

function fmt(n: number) { return '$' + Math.round(Number(n)).toLocaleString('es-MX'); }
</script>

<template>
  <!-- Modo compacto: solo chip -->
  <span v-if="compacto" :class="'chip ' + c.chip">
    {{ score.emoji }} {{ nombreNivel }}
  </span>

  <!-- Modo completo: card -->
  <div v-else class="card p-4 border-2" :class="c.bg">
    <div class="flex items-center gap-3 mb-3">
      <div class="text-4xl">{{ score.emoji }}</div>
      <div class="flex-1 min-w-0">
        <div class="text-xs font-bold uppercase tracking-wider" :class="c.text">Score interno</div>
        <div class="text-2xl font-extrabold" :class="c.text">{{ nombreNivel }}</div>
      </div>
      <div class="text-right">
        <div class="text-xs font-bold uppercase tracking-wider text-slate-500">Puntualidad</div>
        <div class="text-2xl font-extrabold" :class="score.puntualidad_pct >= 80 ? 'text-emerald-700' : (score.puntualidad_pct >= 50 ? 'text-amber-700' : 'text-red-700')">
          {{ score.puntualidad_pct }}%
        </div>
      </div>
    </div>

    <!-- KPIs mini -->
    <div class="grid grid-cols-3 gap-2 text-center mb-3">
      <div class="bg-white/60 rounded-xl p-2">
        <div class="text-lg font-extrabold">{{ score.prestamos_liquidados }}</div>
        <div class="text-[10px] text-slate-500 uppercase font-bold">Liquidados</div>
      </div>
      <div class="bg-white/60 rounded-xl p-2">
        <div class="text-lg font-extrabold" :class="score.prestamos_activos >= score.activos_maximos ? 'text-amber-700' : ''">
          {{ score.prestamos_activos }}/{{ score.activos_maximos }}
        </div>
        <div class="text-[10px] text-slate-500 uppercase font-bold">Activos</div>
      </div>
      <div class="bg-white/60 rounded-xl p-2">
        <div class="text-lg font-extrabold" :class="score.atrasos_serios > 0 ? 'text-red-700' : ''">{{ score.atrasos_totales }}</div>
        <div class="text-[10px] text-slate-500 uppercase font-bold">Atrasos</div>
      </div>
    </div>

    <!-- Sugerencias -->
    <div v-if="score.nivel !== 'bloqueado'" class="text-sm space-y-1 border-t border-white/60 pt-3">
      <div class="flex justify-between">
        <span class="text-slate-600">Monto máx. sugerido</span>
        <span class="font-extrabold" :class="c.text">{{ fmt(score.monto_maximo_sugerido) }}</span>
      </div>
      <div class="flex justify-between">
        <span class="text-slate-600">Tasa sugerida</span>
        <span class="font-bold" :class="c.text">{{ score.tasa_sugerida_pct }}% / periodo</span>
      </div>
    </div>

    <!-- Razones -->
    <div v-if="score.razones.length > 0" class="mt-3 space-y-1">
      <div v-for="(r, i) in score.razones" :key="i" class="text-xs flex items-start gap-1.5" :class="c.text">
        <span>•</span>
        <span>{{ r }}</span>
      </div>
    </div>
  </div>
</template>
