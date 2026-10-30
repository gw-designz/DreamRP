import React from 'react';
import { getCategoryLucideIcon } from './CategoryIcons';
import { PageHeader } from './ui';

export default function Sidebar({
  navPath,
  setNavPath,
  categories
}: {
  navPath: string[],
  setNavPath: (path: string[]) => void,
  categories: any[]
}) {
  const mainTab = navPath[0];

  const handleSelect = (item: string) => {
    if (navPath.length === 1 && mainTab === 'APPAREL') {
      setNavPath([mainTab, item]);
    } else if (navPath.length === 2 && mainTab === 'APPAREL') {
      setNavPath([mainTab, navPath[1], item]);
    } else {
      setNavPath([mainTab, item]);
    }
  };

  return (
    <div className="w-[446px] flex flex-col pointer-events-auto select-none relative z-10">
      <PageHeader navPath={navPath} setNavPath={setNavPath} />

      <div className="flex flex-col gap-[4px] mt-2 max-h-[calc(100vh-260px)] overflow-y-auto styled-scrollbar">
        {categories.map((itemObj: any) => {
          const item = itemObj.label;
          const isActive = navPath[navPath.length - 1] === item;
          return (
            <button key={item}
              type="button"
              onClick={() => handleSelect(item)}
              className={`
                group flex items-center gap-4 w-full h-[56px] px-6 flex-shrink-0 border-l-[3px] transition-colors cursor-pointer
                ${isActive ? 'bg-white text-black border-white' : 'np-panel text-white border-white/80 hover:bg-white hover:text-black'}
              `}>
              {getCategoryLucideIcon(item, 'w-[24px] h-[24px]')}
              <span className="font-np font-bold italic text-[24px] uppercase leading-none">
                {item}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
