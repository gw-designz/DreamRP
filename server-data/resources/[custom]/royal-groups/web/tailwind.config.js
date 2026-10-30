/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        display: ['Quantico', 'Rajdhani', 'sans-serif'],
      },
      colors: {
        main: {
          DEFAULT: '#BFFF74',
          dim: 'rgba(162, 202, 49, 0.4)',
        },
      },
    },
  },
  plugins: [],
}
