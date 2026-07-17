import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.axorsystem.panditacash',
  appName: 'PanditaCash',
  webDir: 'dist',
  bundledWebRuntime: false,
  server: {
    // La app carga la web en producción — así los cambios de UI/backend no
    // requieren reinstalar el APK/IPA. Si prefieres que la app funcione offline
    // con los assets embebidos, comenta la línea de `url` y compila el webDir.
    url: 'https://panditacash.5-78-222-255.sslip.io',
    cleartext: false,
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 1500,
      launchAutoHide: true,
      backgroundColor: '#FFF5E4',
      androidSplashResourceName: 'splash',
      showSpinner: false,
    },
    StatusBar: {
      style: 'DARK',
      backgroundColor: '#F59E0B',
    },
  },
  ios: {
    contentInset: 'always',
    backgroundColor: '#FFF5E4',
  },
  android: {
    backgroundColor: '#FFF5E4',
    allowMixedContent: false,
  },
};

export default config;
