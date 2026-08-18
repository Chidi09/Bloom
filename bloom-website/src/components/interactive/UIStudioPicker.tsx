import { useState } from 'preact/hooks';
import {
  Sliders,
  Bell,
  Check,
  Calendar,
  ArrowUpRight,
  Shield,
  User,
  Search,
  Plus,
  Trash2,
  RefreshCw,
  ChevronDown,
  ChevronRight,
  Heart,
  Share2,
  AlertCircle,
  CheckCircle2,
  Lock,
  CreditCard,
  Wifi,
  Battery,
  Home,
  Settings,
  MessageSquare,
  Sparkles,
  Zap,
  X,
  Smartphone,
  Info,
  HelpCircle,
  MoreHorizontal
} from 'lucide-preact';
import { showToast } from '../common/ToastSystem';
import { Button } from '../ui/button';
import { Badge } from '../ui/badge';
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '../ui/card';
import { Input } from '../ui/input';
import { Progress } from '../ui/progress';
import { Avatar, AvatarFallback, AvatarImage } from '../ui/avatar';
import { Alert, AlertTitle, AlertDescription } from '../ui/alert';
import { Sheet } from '../ui/sheet';
import { DatePicker } from '../ui/date-picker';
import { SegmentedControl } from '../ui/segmented-control';

