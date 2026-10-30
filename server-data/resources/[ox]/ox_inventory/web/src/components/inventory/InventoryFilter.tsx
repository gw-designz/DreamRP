import React, { useCallback, useEffect } from 'react';
import { useAppDispatch, useAppSelector } from '../../store';
import { FilterCategory, setCategory, setQuery } from '../../store/filter';
import { Locale } from '../../store/locale';
import { playSound } from '../../utils/sound';

const CATEGORIES: { id: FilterCategory; label: string; icon: React.ReactNode }[] = [
  {
    id: 'all',
    label: 'All',
    icon: (
      <path d="M3 3h5v5H3V3zm6.500 0h5v5h-5V3zM16 3h5v5h-5V3zM3 9.500h5v5H3v-5zm6.500 0h5v5h-5v-5zm6.500 0h5v5h-5v-5zM3 16h5v5H3v-5zm6.500 0h5v5h-5v-5zm6.500 0h5v5h-5v-5z" />
    ),
  },
  {
    id: 'medical',
    label: 'Medical',
    icon: <path d="M2 6h2v12H2V6zm18 0h2v12h-2V6zM10 5h4v5h5v4h-5v5h-4v-5H5v-4h5V5z" />,
  },
  {
    id: 'weapons',
    label: 'Weapons',
    icon: <path d="M2 5h19v5h-7.500l-1.200 2.500H11l-1.700 8H5.500L7.700 10H2V5z" />,
  },
  {
    id: 'tools',
    label: 'Tools',
    icon: (
      <>
        <path d="M3 7h9l2.500 2v3H9l-1 5H4.500l1-5H3V7z" />
        <path
          d="M17 6l2-1.500M18 9.500h3M17 13l2 1.500"
          stroke="currentColor"
          strokeWidth="1.600"
          strokeLinecap="round"
          fill="none"
        />
      </>
    ),
  },
  {
    id: 'food',
    label: 'Food',
    icon: (
      <path d="M6 3h1.500v6h1V3H10v6h1V3h1.500v7a3 3 0 0 1-2.300 2.900L10 21H8l-.2-8.100A3 3 0 0 1 5.500 10V3H6zM17 3c-2 1.200-3 4-3 7h3v11h2V3h-2z" />
    ),
  },
  {
    id: 'money',
    label: 'Money',
    icon: <path d="M2 6h20v12H2V6zm10 2.500a3.500 3.500 0 1 0 0 7 3.500 3.500 0 0 0 0-7z" fillRule="evenodd" />,
  },
];

const InventoryFilter: React.FC = () => {
  const dispatch = useAppDispatch();
  const { query, category } = useAppSelector((state) => state.filter);

  const cycle = useCallback(
    (step: number) => {
      const index = CATEGORIES.findIndex(({ id }) => id === category);
      const next = (index + step + CATEGORIES.length) % CATEGORIES.length;
      dispatch(setCategory(CATEGORIES[next].id));
    },
    [category, dispatch]
  );

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.ctrlKey || event.altKey || event.metaKey || event.repeat) return;

      const target = event.target as HTMLElement | null;
      if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable)) return;

      const key = event.key.toLowerCase();
      if (key !== 'q' && key !== 'e') return;

      playSound('click');
      cycle(key === 'q' ? -1 : 1);
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [cycle]);

  return (
    <>
      <div className="inventory-filter">
        <button className="inventory-filter-button" title="Previous" onClick={() => cycle(-1)}>
          <span className="inventory-filter-glyph">Q</span>
        </button>
        {CATEGORIES.map(({ id, label, icon }) => (
          <button
            key={id}
            title={label}
            className={`inventory-filter-button${category === id ? ' inventory-filter-button--active' : ''}`}
            onClick={() => dispatch(setCategory(id))}
          >
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
              {icon}
            </svg>
          </button>
        ))}
        <button className="inventory-filter-button" title="Next" onClick={() => cycle(1)}>
          <span className="inventory-filter-glyph">E</span>
        </button>
      </div>
      <input
        className="inventory-search"
        type="text"
        value={query}
        placeholder={Locale.ui_search || 'Search...'}
        onChange={(event) => dispatch(setQuery(event.target.value))}
      />
    </>
  );
};

export default InventoryFilter;
