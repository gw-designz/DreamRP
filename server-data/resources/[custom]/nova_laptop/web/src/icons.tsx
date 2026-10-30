import {
  ThumbsUp, PenTool, BookOpen, Newspaper, Camera, Trash2, House, UsersRound, Users, Wallet, Bell, LogOut, LogIn, Search,
  Pin, Globe, Lock, Check, X, Minus, Plus, ChevronLeft, ChevronRight, ChevronDown, RefreshCw, Send, Landmark,
  Crown, Banknote, Printer, Image, Smartphone, MemoryStick, Eraser, Paperclip, Maximize, ZoomIn, ZoomOut, ArrowLeft,
  Undo2, CircleCheck, CircleX, Clock3, Info, Power, Wifi, Volume2, VolumeX, BatteryFull, Monitor, Settings, Moon,
  Sun, AppWindow, Drumstick, Crosshair, CupSoda, TrendingUp, Building2, DoorOpen, Megaphone, ReceiptText, FileText,
  GripVertical, Pencil, Loader, Copy, FileDown, Hand
} from 'lucide-react';
const icons = { portal: ThumbsUp, writer: PenTool, magazine: BookOpen, newsstand: Newspaper, camera: Camera, trash: Trash2,
  home: House, friends: UsersRound, groups: Users, wallet: Wallet, bell: Bell, logout: LogOut, login: LogIn, search: Search,
  pin: Pin, globe: Globe, lock: Lock, check: Check, close: X, minimize: Minus, plus: Plus, maximize: Plus, left: ChevronLeft,
  right: ChevronRight, down: ChevronDown, refresh: RefreshCw, send: Send, bank: Landmark, crown: Crown, pay: Banknote,
  printer: Printer, image: Image, phone: Smartphone, card: MemoryStick, eraser: Eraser, clip: Paperclip, expand: Maximize,
  zoomin: ZoomIn, zoomout: ZoomOut, back: ArrowLeft, restore: Undo2, approve: CircleCheck, reject: CircleX, clock: Clock3,
  info: Info, power: Power, wifi: Wifi, volume: Volume2, muted: VolumeX, battery: BatteryFull, monitor: Monitor,
  settings: Settings, moon: Moon, sun: Sun, app: AppWindow, chicken: Drumstick, gun: Crosshair, soda: CupSoda,
  trend: TrendingUp, building: Building2, door: DoorOpen, megaphone: Megaphone, receipt: ReceiptText, article: FileText,
  grip: GripVertical, edit: Pencil, spinner: Loader, copy: Copy, filedown: FileDown, hand: Hand };
export function Icon({ name, size = 18, className = '', stroke = 1.7 }: { name: string; size?: number; className?: string; stroke?: number }) {
  const Component = icons[name as keyof typeof icons] || AppWindow;
  return <Component size={size} strokeWidth={stroke} className={className} aria-hidden="true" />;
}
export function AppIcon({ icon, color, size = 'normal' }: { icon: string; color: string; size?: string }) {
  return <span className={`app-icon ${size}`} style={{ '--icon-color': color } as React.CSSProperties}><Icon name={icon} size={size === 'small' ? 17 : size === 'large' ? 30 : 25} /></span>;
}
export function NovaMark() { return <span className="nova-mark" aria-hidden="true"><i /><i /><i /><i /></span>; }
