import * as React from "react";

export function FlutterIcon({ className = "size-4" }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-label="Flutter"
    >
      <path d="M14.314 0L2.3 12 6 15.7 21.714 0h-7.4z" fill="#02569B" />
      <path d="M14.314 24h7.4L14.3 16.586 10.6 20.286 14.314 24z" fill="#0175C2" />
      <path d="M6.886 14.814l3.714-3.714 3.714 3.714-3.714 3.714-3.714-3.714z" fill="#02569B" />
      <path d="M14.314 8.886l5.486 5.486-3.714 3.714-5.486-5.486 3.714-3.714z" fill="#29B6F6" />
    </svg>
  );
}
