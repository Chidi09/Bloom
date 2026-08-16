import { redirect } from "next/navigation";

// §4.2 — Root route redirects into overview dashboard
export default function Home() {
  redirect("/overview");
}
