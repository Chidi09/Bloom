import { create } from "zustand";

type UiState = {
  sidebarCollapsed: boolean;
  commandPaletteOpen: boolean;
  planUpgradeDialogOpen: boolean;
  toggleSidebar: () => void;
  setCommandPaletteOpen: (open: boolean) => void;
  setPlanUpgradeDialogOpen: (open: boolean) => void;
};

export const useUiStore = create<UiState>((set) => ({
  sidebarCollapsed: false,
  commandPaletteOpen: false,
  planUpgradeDialogOpen: false,
  toggleSidebar: () =>
    set((state) => ({ sidebarCollapsed: !state.sidebarCollapsed })),
  setCommandPaletteOpen: (commandPaletteOpen) => set({ commandPaletteOpen }),
  setPlanUpgradeDialogOpen: (planUpgradeDialogOpen) =>
    set({ planUpgradeDialogOpen }),
}));
