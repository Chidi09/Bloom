"use client";

import { Badge } from "@/components/ui/badge";
import {
  type AuthMethod,
  getMostUsedMethod,
  useAuthPreferenceStore,
} from "@/stores/auth-preference-store";

export function AuthMethodBadge({ method }: { method: AuthMethod }) {
  const lastUsedMethod = useAuthPreferenceStore((s) => s.lastUsedMethod);
  const mostUsedMethod = useAuthPreferenceStore(getMostUsedMethod);

  if (method === lastUsedMethod) {
    return (
      <Badge variant="secondary" className="ml-auto">
        Last used
      </Badge>
    );
  }
  if (method === mostUsedMethod) {
    return (
      <Badge variant="outline" className="ml-auto">
        Most used
      </Badge>
    );
  }
  return null;
}
