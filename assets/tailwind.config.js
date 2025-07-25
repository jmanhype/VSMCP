// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/*_web.ex",
    "../lib/*_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        'vsm-primary': '#00ff41',
        'vsm-secondary': '#0080ff',
        'vsm-accent': '#ff0080',
        'vsm-warning': '#ffaa00',
        'vsm-dark': '#0a0a0a',
        'vsm-darker': '#050505',
      },
      animation: {
        'neural-pulse': 'neural-pulse 2s ease-in-out infinite',
        'data-flow': 'data-flow 3s linear infinite',
        'grid-move': 'grid-move 10s linear infinite',
        'glow-pulse': 'glow-pulse 3s ease-in-out infinite',
      },
      keyframes: {
        'neural-pulse': {
          '0%, 100%': { opacity: '1', transform: 'scale(1)' },
          '50%': { opacity: '0.6', transform: 'scale(0.98)' },
        },
        'data-flow': {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' },
        },
        'grid-move': {
          '0%': { backgroundPosition: '0 0, 0 0' },
          '100%': { backgroundPosition: '50px 50px, 50px 50px' },
        },
        'glow-pulse': {
          '0%, 100%': { 
            boxShadow: '0 0 20px rgba(0, 255, 65, 0.5)',
          },
          '50%': { 
            boxShadow: '0 0 40px rgba(0, 255, 65, 0.8)',
          },
        },
      },
      fontFamily: {
        'mono': ['JetBrains Mono', 'Fira Code', 'Consolas', 'Monaco', 'monospace'],
      },
      backgroundImage: {
        'vsm-grid': `
          linear-gradient(rgba(0, 255, 65, 0.03) 1px, transparent 1px),
          linear-gradient(90deg, rgba(0, 255, 65, 0.03) 1px, transparent 1px)
        `,
        'vsm-circuit': `
          repeating-linear-gradient(
            90deg,
            transparent,
            transparent 20px,
            rgba(0, 255, 65, 0.05) 20px,
            rgba(0, 255, 65, 0.05) 21px
          ),
          repeating-linear-gradient(
            0deg,
            transparent,
            transparent 20px,
            rgba(0, 255, 65, 0.05) 20px,
            rgba(0, 255, 65, 0.05) 21px
          )
        `,
      },
      boxShadow: {
        'vsm-glow': '0 0 20px rgba(0, 255, 65, 0.5)',
        'vsm-glow-lg': '0 0 40px rgba(0, 255, 65, 0.6)',
        'vsm-glow-sm': '0 0 10px rgba(0, 255, 65, 0.4)',
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Custom plugin for VSM-specific utilities
    plugin(({ addBase, addComponents, addUtilities }) => {
      addBase({
        ':root': {
          '--vsm-primary': '#00ff41',
          '--vsm-secondary': '#0080ff',
          '--vsm-accent': '#ff0080',
          '--vsm-warning': '#ffaa00',
          '--vsm-dark': '#0a0a0a',
          '--vsm-darker': '#050505',
        },
      })
      
      addComponents({
        '.vsm-panel': {
          '@apply relative bg-black/80 border border-green-500/30 rounded-lg': {},
          '&:hover': {
            '@apply border-green-500/60': {},
          },
        },
        '.vsm-button': {
          '@apply relative overflow-hidden px-4 py-2 rounded-lg transition-all duration-300': {},
          '@apply bg-green-500/20 border border-green-500/50 text-green-400': {},
          '@apply hover:bg-green-500/30 hover:border-green-500': {},
          '&:before': {
            content: '""',
            '@apply absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent': {},
            transform: 'translateX(-100%)',
            transition: 'transform 0.6s',
          },
          '&:hover:before': {
            transform: 'translateX(100%)',
          },
        },
        '.vsm-input': {
          '@apply bg-black/60 border border-green-500/30 rounded-lg px-4 py-2': {},
          '@apply text-green-400 placeholder-green-400/30': {},
          '@apply focus:border-green-500 focus:ring-2 focus:ring-green-500/50 focus:outline-none': {},
          '@apply transition-all duration-200': {},
        },
      })
      
      addUtilities({
        '.vsm-glow': {
          boxShadow: 'var(--vsm-glow)',
          textShadow: '0 0 10px currentColor',
        },
        '.vsm-text-glow': {
          textShadow: '0 0 10px currentColor',
        },
        '.vsm-bg-circuit': {
          backgroundImage: `
            repeating-linear-gradient(
              90deg,
              transparent,
              transparent 20px,
              rgba(0, 255, 65, 0.05) 20px,
              rgba(0, 255, 65, 0.05) 21px
            ),
            repeating-linear-gradient(
              0deg,
              transparent,
              transparent 20px,
              rgba(0, 255, 65, 0.05) 20px,
              rgba(0, 255, 65, 0.05) 21px
            )
          `,
        },
      })
    })
  ]
}