export function UIStudioPicker() {
  const [accentColor, setAccentColor] = useState<'purple' | 'pink' | 'blue' | 'emerald' | 'amber' | 'rose'>('purple');
  const [radius, setRadius] = useState(12);
  const [activeCategory, setActiveCategory] = useState<'all' | 'buttons' | 'inputs' | 'cards' | 'nav'>('all');
  
  // Interactive state mocks
  const [sheetOpen, setSheetOpen] = useState(false);
  const [selectedDate, setSelectedDate] = useState(14);
  const [switchState1, setSwitchState1] = useState(true);
  const [switchState2, setSwitchState2] = useState(false);
  const [checkbox1, setCheckbox1] = useState(true);
  const [checkbox2, setCheckbox2] = useState(false);
  const [radioVal, setRadioVal] = useState('opt1');
  const [accordionOpen, setAccordionOpen] = useState(true);
  const [activeBottomNav, setActiveBottomNav] = useState('home');
  const [progressVal, setProgressVal] = useState(72);
  const [textareaVal, setTextareaVal] = useState('Bloom brings opinionated design tokens to Flutter.');

  const colorsMap = {
    purple: { bg: 'bg-purple-600', text: 'text-purple-600 dark:text-purple-400', border: 'border-purple-500', softBg: 'bg-purple-100 dark:bg-purple-500/20 text-purple-700 dark:text-purple-300 border-purple-200 dark:border-purple-500/30', hex: '#8B5CF6' },
    pink: { bg: 'bg-pink-600', text: 'text-pink-600 dark:text-pink-400', border: 'border-pink-500', softBg: 'bg-pink-100 dark:bg-pink-500/20 text-pink-700 dark:text-pink-300 border-pink-200 dark:border-pink-500/30', hex: '#FF4B8B' },
    blue: { bg: 'bg-blue-600', text: 'text-blue-600 dark:text-blue-400', border: 'border-blue-500', softBg: 'bg-blue-100 dark:bg-blue-500/20 text-blue-700 dark:text-blue-300 border-blue-200 dark:border-blue-500/30', hex: '#3B82F6' },
    emerald: { bg: 'bg-emerald-600', text: 'text-emerald-600 dark:text-emerald-400', border: 'border-emerald-500', softBg: 'bg-emerald-100 dark:bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-500/30', hex: '#10B981' },
    amber: { bg: 'bg-amber-600', text: 'text-amber-600 dark:text-amber-400', border: 'border-amber-500', softBg: 'bg-amber-100 dark:bg-amber-500/20 text-amber-700 dark:text-amber-300 border-amber-200 dark:border-amber-500/30', hex: '#F59E0B' },
    rose: { bg: 'bg-rose-600', text: 'text-rose-600 dark:text-rose-400', border: 'border-rose-500', softBg: 'bg-rose-100 dark:bg-rose-500/20 text-rose-700 dark:text-rose-300 border-rose-200 dark:border-rose-500/30', hex: '#F43F5E' },
  };

  const activeColor = colorsMap[accentColor];

  return (
    <div className="glass-panel rounded-[2.5rem] overflow-hidden shadow-2xl grid grid-cols-1 lg:grid-cols-12 relative border border-slate-200/60 dark:border-zinc-800 bg-white dark:bg-black group">
      {/* Token Configurator Sidebar - compact strip on mobile, full sidebar on lg */}
      <div className="lg:col-span-3 bg-slate-50/60 dark:bg-zinc-950/90 border-b lg:border-b-0 lg:border-r border-slate-200/60 dark:border-zinc-800 relative z-10">
        {/* Mobile: horizontal compact strip */}
        <div className="flex flex-col lg:hidden p-4 gap-4">
          <div className="flex items-center justify-between gap-4 flex-wrap">
            <div className="flex items-center gap-2">
              <span className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase">Accent</span>
              <div className="flex gap-2">
                {(['purple', 'pink', 'blue', 'emerald', 'amber', 'rose'] as const).map((c) => (
                  <button
                    key={c}
                    onClick={() => setAccentColor(c)}
                    aria-label={`Select ${c} accent`}
                    className={`w-6 h-6 rounded-full ${colorsMap[c].bg} transition-all ${
                      accentColor === c ? 'ring-2 ring-offset-1 ring-offset-white dark:ring-offset-black ring-slate-400 scale-110' : 'opacity-70 hover:opacity-100'
                    }`}
                  />
                ))}
              </div>
            </div>
            <div className="flex items-center gap-2 flex-1 min-w-[120px]">
              <span className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase shrink-0">r={radius}px</span>
              <input
                type="range" min="0" max="24" value={radius}
                onInput={(e) => setRadius(Number((e.target as HTMLInputElement).value))}
                className="w-full h-1.5 bg-slate-200 dark:bg-zinc-800 rounded-lg appearance-none cursor-pointer"
                style={{ accentColor: activeColor.hex }}
              />
            </div>
          </div>
          <div className="flex gap-1.5 flex-wrap font-mono text-[11px]">
            {[
              { id: 'all', label: 'All' },
              { id: 'buttons', label: 'Buttons' },
              { id: 'inputs', label: 'Inputs' },
              { id: 'cards', label: 'Cards' },
            ].map((cat) => (
              <button
                key={cat.id}
                onClick={() => setActiveCategory(cat.id as any)}
                className={`px-2.5 py-1 rounded-lg transition-all ${
                  activeCategory === cat.id
                    ? `${activeColor.bg} text-white font-bold`
                    : 'bg-slate-200/60 dark:bg-zinc-900 text-slate-600 dark:text-slate-400'
                }`}
              >
                {cat.label}
              </button>
            ))}
          </div>
        </div>

        {/* Desktop: full vertical sidebar */}
        <div className="hidden lg:flex flex-col justify-between p-8 space-y-8 h-full">
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-xs font-bold text-slate-900 dark:text-white uppercase tracking-widest font-mono flex items-center gap-2">
                <Sliders className={`w-4 h-4 ${activeColor.text}`} strokeWidth={2} />
                shadcn / Mobile UI
              </h3>
              <Badge variant="outline" style={{ borderRadius: `${radius}px` }}>v2.5</Badge>
            </div>

            <div className="space-y-3">
              <label className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase">Accent Token</label>
              <div className="flex flex-wrap gap-2.5">
                {(['purple', 'pink', 'blue', 'emerald', 'amber', 'rose'] as const).map((c) => (
                  <button
                    key={c}
                    onClick={() => setAccentColor(c)}
                    aria-label={`Select ${c} accent`}
                    className={`w-7 h-7 rounded-full ${colorsMap[c].bg} transition-all ${
                      accentColor === c ? 'ring-2 ring-offset-2 ring-offset-white dark:ring-offset-black ring-slate-400 dark:ring-zinc-600 scale-110' : 'opacity-80 hover:opacity-100 hover:scale-105'
                    }`}
                  />
                ))}
              </div>
            </div>

            <div className="space-y-3">
              <div className="flex justify-between items-center text-xs font-mono text-slate-500 dark:text-slate-400 uppercase">
                <label className="font-bold">Border Radius</label>
                <span className="font-bold text-slate-900 dark:text-white font-mono">{(radius / 16).toFixed(2)}rem ({radius}px)</span>
              </div>
              <input
                type="range" min="0" max="24" value={radius}
                onInput={(e) => setRadius(Number((e.target as HTMLInputElement).value))}
                className="w-full h-1.5 bg-slate-200 dark:bg-zinc-800 rounded-lg appearance-none cursor-pointer"
                style={{ accentColor: activeColor.hex }}
              />
            </div>

            <div className="space-y-2 pt-2">
              <label className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase block">Filter Components</label>
              <div className="flex flex-wrap gap-1.5 font-mono text-[11px]">
                {[
                  { id: 'all', label: 'All' },
                  { id: 'buttons', label: 'Buttons & Badges' },
                  { id: 'inputs', label: 'Inputs & Forms' },
                  { id: 'cards', label: 'Cards & Avatars' },
                  { id: 'nav', label: 'Nav & Feedback' },
                ].map((cat) => (
                  <button
                    key={cat.id}
                    onClick={() => setActiveCategory(cat.id as any)}
                    className={`px-2.5 py-1 rounded-lg transition-all ${
                      activeCategory === cat.id
                        ? `${activeColor.bg} text-white font-bold`
                        : 'bg-slate-200/60 dark:bg-zinc-900 text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white'
                    }`}
                  >
                    {cat.label}
                  </button>
                ))}
              </div>
            </div>
          </div>

          <Button
            onClick={() => showToast('Token System Live', `Accent: ${accentColor.toUpperCase()} | Radius: ${radius}px`, accentColor === 'emerald' ? 'emerald' : accentColor === 'blue' ? 'blue' : 'purple')}
            style={{ borderRadius: `${radius}px` }}
            className="w-full"
          >
            <Bell className="w-4 h-4 mr-2" strokeWidth={2} />
            Trigger Toast Event
          </Button>
        </div>
      </div>

      {/* Mobile Component Gallery Canvas (9 cols) */}
      <div className="lg:col-span-9 p-6 sm:p-8 space-y-10">
        
        {/* CATEGORY 1: BUTTONS & BADGES */}
        {(activeCategory === 'all' || activeCategory === 'buttons') && (
          <div className="space-y-4">
            <h4 className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase tracking-widest flex items-center justify-between border-b border-slate-200 dark:border-zinc-800 pb-2">
              <span className="flex items-center gap-2">
                <Zap className={`w-3.5 h-3.5 ${activeColor.text}`} />
                Buttons & Badges (cva primitives)
              </span>
            </h4>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {/* Button Variants */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>Button Variants</CardTitle>
                  <CardDescription>Primary, Secondary, Outline, Destructive</CardDescription>
                </CardHeader>
                <CardContent className="flex flex-wrap gap-2">
                  <Button style={{ borderRadius: `${radius}px`, backgroundColor: activeColor.hex }}>Primary</Button>
                  <Button variant="secondary" style={{ borderRadius: `${radius}px` }}>Secondary</Button>
                  <Button variant="outline" style={{ borderRadius: `${radius}px` }}>Outline</Button>
                  <Button variant="destructive" style={{ borderRadius: `${radius}px` }}><Trash2 /> Delete</Button>
                </CardContent>
              </Card>

              {/* Icon & Loading State Buttons */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>Icon & Loading Buttons</CardTitle>
                  <CardDescription>With leading icons & spinners</CardDescription>
                </CardHeader>
                <CardContent className="flex flex-wrap items-center gap-2">
                  <Button style={{ borderRadius: `${radius}px`, backgroundColor: activeColor.hex }}>
                    <Plus /> Add Item
                  </Button>
                  <Button variant="secondary" style={{ borderRadius: `${radius}px` }}>
                    <RefreshCw className="animate-spin" /> Saving...
                  </Button>
                  <Button variant="ghost" size="icon" style={{ borderRadius: `${radius}px` }}>
                    <Heart className="fill-current text-rose-500" />
                  </Button>
                </CardContent>
              </Card>

              {/* Badges Collection */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>Badge Variants</CardTitle>
                  <CardDescription>Status tags & counts</CardDescription>
                </CardHeader>
                <CardContent className="flex flex-wrap gap-2">
                  <Badge style={{ borderRadius: `${radius}px`, backgroundColor: activeColor.hex }}>Default</Badge>
                  <Badge variant="secondary" style={{ borderRadius: `${radius}px` }}>Secondary</Badge>
                  <Badge variant="outline" style={{ borderRadius: `${radius}px` }}>Outline</Badge>
                  <Badge variant="success" style={{ borderRadius: `${radius}px` }}>Success</Badge>
                  <Badge variant="destructive" style={{ borderRadius: `${radius}px` }}>Alert</Badge>
                </CardContent>
              </Card>
            </div>
          </div>
        )}

        {/* CATEGORY 2: INPUTS & FORM CONTROLS */}
        {(activeCategory === 'all' || activeCategory === 'inputs') && (
          <div className="space-y-4">
            <h4 className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase tracking-widest flex items-center justify-between border-b border-slate-200 dark:border-zinc-800 pb-2">
              <span className="flex items-center gap-2">
                <Search className={`w-3.5 h-3.5 ${activeColor.text}`} />
                Inputs, Textarea & Form Controls
              </span>
            </h4>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {/* Text & Search Inputs */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>Text & Search Inputs</CardTitle>
                  <CardDescription>Mobile input fields</CardDescription>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div className="relative">
                    <Search className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
                    <Input placeholder="Search widgets..." className="pl-9" style={{ borderRadius: `${radius}px` }} />
                  </div>
                  <Input type="email" defaultValue="developer@bloom.dev" style={{ borderRadius: `${radius}px` }} />
                </CardContent>
              </Card>

              {/* Progress & Range Slider */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>Progress & Range Slider</CardTitle>
                  <CardDescription>Live progress bar</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <div className="flex justify-between text-xs font-mono mb-1.5 font-semibold">
                      <span>OTA Bundle Upload</span>
                      <span className={activeColor.text}>{progressVal}%</span>
                    </div>
                    <Progress value={progressVal} style={{ borderRadius: `${radius}px` }} />
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="100"
                    value={progressVal}
                    onInput={(e) => setProgressVal(Number((e.target as HTMLInputElement).value))}
                    className="w-full h-1.5 bg-slate-200 dark:bg-zinc-800 rounded-lg appearance-none cursor-pointer"
                    style={{ accentColor: activeColor.hex }}
                  />
                </CardContent>
              </Card>

              {/* Checkboxes & Switches */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>Switches & Checkboxes</CardTitle>
                  <CardDescription>Binary toggle switches</CardDescription>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-semibold text-slate-700 dark:text-slate-300">Push Notifications</span>
                    <div
                      onClick={() => setSwitchState1(!switchState1)}
                      className={`w-11 h-6 rounded-full p-1 cursor-pointer transition-colors ${
                        switchState1 ? activeColor.bg : 'bg-slate-300 dark:bg-zinc-800'
                      }`}
                    >
                      <div className={`w-4 h-4 bg-white rounded-full transform transition-transform shadow ${switchState1 ? 'translate-x-5' : 'translate-x-0'}`} />
                    </div>
                  </div>

                  <label className="flex items-center gap-2 cursor-pointer text-xs font-semibold text-slate-700 dark:text-slate-300">
                    <input
                      type="checkbox"
                      checked={checkbox1}
                      onChange={() => setCheckbox1(!checkbox1)}
                      style={{ accentColor: activeColor.hex, borderRadius: `${Math.min(radius, 4)}px` }}
                    />
                    <span>Auto-update signals state</span>
                  </label>
                </CardContent>
              </Card>
            </div>
          </div>
        )}

        {/* CATEGORY 3: CARDS, AVATARS & ALERTS */}
        {(activeCategory === 'all' || activeCategory === 'cards') && (
          <div className="space-y-4">
            <h4 className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase tracking-widest flex items-center justify-between border-b border-slate-200 dark:border-zinc-800 pb-2">
              <span className="flex items-center gap-2">
                <CreditCard className={`w-3.5 h-3.5 ${activeColor.text}`} />
                Mobile Cards, Avatars & Alerts
              </span>
            </h4>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {/* Payment Wallet Card */}
              <Card className={`text-white shadow-xl ${activeColor.bg} border-0`} style={{ borderRadius: `${radius}px` }}>
                <CardHeader className="flex flex-row justify-between items-start pb-2 space-y-0">
                  <CardTitle className="text-xs font-mono font-bold opacity-80 uppercase text-white dark:text-white">Bloom Wallet</CardTitle>
                  <Zap className="w-5 h-5 opacity-90" />
                </CardHeader>
                <CardContent className="py-6">
                  <span className="text-[10px] font-mono opacity-70 block mb-1">Total Balance</span>
                  <h3 className="text-2xl font-black font-mono tracking-tight">$14,890.00</h3>
                </CardContent>
                <CardFooter className="flex justify-between items-center text-xs font-mono opacity-80 pb-6 pt-0">
                  <span>•••• 4892</span>
                  <span>10/28</span>
                </CardFooter>
              </Card>

              {/* User Avatar Card */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>User Profile & Avatar</CardTitle>
                  <CardDescription>Avatar primitive with fallback</CardDescription>
                </CardHeader>
                <CardContent className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <Avatar>
                      <AvatarImage src="https://i.pravatar.cc/100?img=12" alt="Avatar" />
                      <AvatarFallback>AR</AvatarFallback>
                    </Avatar>
                    <div>
                      <h4 className="font-bold text-xs text-slate-900 dark:text-white">Alex Rivera</h4>
                      <span className="text-[10px] font-mono text-slate-500">Mobile Lead</span>
                    </div>
                  </div>
                  <Badge variant="outline" style={{ borderRadius: `${radius}px` }}>Active</Badge>
                </CardContent>
              </Card>

              {/* Alert Callout */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>Alert Callout Primitive</CardTitle>
                  <CardDescription>System notifications</CardDescription>
                </CardHeader>
                <CardContent>
                  <Alert variant="default" style={{ borderRadius: `${radius}px` }}>
                    <CheckCircle2 className="w-4 h-4 text-emerald-500" />
                    <AlertTitle>Deployment Complete</AlertTitle>
                    <AlertDescription>Patch v2.5.1 published to 142 Edge CDN nodes.</AlertDescription>
                  </Alert>
                </CardContent>
              </Card>
            </div>
          </div>
        )}

        {/* CATEGORY 4: SHEETS, DATE PICKER & OVERLAYS */}
        {(activeCategory === 'all' || activeCategory === 'nav') && (
          <div className="space-y-4">
            <h4 className="text-xs font-mono font-bold text-slate-500 dark:text-slate-400 uppercase tracking-widest flex items-center justify-between border-b border-slate-200 dark:border-zinc-800 pb-2">
              <span className="flex items-center gap-2">
                <Smartphone className={`w-3.5 h-3.5 ${activeColor.text}`} />
                Bottom Sheets, DatePicker & Controls
              </span>
            </h4>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {/* Bottom Sheet Drawer Trigger Card */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>Bottom Sheet / Drawer</CardTitle>
                  <CardDescription>Interactive mobile modal overlay</CardDescription>
                </CardHeader>
                <CardContent className="space-y-3">
                  <p className="text-xs text-slate-500 dark:text-slate-400">
                    Triggers a native-feel mobile bottom sheet with custom radius and accent styling.
                  </p>
                  <Button
                    onClick={() => setSheetOpen(true)}
                    style={{ borderRadius: `${radius}px`, backgroundColor: activeColor.hex }}
                    className="w-full"
                  >
                    Open Bottom Sheet
                  </Button>
                </CardContent>
              </Card>

              {/* Segmented Control Card */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>Segmented Control</CardTitle>
                  <CardDescription>Mobile tab selection bar</CardDescription>
                </CardHeader>
                <CardContent className="space-y-3">
                  <SegmentedControl
                    options={[
                      { id: 'day', label: 'Day' },
                      { id: 'week', label: 'Week' },
                      { id: 'month', label: 'Month' },
                    ]}
                    accentColorHex={activeColor.hex}
                    radiusPx={radius}
                  />
                </CardContent>
              </Card>

              {/* DatePicker Card */}
              <Card style={{ borderRadius: `${radius}px` }}>
                <CardHeader>
                  <CardTitle>Mobile DatePicker</CardTitle>
                  <CardDescription>Calendar grid with day selection</CardDescription>
                </CardHeader>
                <CardContent className="flex justify-center">
                  <DatePicker
                    accentColorHex={activeColor.hex}
                    radiusPx={radius}
                    selectedDay={selectedDate}
                    onSelectDay={(d) => setSelectedDate(d)}
                  />
                </CardContent>
              </Card>
            </div>
          </div>
        )}

        {/* Interactive Sheet Overlay Component */}
        <Sheet
          isOpen={sheetOpen}
          onClose={() => setSheetOpen(false)}
          title="Bloom Flutter Architecture"
          description="Signals state and Shorebird OTA integration spec"
          accentColorHex={activeColor.hex}
          radiusPx={radius}
        >
          <div className="space-y-4 py-2 text-xs">
            <div className="p-3 bg-purple-500/10 border border-purple-500/20 rounded-xl">
              <span className="font-bold text-purple-600 dark:text-purple-400 block mb-1">⚡️ Signals State Synced</span>
              <p className="text-slate-600 dark:text-slate-300">
                Zero-boilerplate reactive binding active across all components.
              </p>
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="outline" onClick={() => setSheetOpen(false)} style={{ borderRadius: `${radius}px` }}>
                Cancel
              </Button>
              <Button
                onClick={() => {
                  setSheetOpen(false);
                  showToast('Sheet Confirmed', 'Mobile overlay state updated successfully.', 'emerald');
                }}
                style={{ borderRadius: `${radius}px`, backgroundColor: activeColor.hex }}
              >
                Confirm Action
              </Button>
            </div>
          </div>
        </Sheet>
      </div>
    </div>
  );
}
