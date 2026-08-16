import { create } from "zustand";
import { persist } from "zustand/middleware";

// Only the last-selected org id is persisted (cloud-dashboard-frontend.md §6.3) — the
// org list/detail itself always comes from TanStack Query, never cached here.
type OrganizationState = {
  currentOrganizationId: string | null;
  setCurrentOrganizationId: (id: string | null) => void;
};

export const useOrganizationStore = create<OrganizationState>()(
  persist(
    (set) => ({
      currentOrganizationId: null,
      setCurrentOrganizationId: (currentOrganizationId) =>
        set({ currentOrganizationId }),
    }),
    { name: "bloom-cloud-organization" },
  ),
);
