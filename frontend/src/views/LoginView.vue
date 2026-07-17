<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';

const router = useRouter();
const auth = useAuthStore();

type Modo = 'elegir' | 'mama-pin' | 'cliente-tel' | 'cliente-otp';
const modo = ref<Modo>('elegir');

const telefono = ref('');
const nombre = ref('');
const pin = ref('');
const otp = ref('');

const cargando = ref(false);
const error = ref('');
const requiereNombre = ref(false);
const mensajeEnvio = ref('');

async function loginMama() {
  error.value = '';
  cargando.value = true;
  try {
    await auth.loginMama(telefono.value, pin.value);
    router.push('/');
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Error';
  } finally { cargando.value = false; }
}

async function pedirOtp() {
  error.value = '';
  cargando.value = true;
  try {
    const r = await auth.requestOtp(telefono.value, nombre.value);
    mensajeEnvio.value = r.sent_via === 'whatsapp' ? '📱 Te enviamos un código por WhatsApp' : `Código de prueba: ${r.debug_code}`;
    modo.value = 'cliente-otp';
  } catch (e: any) {
    const msg = e.response?.data?.error ?? 'Error';
    if (msg.includes('no está registrado')) requiereNombre.value = true;
    error.value = msg;
  } finally { cargando.value = false; }
}

async function validarOtp() {
  error.value = '';
  cargando.value = true;
  try {
    await auth.verifyOtp(telefono.value, otp.value);
    router.push('/');
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Error';
  } finally { cargando.value = false; }
}
</script>

<template>
  <div class="min-h-screen flex flex-col justify-center px-6 py-8 bg-gradient-to-br from-panda-50 via-white to-panda-100">
    <!-- Header/branding -->
    <div class="text-center mb-10">
      <img src="/logo.svg" alt="PanditaCash" class="w-28 h-28 mx-auto mb-4 drop-shadow-lg" />
      <h1 class="text-4xl font-extrabold bg-gradient-to-r from-panda-500 to-panda-700 bg-clip-text text-transparent tracking-tight">PanditaCash</h1>
      <p class="text-slate-600 mt-2 text-sm font-medium">Préstamos con corazón 🐼</p>
    </div>

    <!-- Elegir tipo -->
    <div v-if="modo === 'elegir'" class="space-y-3">
      <button @click="modo = 'mama-pin'" class="w-full bg-gradient-to-r from-panda-500 to-panda-600 text-white font-bold rounded-3xl py-5 shadow-lg shadow-panda-500/30 active:scale-[0.97] transition">
        👩 Soy mamá (administradora)
      </button>
      <button @click="modo = 'cliente-tel'" class="w-full bg-white border-2 border-panda-200 text-ink font-bold rounded-3xl py-5 hover:border-panda-500 active:scale-[0.97] transition">
        🙋 Soy cliente
      </button>
      <p class="text-center text-xs text-slate-500 mt-6">Tu información está segura y privada.</p>
    </div>

    <!-- Login mamá con PIN -->
    <div v-if="modo === 'mama-pin'" class="space-y-4">
      <button @click="modo = 'elegir'" class="text-panda-700 text-sm">← Cambiar</button>
      <div class="card p-6 space-y-4">
        <h2 class="text-xl font-bold text-center">Hola mamá 👋</h2>
        <label for="tel-mama" class="block">
          <span class="text-sm font-semibold text-slate-600">Tu teléfono</span>
          <input id="tel-mama" v-model="telefono" type="tel" inputmode="numeric" placeholder="55 XXXX XXXX" class="input mt-1" />
        </label>
        <label for="pin-mama" class="block">
          <span class="text-sm font-semibold text-slate-600">Tu PIN (4 dígitos)</span>
          <input id="pin-mama" v-model="pin" type="password" inputmode="numeric" maxlength="6" placeholder="••••" class="input mt-1 text-center tracking-widest text-3xl" />
        </label>
        <p v-if="error" class="text-red-600 text-sm text-center">{{ error }}</p>
        <button @click="loginMama" :disabled="cargando" class="btn-primary w-full">
          {{ cargando ? 'Entrando...' : 'Entrar' }}
        </button>
      </div>
    </div>

    <!-- Login cliente teléfono -->
    <div v-if="modo === 'cliente-tel'" class="space-y-4">
      <button @click="modo = 'elegir'" class="text-panda-700 text-sm">← Cambiar</button>
      <div class="card p-6 space-y-4">
        <h2 class="text-xl font-bold text-center">Bienvenido</h2>
        <p class="text-sm text-slate-500 text-center">Te enviaremos un código por WhatsApp.</p>
        <label for="tel-cli" class="block">
          <span class="text-sm font-semibold text-slate-600">Tu teléfono (10 dígitos)</span>
          <input id="tel-cli" v-model="telefono" type="tel" inputmode="numeric" placeholder="55 XXXX XXXX" class="input mt-1" />
        </label>
        <label v-if="requiereNombre" for="nom-cli" class="block">
          <span class="text-sm font-semibold text-slate-600">Tu nombre completo</span>
          <input id="nom-cli" v-model="nombre" placeholder="Ej: Liliana Martínez" class="input mt-1" />
        </label>
        <p v-if="error" class="text-red-600 text-sm text-center">{{ error }}</p>
        <button @click="pedirOtp" :disabled="cargando" class="btn-primary w-full">
          {{ cargando ? 'Enviando...' : 'Enviarme el código' }}
        </button>
      </div>
    </div>

    <!-- Validar OTP -->
    <div v-if="modo === 'cliente-otp'" class="space-y-4">
      <button @click="modo = 'cliente-tel'" class="text-panda-700 text-sm">← Cambiar teléfono</button>
      <div class="card p-6 space-y-4">
        <h2 class="text-xl font-bold text-center">Código de acceso</h2>
        <p v-if="mensajeEnvio" class="text-sm text-emerald-700 text-center bg-emerald-50 py-2 rounded-lg">{{ mensajeEnvio }}</p>
        <label for="otp-cli" class="block">
          <span class="text-sm font-semibold text-slate-600">Código de 6 dígitos</span>
          <input id="otp-cli" v-model="otp" type="tel" inputmode="numeric" maxlength="6" placeholder="000000" class="input mt-1 text-center tracking-widest text-3xl" />
        </label>
        <p v-if="error" class="text-red-600 text-sm text-center">{{ error }}</p>
        <button @click="validarOtp" :disabled="cargando" class="btn-primary w-full">
          {{ cargando ? 'Validando...' : 'Entrar' }}
        </button>
      </div>
    </div>
  </div>
</template>
