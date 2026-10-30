import { MantineThemeOverride, Tuple } from '@mantine/core';

export const fontFamily = "'Barlow', sans-serif";
export const displayFontFamily = "'Barlow Condensed', 'Barlow', sans-serif";

// Navy panel palette
export const panel = {
  header: 'rgba(15, 20, 29, 0.94)',
  body: 'rgba(22, 30, 43, 0.90)',
  solid: '#171e2a',
  row: 'rgba(26, 40, 58, 0.78)',
  rowSelected: '#ffffff',
  hint: 'rgba(15, 20, 29, 0.94)',
  text: '#ffffff',
  textMuted: '#98a2b3',
  inputBg: '#ffffff',
  inputText: '#111721',
  inputMuted: '#8a919c',
};

type Palette = Tuple<string, 10>;

const cyan: Palette = [
  '#e3fbff',
  '#bdf5fc',
  '#92eefa',
  '#6be8f8',
  '#4ee3f6',
  '#42e0f5',
  '#3de0f5',
  '#2bbdd0',
  '#1e97a7',
  '#146f7c',
];

const dark: Palette = [
  '#f2f5f9',
  '#c9d0db',
  '#98a2b3',
  '#6b7688',
  '#3f4a5c',
  '#2b3546',
  '#1c2534',
  '#171e2a',
  '#121822',
  '#0b0f16',
];

