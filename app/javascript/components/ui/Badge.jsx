import React from "react";

const statusVariants = {
  active: "success",
  available: "success",
  completed: "success",
  ordered: "success",
  successful: "success",
  success: "success",
  inactive: "neutral",
  pending: "warning",
  low: "warning",
  "out of stock": "danger",
  failed: "danger",
  error: "danger",
};

export default function Badge({ variant, children, className = "", ...props }) {
  const resolvedVariant = variant || statusVariants[String(children).toLowerCase()] || "neutral";

  return (
    <span className={`lf-badge lf-badge--${resolvedVariant}${className ? ` ${className}` : ""}`} {...props}>
      {children}
    </span>
  );
}
