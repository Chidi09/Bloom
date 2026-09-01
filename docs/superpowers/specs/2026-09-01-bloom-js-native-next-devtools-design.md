# Bloom JS Native Next-Style DevTools Design

## Goal

Replace Bloom JS Native's disconnected development drawer and runtime error page
with one development surface modelled on current Next 16 DevTools. It must expose
only diagnostic information Bloom can obtain, be injected exclusively by `bloom js
dev`, and add no production runtime dependency.

## Reference behaviour

The local Next 16.3.1 distribution separates an unobtrusive, draggable indicator
from an issue-aware menu, resizable panels, and modal error detail. Its overlay is
isolated from page styles and its error state supports build, runtime, and console
diagnostics. Bloom adopts that interaction contract, not Next branding or React
implementation.

## Architecture

`BloomLiveReloadServer` remains the single development-only injection point. Its
SSE stream sends lifecycle and build-error events to an isolated `#bloom-devtools`
host with a shadow root. The injected client captures browser runtime errors,
unhandled rejections, and console warnings/errors; it normalizes them with SSE
build errors into a bounded issue store. The floating Bloom mark opens a compact
menu and resizable panel. Selecting an issue opens a modal diagnostic view.

`BloomJsDevTools` remains the pure-Dart runtime diagnostics API. The client
observes the existing development error host emitted by browser mount failures and
normalizes it into the same issue store without coupling the pure API to the CLI.

## User experience

- A 36px Bloom indicator is draggable, keyboard operable, remembers its corner,
  and shows status/issue count.
- The menu contains Overview, Issues, Console, and Reload history. It only lists
  capabilities Bloom supports today.
- The panel supports Escape dismissal, focus management, light/dark system theme,
  copy details, clear issues, reload, and visible compile/reconnect state.
- An issue opens a full-screen, accessible modal with type, message, source hint,
  stack, code-frame-like emphasis for parsed Dart locations, error pagination,
  Copy, and Dismiss. It never uses `innerHTML` for error text.
- Build errors from the compiler and runtime/console errors share one issue model.
  A successful rebuild removes stale build errors; runtime errors remain until
  cleared or a reload starts.

## Testing

Server tests assert injected markup contains the isolated host, Next-style state
surface, error/event listeners, and safe issue protocol. Browser tests verify
indicator creation, an SSE build error showing an issue count, and a DDC runtime
failure opening the diagnostic UI. VM tests cover the runtime custom event bridge
where browser compilation permits it.
