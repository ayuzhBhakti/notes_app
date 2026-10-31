// The onboarding screens' colours, built the way BrandShell (lib/widgets/brand.dart)
// builds them: ColorScheme.fromSeed(seed, DynamicSchemeVariant.fidelity).
// Uses Google's material-color-utilities (vendored, vendor/); v0.3.0 was checked against the Dart
// package Flutter ships (0.13.0) and gives the same hex for every role used.

import { DEFAULT_SEED } from "./resolve.js";

const MCU_URL = "./vendor/material-color-utilities-0.3.0.js";

// Every ColorScheme role the four screens paint with.
const ROLES = [
  "primary", "onPrimary", "primaryContainer", "onPrimaryContainer",
  "secondaryContainer", "onSecondaryContainer", "tertiary",
  "surface", "onSurface", "onSurfaceVariant",
  "surfaceContainerLow", "surfaceContainerHigh", "surfaceContainerHighest",
  "outlineVariant", "error",
];

let mcu = null;
const cache = new Map();

/** Loads the colour library once. Without it a rough scheme is used. */
export async function loadColorLibrary() {
  try {
    mcu = await import(MCU_URL);
  } catch (error) {
    console.warn("Colour library unavailable; preview colours are approximate.", error);
    mcu = null;
  }
  cache.clear();
}

const toHex = (argb) => `#${(argb & 0xffffff).toString(16).padStart(6, "0")}`;

function exactScheme(seed, dark) {
  const argb = parseInt(seed.slice(1), 16) | 0xff000000;
  const scheme = new mcu.SchemeFidelity(mcu.Hct.fromInt(argb), dark, 0);
  return Object.fromEntries(
    ROLES.map((role) => [role, toHex(mcu.MaterialDynamicColors[role].getArgb(scheme))]),
  );
}

// Only for when the CDN is unreachable: close enough to judge a layout.
function roughScheme(seed, dark) {
  const mix = (pct, base) => `color-mix(in srgb, ${seed} ${pct}%, ${base})`;
  return dark
    ? {
      primary: mix(55, "#fff"), onPrimary: "#1b1b1f", primaryContainer: seed, onPrimaryContainer: "#fff",
      secondaryContainer: mix(35, "#1b1b1f"), onSecondaryContainer: "#eee", tertiary: "#ffb68b",
      surface: "#141218", onSurface: "#e6e0e9", onSurfaceVariant: "#cac4d0",
      surfaceContainerLow: "#1d1b20", surfaceContainerHigh: "#2b2930", surfaceContainerHighest: "#36343b",
      outlineVariant: "#49454f", error: "#ffb4ab",
    }
    : {
      primary: seed, onPrimary: "#fff", primaryContainer: mix(25, "#fff"), onPrimaryContainer: mix(80, "#000"),
      secondaryContainer: mix(20, "#fff"), onSecondaryContainer: mix(70, "#000"), tertiary: "#7d5260",
      surface: "#fef7ff", onSurface: "#1d1b20", onSurfaceVariant: "#49454f",
      surfaceContainerLow: "#f7f2fa", surfaceContainerHigh: "#ece6f0", surfaceContainerHighest: "#e6e0e9",
      outlineVariant: "#cac4d0", error: "#b3261e",
    };
}

/** Role -> CSS colour for this seed and brightness. */
export function colorScheme(seed = DEFAULT_SEED, dark = false) {
  const key = `${seed}|${dark}|${mcu ? 1 : 0}`;
  if (!cache.has(key)) cache.set(key, mcu ? exactScheme(seed, dark) : roughScheme(seed, dark));
  return cache.get(key);
}

// ThemeData.estimateBrightnessForColor: dark when (L + 0.05)^2 <= 0.15.
function isDarkColor(hex) {
  const channel = (i) => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  };
  const luminance = 0.2126 * channel(1) + 0.7152 * channel(3) + 0.0722 * channel(5);
  return (luminance + 0.05) ** 2 <= 0.15;
}

/** The paywall's _Accent: the theme's primary, or the backend's accent colour. */
export function accentColors(scheme, accentHex) {
  if (!accentHex) {
    return {
      color: scheme.primary, onColor: scheme.onPrimary,
      container: scheme.primaryContainer, onContainer: scheme.onPrimaryContainer,
    };
  }
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(accentHex.slice(i, i + 2), 16));
  return {
    color: accentHex,
    onColor: isDarkColor(accentHex) ? "#ffffff" : "#000000",
    container: `rgba(${r}, ${g}, ${b}, 0.15)`,
    onContainer: accentHex,
  };
}

const kebab = (s) => s.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`);

/** Inline CSS custom properties for one phone. */
export function cssVars(scheme, accent) {
  const roles = Object.entries(scheme).map(([role, value]) => `--${kebab(role)}:${value}`);
  const acc = Object.entries(accent).map(([role, value]) => `--accent-${kebab(role)}:${value}`);
  return [...roles, ...acc].join(";");
}
