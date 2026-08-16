// Ground truth: cloud-cloud-backend src/apps/organizations/permissions.rs (cloud-dashboard-frontend.md §21.5).
// Ordinal values matter — compare with >=, never alphabetize or index into an array by name.
export const OrganizationRole = {
  Viewer: 1,
  Developer: 2,
  ReleaseManager: 3,
  Admin: 4,
  Owner: 5,
} as const;

export type OrganizationRoleName = keyof typeof OrganizationRole;

/** True if `role` meets or exceeds `minimum`. Use to hard-hide actions per §21.5/§22.7 — never disable. */
export function hasRole(
  role: OrganizationRoleName,
  minimum: OrganizationRoleName,
): boolean {
  return OrganizationRole[role] >= OrganizationRole[minimum];
}
