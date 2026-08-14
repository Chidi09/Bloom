/**
 * Zero-dependency, collision-free token-based Dart syntax highlighter
 */
export function highlightDart(code: string): string {
  // Token pattern matching in order of precedence
  const tokenRegex = /(\/\/[^\n]*|\/\*[\s\S]*?\*\/)|('(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")|(@\w+)|(\b(?:import|package|class|extends|implements|with|mixin|abstract|enum|void|return|final|late|const|var|static|super|this|new|await|async|yield|if|else|switch|case|default|break|continue|for|while|do|in|is|as|try|catch|finally|throw|rethrow|get|set|typedef|true|false|null)\b)|(\b[A-Z][a-zA-Z0-9_$]*\b)|(\b(?:inject|createSignal|createComputed|createEffect|createQuery|createMutation|Watch|provideSingleton|provideLazySingleton|provideFactory|runApp|main|setState|toStringAsFixed|setData|invalidateQueries|onInit|onDispose|onBoot)\b)|(\b\d+(?:\.\d+)?\b)/g;

  let lastIndex = 0;
  let result = '';
  let match: RegExpExecArray | null;

  while ((match = tokenRegex.exec(code)) !== null) {
    // Append plain text before this match
    if (match.index > lastIndex) {
      result += escapeHtml(code.slice(lastIndex, match.index));
    }

    const [fullMatch, comment, stringLit, annotation, keyword, typeName, frameworkMethod, numberLit] = match;

    if (comment) {
      result += `<span class="text-slate-500 italic">${escapeHtml(comment)}</span>`;
    } else if (stringLit) {
      result += `<span class="text-emerald-400 font-medium">${escapeHtml(stringLit)}</span>`;
    } else if (annotation) {
      result += `<span class="text-yellow-400 font-semibold">${escapeHtml(annotation)}</span>`;
    } else if (keyword) {
      result += `<span class="text-pink-400 font-bold">${escapeHtml(keyword)}</span>`;
    } else if (typeName) {
      result += `<span class="text-cyan-400 font-semibold">${escapeHtml(typeName)}</span>`;
    } else if (frameworkMethod) {
      result += `<span class="text-amber-300 font-medium">${escapeHtml(frameworkMethod)}</span>`;
    } else if (numberLit) {
      result += `<span class="text-orange-400">${escapeHtml(numberLit)}</span>`;
    }

    lastIndex = tokenRegex.lastIndex;
  }

  if (lastIndex < code.length) {
    result += escapeHtml(code.slice(lastIndex));
  }

  return result;
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
