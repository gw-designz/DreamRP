import React, { useState, useEffect } from 'react';
import Nui from '../Nui';
import { Layers, Plus, Download, Share2, Trash2, Check, Copy, X } from 'lucide-react';
import { PageHeader } from './ui';

interface Outfit {
  id: number;
  name: string;
  model?: string | number;
  components?: any;
  props?: any;
}

export default function SavedOutfits({
  navPath,
  setNavPath,
  onOutfitApplied
}: {
  navPath: string[];
  setNavPath: (path: string[]) => void;
  onOutfitApplied?: () => void;
}) {
  const [outfits, setOutfits] = useState<Outfit[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeOutfitId, setActiveOutfitId] = useState<number | null>(null);

  const [showSaveModal, setShowSaveModal] = useState(false);
  const [saveName, setSaveName] = useState('');
  const [showImportModal, setShowImportModal] = useState(false);
  const [importName, setImportName] = useState('');
  const [importCode, setImportCode] = useState('');
  const [importError, setImportError] = useState('');
  const [generatedCode, setGeneratedCode] = useState<{ id: number; code: string } | null>(null);
  const [copied, setCopied] = useState(false);

  const fetchOutfits = () => {
    setLoading(true);
    Nui.post('appearance_get_outfits')
      .then((res: any) => {
        if (Array.isArray(res)) {
          setOutfits(res);
        } else if (res && Array.isArray(res.outfits)) {
          setOutfits(res.outfits);
        } else {
          setOutfits([]);
        }
      })
      .catch(() => setOutfits([]))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchOutfits();
  }, []);

  const handleSaveCurrentOutfit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!saveName.trim()) return;

    Nui.post('appearance_save_outfit', { name: saveName.trim() }).then((res: any) => {
      if (Array.isArray(res)) {
        setOutfits(res);
      } else if (res?.outfits) {
        setOutfits(res.outfits);
      } else {
        fetchOutfits();
      }
      setSaveName('');
      setShowSaveModal(false);
    });
  };

  const handleApplyOutfit = (outfit: Outfit) => {
    setActiveOutfitId(outfit.id);
    Nui.post('appearance_load_outfit', outfit);
    if (onOutfitApplied) onOutfitApplied();
  };

  const handleDeleteOutfit = (outfitId: number) => {
    Nui.post('appearance_delete_outfit', outfitId).then((res: any) => {
      if (Array.isArray(res)) {
        setOutfits(res);
      } else if (res?.outfits) {
        setOutfits(res.outfits);
      } else {
        fetchOutfits();
      }
      if (activeOutfitId === outfitId) setActiveOutfitId(null);
    });
  };

  const handleGenerateCode = (outfitId: number) => {
    setShowSaveModal(false);
    setShowImportModal(false);
    Nui.post('appearance_generate_outfit_code', outfitId).then((code: string) => {
      if (code) {
        setGeneratedCode({ id: outfitId, code });
        setCopied(false);
      }
    });
  };

  const handleCopyCode = () => {
    if (generatedCode?.code) {
      navigator.clipboard.writeText(generatedCode.code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleImportOutfit = (e: React.FormEvent) => {
    e.preventDefault();
    setImportError('');
    if (!importName.trim() || !importCode.trim()) return;

    Nui.post('appearance_import_outfit_code', {
      name: importName.trim(),
      code: importCode.trim()
    }).then((res: any) => {
      if (res?.success) {
        if (res?.outfits) setOutfits(res.outfits);
        else fetchOutfits();
        setImportName('');
        setImportCode('');
        setShowImportModal(false);
      } else {
        setImportError(res?.message || 'Failed to import outfit code. Please verify the code.');
      }
    });
  };

  return (
    <div className="w-[560px] flex flex-col pointer-events-auto select-none relative z-10 text-white">
      <PageHeader navPath={navPath} setNavPath={setNavPath} />

      <div className="flex flex-col np-panel p-3 mt-2">
        <div className="flex gap-2.5 mb-4">
          <button
            onClick={() => {
              setShowImportModal(false);
              setGeneratedCode(null);
              setShowSaveModal((prev) => !prev);
            }}
            className="flex-1 py-2.5 px-4 bg-[#10f6b7] hover:bg-[#5cf9cf] text-black font-np font-bold italic text-[14px] tracking-wider uppercase flex items-center justify-center gap-2 transition-colors cursor-pointer shadow-md"
          >
            <Plus className="w-4 h-4 stroke-[3]" />
            SAVE CURRENT OUTFIT
          </button>
          <button
            onClick={() => {
              setShowSaveModal(false);
              setGeneratedCode(null);
              setImportError('');
              setShowImportModal((prev) => !prev);
            }}
            className="py-2.5 px-4 bg-white/10 hover:bg-zinc-800 text-white font-np font-bold italic text-[14px] tracking-wider uppercase flex items-center justify-center gap-2 transition-colors cursor-pointer border border-white/10"
          >
            <Download className="w-4 h-4" />
            IMPORT CODE
          </button>
        </div>

        <div className="overflow-y-auto max-h-[58vh] pr-1 styled-scrollbar flex flex-col gap-2">
          {loading ? (
            <div className="text-center py-12 font-oswald text-zinc-400 uppercase tracking-widest text-sm">
              Loading Outfits...
            </div>
          ) : outfits.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-center border border-dashed border-white/10 bg-black/30 p-6">
              <Layers className="w-12 h-12 text-zinc-600 mb-3" />
              <span className="font-np font-bold italic text-lg tracking-wider uppercase text-zinc-300">
                NO SAVED OUTFITS
              </span>
              <span className="font-oswald text-xs text-zinc-500 uppercase tracking-wider mt-1">
                Click "+ SAVE CURRENT OUTFIT" to save your current clothing
              </span>
            </div>
          ) : (
            outfits.map((outfit) => {
              const isCurrent = activeOutfitId === outfit.id;
              return (
                <div
                  key={outfit.id}
                  className={`
                    flex items-center justify-between p-3.5 bg-black/40 border transition-all
                    ${isCurrent ? 'border-[#10f6b7] ring-1 ring-[#10f6b7]' : 'border-white/5 hover:border-white/20'}
                  `}
                >
                  <div className="flex items-center gap-3.5 min-w-0">
                    <div className="w-10 h-10 bg-black/50 flex items-center justify-center border border-white/5 text-[#10f6b7] flex-shrink-0">
                      <Layers className="w-5 h-5" />
                    </div>
                    <div className="flex flex-col min-w-0">
                      <span className="font-np font-bold italic text-[16px] text-white tracking-wider uppercase truncate">
                        {outfit.name}
                      </span>
                      <span className="font-oswald text-[11px] text-zinc-400 tracking-wider uppercase">
                        OUTFIT #{outfit.id}
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 flex-shrink-0">
                    <button
                      onClick={() => handleApplyOutfit(outfit)}
                      className={`
                        px-4 py-1.5 font-np font-bold italic text-[13px] tracking-wider uppercase transition-colors cursor-pointer flex items-center gap-1.5
                        ${isCurrent
                          ? 'bg-white text-black'
                          : 'bg-[#10f6b7] hover:bg-[#5cf9cf] text-black'}
                      `}
                    >
                      {isCurrent ? <Check className="w-3.5 h-3.5 stroke-[3]" /> : null}
                      {isCurrent ? 'EQUIPPED' : 'WEAR'}
                    </button>

                    <button
                      onClick={() => handleGenerateCode(outfit.id)}
                      title="Share Outfit Code"
                      className="w-8 h-8 flex items-center justify-center bg-white/10 hover:bg-zinc-700 text-zinc-300 hover:text-white transition-colors cursor-pointer border border-white/5"
                    >
                      <Share2 className="w-4 h-4" />
                    </button>

                    <button
                      onClick={() => handleDeleteOutfit(outfit.id)}
                      title="Delete Outfit"
                      className="w-8 h-8 flex items-center justify-center bg-white/10 hover:bg-red-900/40 text-zinc-400 hover:text-red-400 transition-colors cursor-pointer border border-white/5"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {showSaveModal && (
        <div className="fixed right-12 top-28 z-[120] pointer-events-auto select-none">
          <form
            onSubmit={handleSaveCurrentOutfit}
            className="w-[380px] bg-[#0c0c0c]/90 border-t-[3px] border-t-[#10f6b7] border border-white/10 p-5 flex flex-col gap-4 shadow-2xl"
          >
            <div className="flex justify-between items-center border-b border-white/10 pb-3">
              <span className="font-np font-bold italic text-[26px] leading-none text-white">SAVE OUTFIT</span>
              <button
                type="button"
                onClick={() => setShowSaveModal(false)}
                className="w-7 h-7 flex items-center justify-center bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="flex flex-col gap-1.5">
              <label className="font-oswald text-xs uppercase tracking-wider text-zinc-400">
                Outfit Name
              </label>
              <input
                autoFocus
                type="text"
                value={saveName}
                onChange={(e) => setSaveName(e.target.value)}
                placeholder="e.g. Summer Casual"
                className="w-full bg-black/40 border border-white/10 px-3 py-2 text-white font-oswald text-sm outline-none focus:border-[#10f6b7]"
              />
            </div>

            <div className="flex gap-2 pt-2">
              <button
                type="button"
                onClick={() => setShowSaveModal(false)}
                className="flex-1 py-2 bg-white/10 hover:bg-zinc-800 font-oswald text-xs tracking-wider uppercase text-zinc-300 transition-colors cursor-pointer"
              >
                CANCEL
              </button>
              <button
                type="submit"
                disabled={!saveName.trim()}
                className="flex-1 py-2 bg-[#10f6b7] hover:bg-[#5cf9cf] disabled:opacity-40 text-black font-np font-bold italic text-xs tracking-wider uppercase transition-colors cursor-pointer"
              >
                SAVE
              </button>
            </div>
          </form>
        </div>
      )}

      {showImportModal && (
        <div className="fixed right-12 top-28 z-[120] pointer-events-auto select-none">
          <form
            onSubmit={handleImportOutfit}
            className="w-[380px] bg-[#0c0c0c]/90 border-t-[3px] border-t-[#10f6b7] border border-white/10 p-5 flex flex-col gap-4 shadow-2xl"
          >
            <div className="flex justify-between items-center border-b border-white/10 pb-3">
              <span className="font-np font-bold italic text-[26px] leading-none text-white">IMPORT OUTFIT</span>
              <button
                type="button"
                onClick={() => setShowImportModal(false)}
                className="w-7 h-7 flex items-center justify-center bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="flex flex-col gap-1.5">
              <label className="font-oswald text-xs uppercase tracking-wider text-zinc-400">
                New Outfit Name
              </label>
              <input
                type="text"
                value={importName}
                onChange={(e) => setImportName(e.target.value)}
                placeholder="e.g. Imported Suit"
                className="w-full bg-black/40 border border-white/10 px-3 py-2 text-white font-oswald text-sm outline-none focus:border-[#10f6b7]"
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <label className="font-oswald text-xs uppercase tracking-wider text-zinc-400">
                Share Code
              </label>
              <input
                type="text"
                value={importCode}
                onChange={(e) => setImportCode(e.target.value)}
                placeholder="e.g. 7X3K9M2P10"
                className="w-full bg-black/40 border border-white/10 px-3 py-2 text-white font-oswald text-sm outline-none focus:border-[#10f6b7] uppercase tracking-widest"
              />
            </div>

            {importError && (
              <span className="font-oswald text-xs text-red-400 tracking-wider">
                {importError}
              </span>
            )}

            <div className="flex gap-2 pt-2">
              <button
                type="button"
                onClick={() => setShowImportModal(false)}
                className="flex-1 py-2 bg-white/10 hover:bg-zinc-800 font-oswald text-xs tracking-wider uppercase text-zinc-300 transition-colors cursor-pointer"
              >
                CANCEL
              </button>
              <button
                type="submit"
                disabled={!importName.trim() || !importCode.trim()}
                className="flex-1 py-2 bg-[#10f6b7] hover:bg-[#5cf9cf] disabled:opacity-40 text-black font-np font-bold italic text-xs tracking-wider uppercase transition-colors cursor-pointer"
              >
                IMPORT
              </button>
            </div>
          </form>
        </div>
      )}

      {generatedCode && (
        <div className="fixed right-12 top-28 z-[120] pointer-events-auto select-none">
          <div className="w-[380px] bg-[#0c0c0c]/90 border-t-[3px] border-t-[#10f6b7] border border-white/10 p-5 flex flex-col gap-4 shadow-2xl">
            <div className="flex justify-between items-center border-b border-white/10 pb-3">
              <span className="font-np font-bold italic text-[26px] leading-none text-white">SHARE OUTFIT CODE</span>
              <button
                type="button"
                onClick={() => setGeneratedCode(null)}
                className="w-7 h-7 flex items-center justify-center bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="flex flex-col gap-2 bg-black/40 p-4 border border-white/5 items-center">
              <span className="font-oswald text-xs text-zinc-400 uppercase tracking-wider">
                Share this code with your friends:
              </span>
              <span className="font-np font-bold italic text-2xl text-[#10f6b7] tracking-widest selection:bg-white selection:text-black">
                {generatedCode.code}
              </span>
            </div>

            <button
              onClick={handleCopyCode}
              className="w-full py-2.5 bg-[#10f6b7] hover:bg-[#5cf9cf] text-black font-np font-bold italic text-sm tracking-wider uppercase flex items-center justify-center gap-2 cursor-pointer shadow transition-colors"
            >
              {copied ? <Check className="w-4 h-4 stroke-[3]" /> : <Copy className="w-4 h-4" />}
              {copied ? 'COPIED TO CLIPBOARD!' : 'COPY CODE'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
