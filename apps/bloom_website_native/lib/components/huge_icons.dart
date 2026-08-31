import 'package:bloom_js_native/bloom_js_native.dart';

String _hugeIconSvg(String name, {String className = 'w-4 h-4'}) {
  final paths = <String, String>{
    'star':
        '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" fill="currentColor" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'terminal':
        '<path d="M4 17L10 11L4 5M12 19H20" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'zap':
        '<path d="M13 2L3 14H12L11 22L21 10H12L13 2Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'layers':
        '<path d="M12 2L2 7L12 12L22 7L12 2Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M2 17L12 22L22 17" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M2 12L12 17L22 12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'server':
        '<rect x="2" y="2" width="20" height="8" rx="2" stroke="currentColor" stroke-width="1.5"/><rect x="2" y="14" width="20" height="8" rx="2" stroke="currentColor" stroke-width="1.5"/><line x1="6" y1="6" x2="6.01" y2="6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><line x1="6" y1="18" x2="6.01" y2="18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    'rocket':
        '<path d="M4.5 16.5C3.5 18.5 2 22 2 22C2 22 5.5 20.5 7.5 19.5M14.5 9.5L12 7L7 12L9.5 14.5M14.5 9.5C16.5 7.5 19.5 4 21 2C20 4.5 16.5 7.5 14.5 9.5ZM14.5 9.5L19.5 14.5C20.5 15.5 21.5 17 22 22C17 21.5 15.5 20.5 14.5 19.5L9.5 14.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'check':
        '<path d="M20 6L9 17L4 12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'copy':
        '<rect x="9" y="9" width="13" height="13" rx="2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M5 15H4C2.89543 15 2 14.1046 2 13V4C2 2.89543 2.89543 2 4 2H13C14.1046 2 15 2.89543 15 4V5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'search':
        '<circle cx="11" cy="11" r="8" stroke="currentColor" stroke-width="1.5"/><line x1="21" y1="21" x2="16.65" y2="16.65" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    'code':
        '<polyline points="16 18 22 12 16 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><polyline points="8 6 2 12 8 18" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'chevron-right':
        '<polyline points="9 18 15 12 9 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'chevron-down':
        '<polyline points="6 9 12 15 18 9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'arrow-right':
        '<line x1="5" y1="12" x2="19" y2="12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><polyline points="12 5 19 12 12 19" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'arrow-up':
        '<line x1="12" y1="19" x2="12" y2="5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><polyline points="5 12 12 5 19 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'arrow-up-right':
        '<line x1="7" y1="17" x2="17" y2="7" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><polyline points="7 7 17 7 17 17" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'cpu':
        '<rect x="4" y="4" width="16" height="16" rx="2" stroke="currentColor" stroke-width="1.5"/><rect x="9" y="9" width="6" height="6" stroke="currentColor" stroke-width="1.5"/><path d="M9 1V4M15 1V4M9 20V23M15 20V23M20 9H23M20 15H23M1 9H4M1 15H4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    'globe':
        '<circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="1.5"/><path d="M2 12H22M12 2A15.3 15.3 0 0 1 16 12A15.3 15.3 0 0 1 12 22A15.3 15.3 0 0 1 8 12A15.3 15.3 0 0 1 12 2Z" stroke="currentColor" stroke-width="1.5"/>',
    'shield':
        '<path d="M12 22S20 18 20 12V5L12 2L4 5V12C4 18 12 22 12 22Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'activity':
        '<polyline points="22 12 18 12 15 21 9 3 6 12 2 12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'cloud':
        '<path d="M18 10H16.74A8 8 0 1 0 6 16.29H18A4 4 0 0 0 18 10Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'database':
        '<ellipse cx="12" cy="5" rx="9" ry="3" stroke="currentColor" stroke-width="1.5"/><path d="M21 12C21 13.66 16.97 15 12 15S3 13.66 3 12M21 5V19C21 20.66 16.97 22 12 22S3 20.66 3 19V5" stroke="currentColor" stroke-width="1.5"/>',
    'command':
        '<path d="M18 3A3 3 0 0 0 15 6V18A3 3 0 1 0 18 15H6A3 3 0 1 0 9 18V6A3 3 0 1 0 6 9H18A3 3 0 0 0 18 3Z" stroke="currentColor" stroke-width="1.5"/>',
    'sparkles':
        '<path d="M12 2L14.4 7.6L20 10L14.4 12.4L12 18L9.6 12.4L4 10L9.6 7.6L12 2Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M19 16L20.2 18.8L23 20L20.2 21.2L19 24L17.8 21.2L15 20L17.8 18.8L19 16Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'sun':
        '<circle cx="12" cy="12" r="4" stroke="currentColor" stroke-width="1.5"/><path d="M12 2V4M12 20V22M4 12H2M22 12H20M19.07 4.93L17.66 6.34M6.34 17.66L4.93 19.07M19.07 19.07L17.66 17.66M6.34 6.34L4.93 4.93" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    'moon':
        '<path d="M12 3A9 9 0 1 0 21 12A7 7 0 0 1 12 3Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'check-circle':
        '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><polyline points="22 4 12 14.01 9 11.01" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'info':
        '<circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="1.5"/><line x1="12" y1="16" x2="12" y2="12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><line x1="12" y1="8" x2="12.01" y2="8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    'x':
        '<line x1="18" y1="6" x2="6" y2="18" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="6" y1="6" x2="18" y2="18" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'menu':
        '<line x1="4" y1="6" x2="20" y2="6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><line x1="4" y1="12" x2="20" y2="12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><line x1="4" y1="18" x2="20" y2="18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    'github':
        '<path d="M9 19C4 20.5 4 16.5 2 16M16 22V18.13C16.07 17.4 15.82 16.68 15.32 16.14C18.25 15.81 21.33 14.68 21.33 9.61C21.33 8.24 20.85 7.12 20.06 6.24C20.19 5.92 20.62 4.64 19.94 2.92C19.94 2.92 18.89 2.58 16.5 4.2C15.5 3.92 14.46 3.79 13.42 3.79C12.38 3.79 11.34 3.92 10.34 4.2C7.95 2.58 6.9 2.92 6.9 2.92C6.22 4.64 6.65 5.92 6.78 6.24C5.99 7.12 5.51 8.24 5.51 9.61C5.51 14.68 8.59 15.81 11.52 16.14C11.02 16.68 10.77 17.4 10.84 18.13V22" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'message-square':
        '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'users':
        '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><circle cx="9" cy="7" r="4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M22 21v-2a4 4 0 0 0-3-3.87" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M16 3.13a4 4 0 0 1 0 7.75" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'git-pull-request':
        '<circle cx="18" cy="18" r="3" stroke="currentColor" stroke-width="1.5"/><circle cx="6" cy="6" r="3" stroke="currentColor" stroke-width="1.5"/><path d="M13 6h3a2 2 0 0 1 2 2v7" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="6" y1="9" x2="6" y2="21" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'heart':
        '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'folder':
        '<path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.93a2 2 0 0 1-1.66-.9l-.82-1.2A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13c0 1.1.9 2 2 2Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'folder-tree':
        '<path d="M20 10a1 1 0 0 0 1-1V6a1 1 0 0 0-1-1h-2.5a1 1 0 0 1-.8-.4l-.9-1.2A1 1 0 0 0 15 3h-2a1 1 0 0 0-1 1v5a1 1 0 0 0 1 1Z" stroke="currentColor" stroke-width="1.5"/><path d="M20 21a1 1 0 0 0 1-1v-3a1 1 0 0 0-1-1h-2.9a1 1 0 0 1-.88-.55l-.42-.85a1 1 0 0 0-.92-.6H13a1 1 0 0 0-1 1v5a1 1 0 0 0 1 1Z" stroke="currentColor" stroke-width="1.5"/><path d="M3 3v18h4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M7 8h5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'refresh':
        '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M21 3v5h-5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M8 16H3v5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'send':
        '<path d="M22 2 11 13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="m22 2-7 20-4-9-9-4 20-7z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'sliders':
        '<line x1="4" y1="21" x2="4" y2="14" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="4" y1="10" x2="4" y2="3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="12" y1="21" x2="12" y2="12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="12" y1="8" x2="12" y2="3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="20" y1="21" x2="20" y2="16" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="20" y1="12" x2="20" y2="3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="1" y1="14" x2="7" y2="14" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="9" y1="8" x2="15" y2="8" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="17" y1="16" x2="23" y2="16" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'play':
        '<polygon points="5 3 19 12 5 21 5 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'lock':
        '<rect x="3" y="11" width="18" height="11" rx="2" ry="2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M7 11V7a5 5 0 0 1 10 0v4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'clock':
        '<circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="1.5"/><polyline points="12 6 12 12 16 14" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'git-branch':
        '<line x1="6" y1="3" x2="6" y2="15" stroke="currentColor" stroke-width="1.5"/><circle cx="18" cy="6" r="3" stroke="currentColor" stroke-width="1.5"/><circle cx="6" cy="18" r="3" stroke="currentColor" stroke-width="1.5"/><path d="M18 9a9 9 0 0 1-9 9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'wifi':
        '<path d="M12 20h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M8.5 16.429a5 5 0 0 1 7 0" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M5 12.859a10 10 0 0 1 14 0" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M1.5 9.288a15 15 0 0 1 21 0" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
    'qr-code':
        '<rect width="5" height="5" x="3" y="3" rx="1" stroke="currentColor" stroke-width="1.5"/><rect width="5" height="5" x="16" y="3" rx="1" stroke="currentColor" stroke-width="1.5"/><rect width="5" height="5" x="3" y="16" rx="1" stroke="currentColor" stroke-width="1.5"/><path d="M21 16h-3a2 2 0 0 0-2 2v3" stroke="currentColor" stroke-width="1.5"/><path d="M21 21v.01" stroke="currentColor" stroke-width="2"/><path d="M12 7v3a2 2 0 0 1-2 2H7" stroke="currentColor" stroke-width="1.5"/><path d="M3 12h.01" stroke="currentColor" stroke-width="2"/><path d="M12 3h.01" stroke="currentColor" stroke-width="2"/><path d="M12 16v.01" stroke="currentColor" stroke-width="2"/><path d="M16 12h1" stroke="currentColor" stroke-width="1.5"/><path d="M21 12v.01" stroke="currentColor" stroke-width="2"/><path d="M12 21v-1" stroke="currentColor" stroke-width="1.5"/>',
    'smartphone':
        '<rect width="14" height="20" x="5" y="2" rx="2" ry="2" stroke="currentColor" stroke-width="1.5"/><path d="M12 18h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
    'alert-circle':
        '<circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="1.5"/><line x1="12" y1="8" x2="12" y2="12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><line x1="12" y1="16" x2="12.01" y2="16" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    'alert-triangle':
        '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="12" y1="9" x2="12" y2="13" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><line x1="12" y1="17" x2="12.01" y2="17" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    'help-circle':
        '<circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="1.5"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="12" y1="17" x2="12.01" y2="17" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    'download':
        '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><polyline points="7 10 12 15 17 10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="12" y1="15" x2="12" y2="3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>',
  };

  final pathData = paths[name] ?? paths['terminal']!;
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" class="$className" aria-hidden="true">$pathData</svg>';
}

BloomNode hugeIcon(String name, {String className = 'w-4 h-4'}) =>
    Raw(_hugeIconSvg(name, className: className));
