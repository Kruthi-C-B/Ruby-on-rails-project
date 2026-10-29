import React from "react";

export default function Spinner({ label = "Loading", className = "" }) {
  return (
    <div className={`lf-spinner-wrap${className ? ` ${className}` : ""}`} role="status">
      <span className="lf-spinner" aria-hidden="true" />
      <span>{label}</span>
    </div>
  );
}
