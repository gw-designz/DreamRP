import { createSlice, PayloadAction } from '@reduxjs/toolkit';

export type FilterCategory = 'all' | 'medical' | 'weapons' | 'tools' | 'food' | 'money';

interface FilterState {
  query: string;
  category: FilterCategory;
}

const initialState: FilterState = {
  query: '',
  category: 'all',
};

export const filterSlice = createSlice({
  name: 'filter',
  initialState,
  reducers: {
    setQuery(state, action: PayloadAction<string>) {
      state.query = action.payload;
    },
    setCategory(state, action: PayloadAction<FilterCategory>) {
      state.category = action.payload;
    },
    resetFilter(state) {
      state.query = '';
      state.category = 'all';
    },
  },
});

export const { setQuery, setCategory, resetFilter } = filterSlice.actions;

export default filterSlice.reducer;
