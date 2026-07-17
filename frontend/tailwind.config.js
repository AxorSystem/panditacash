/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{vue,ts,js}'],
  theme: {
    extend: {
      colors: {
        panda: {
          50: '#FFFBEB',
          100: '#FEF3C7',
          200: '#FDE68A',
          300: '#FCD34D',
          400: '#FBBF24',
          500: '#F59E0B',   // dorado principal
          600: '#D97706',
          700: '#B45309',   // dorado oscuro
          800: '#78350F',
          900: '#451A03',
        },
        ink: '#1F1710',
        soft: '#F5F0E6',
      },
      fontFamily: {
        sans: ['Nunito', 'Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [require('@tailwindcss/forms')],
};
