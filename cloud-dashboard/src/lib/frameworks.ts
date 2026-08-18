// Canonical list of app frameworks Bloom Cloud understands. Adding a new
// entry here (and marking `available: true` once its build/deploy pipeline
// ships) is the extension point for future framework support.
export type FrameworkId =
  | "bloom"
  | "flutter"
  | "react_native"
  | "swift"
  | "kotlin";

export interface FrameworkMeta {
  id: FrameworkId;
  label: string;
  available: boolean;
}

export const FRAMEWORKS: Record<FrameworkId, FrameworkMeta> = {
  bloom: { id: "bloom", label: "Bloom Framework", available: true },
  flutter: { id: "flutter", label: "Flutter", available: true },
  react_native: {
    id: "react_native",
    label: "React Native",
    available: false,
  },
  swift: { id: "swift", label: "Swift", available: false },
  kotlin: { id: "kotlin", label: "Kotlin", available: false },
};

export const AVAILABLE_FRAMEWORKS = Object.values(FRAMEWORKS).filter(
  (f) => f.available,
);

export const PLANNED_FRAMEWORKS = Object.values(FRAMEWORKS).filter(
  (f) => !f.available,
);