export const theme: MantineThemeOverride = {
  colorScheme: 'dark',
  fontFamily,
  headings: { fontFamily: displayFontFamily, fontWeight: 700 },
  colors: { cyan, dark },
  primaryColor: 'cyan',
  primaryShade: 6,
  defaultRadius: 0,
  radius: { xs: 0, sm: 0, md: 0, lg: 0, xl: 0 },
  shadows: { sm: '1px 1px 3px rgba(0, 0, 0, 0.5)' },
  components: {
    Button: {
      styles: (theme) => ({
        root: {
          border: 'none',
          height: 44,
          borderRadius: 0,
          fontFamily: displayFontFamily,
          fontStyle: 'italic',
          fontWeight: 700,
          fontSize: 20,
          letterSpacing: 0.5,
          textTransform: 'uppercase',
          color: theme.colors.dark[9],
          backgroundColor: theme.fn.primaryColor(),
          '&:hover': { backgroundColor: theme.colors.cyan[4] },
          '&:disabled': { backgroundColor: theme.colors.dark[5], color: theme.colors.dark[3] },
        },
      }),
    },
    Modal: {
      styles: (theme) => ({
        modal: {
          backgroundColor: panel.body,
          borderRadius: 0,
          padding: '0 !important',
          overflow: 'visible',
          boxShadow: '0 10px 40px rgba(0, 0, 0, 0.45)',
        },
        header: { margin: 0, padding: '18px 24px 6px' },
        title: {
          width: '100%',
          margin: 0,
          fontFamily: displayFontFamily,
          fontStyle: 'italic',
          fontWeight: 700,
          fontSize: 30,
          lineHeight: 1,
          textTransform: 'uppercase',
          color: panel.text,
        },
        body: { padding: '8px 24px 24px' },
      }),
    },
    InputWrapper: {
      styles: (theme) => ({
        label: {
          marginBottom: 6,
          fontFamily: fontFamily,
          fontWeight: 700,
          fontSize: 14,
          letterSpacing: 0.3,
          textTransform: 'uppercase',
          color: panel.textMuted,
        },
        required: { color: theme.fn.primaryColor() },
        description: { marginTop: -2, marginBottom: 6, fontSize: 13, color: theme.colors.dark[3] },
        error: { fontSize: 12 },
      }),
    },
    Input: {
      styles: (theme) => ({
        input: {
          height: 44,
          minHeight: 44,
          borderRadius: 0,
          border: 'none',
          fontFamily: fontFamily,
          fontSize: 17,
          backgroundColor: panel.inputBg,
          color: panel.inputText,
          '&::placeholder': { color: panel.inputMuted },
          '&:disabled': { backgroundColor: theme.colors.dark[1], color: theme.colors.dark[4], opacity: 1 },
          '&:focus, &:focus-within': { outline: `2px solid ${theme.fn.primaryColor()}`, outlineOffset: -2 },
        },
        icon: { color: panel.inputMuted },
        rightSection: { color: panel.inputMuted },
      }),
    },
    PasswordInput: {
      styles: () => ({
        innerInput: {
          height: 44,
          fontFamily: fontFamily,
          fontSize: 17,
          color: panel.inputText,
          '&::placeholder': { color: panel.inputMuted },
        },
        visibilityToggle: { color: panel.inputMuted },
      }),
    },
    Textarea: {
      styles: () => ({ input: { height: 'auto', minHeight: 90, paddingTop: 10 } }),
    },
    Select: {
      styles: (theme) => ({
        dropdown: {
          backgroundColor: theme.colors.dark[8],
          border: 'none',
          borderRadius: 0,
          boxShadow: '0 8px 24px rgba(0, 0, 0, 0.5)',
        },
        item: {
          borderRadius: 0,
          fontSize: 16,
          color: theme.white,
          '&[data-hovered]': { backgroundColor: theme.colors.dark[5] },
          '&[data-selected]': { backgroundColor: theme.fn.primaryColor(), color: theme.colors.dark[9] },
        },
      }),
    },
    MultiSelect: {
      styles: (theme) => ({
        dropdown: {
          backgroundColor: theme.colors.dark[8],
          border: 'none',
          borderRadius: 0,
          boxShadow: '0 8px 24px rgba(0, 0, 0, 0.5)',
        },
        item: {
          borderRadius: 0,
          fontSize: 16,
          color: theme.white,
          '&[data-hovered]': { backgroundColor: theme.colors.dark[5] },
          '&[data-selected]': { backgroundColor: theme.fn.primaryColor(), color: theme.colors.dark[9] },
        },
        value: {
          borderRadius: 0,
          backgroundColor: theme.colors.dark[6],
          color: theme.white,
          fontWeight: 600,
        },
        defaultValueRemove: { color: theme.white },
        input: { height: 'auto', minHeight: 44 },
      }),
    },
    NumberInput: {
      styles: (theme) => ({
        control: { border: 'none', color: panel.inputMuted, '&:hover': { backgroundColor: 'transparent' } },
      }),
    },
    Checkbox: {
      styles: (theme) => ({
        label: { fontFamily: fontFamily, fontWeight: 600, fontSize: 17, color: theme.white },
        input: {
          borderRadius: 0,
          backgroundColor: theme.colors.dark[8],
          border: `2px solid ${theme.colors.dark[4]}`,
          '&:checked': { backgroundColor: theme.fn.primaryColor(), borderColor: theme.fn.primaryColor() },
        },
        icon: { color: theme.colors.dark[9] },
      }),
    },
    Slider: {
      styles: (theme) => ({
        track: { '&::before': { backgroundColor: theme.colors.dark[5], borderRadius: 0 } },
        bar: { backgroundColor: theme.fn.primaryColor(), borderRadius: 0 },
        thumb: {
          width: 20,
          height: 20,
          border: `4px solid ${theme.fn.primaryColor()}`,
          backgroundColor: theme.white,
        },
        mark: { borderColor: theme.colors.dark[5], backgroundColor: theme.white, width: 5, height: 5 },
        markFilled: { borderColor: theme.white },
        markLabel: { fontSize: 15, marginTop: 8, color: theme.colors.dark[2] },
      }),
    },
    DatePicker: {
      styles: (theme) => ({
        dropdown: { backgroundColor: theme.colors.dark[8], border: 'none', borderRadius: 0 },
        day: {
          borderRadius: 0,
          color: theme.colors.dark[1],
          fontSize: 16,
          '&:hover': { backgroundColor: theme.colors.dark[5] },
          '&[data-selected]': { backgroundColor: theme.fn.primaryColor(), color: theme.colors.dark[9] },
          '&[data-weekend]': { color: '#ff6b6b' },
          '&[data-outside]': { color: theme.colors.dark[4] },
        },
        weekday: { color: theme.colors.dark[3], fontSize: 15 },
        calendarHeaderLevel: { color: theme.colors.dark[1], fontSize: 16, fontWeight: 600 },
        calendarHeaderControl: { color: theme.colors.dark[1], borderRadius: 0 },
      }),
    },
    Progress: {
      styles: (theme) => ({
        root: { borderRadius: 0, backgroundColor: theme.colors.dark[5] },
        bar: { borderRadius: 0 },
      }),
    },
    Tooltip: {
      styles: (theme) => ({
        tooltip: { backgroundColor: panel.header, color: theme.colors.dark[1], borderRadius: 0 },
      }),
    },
  },
};
