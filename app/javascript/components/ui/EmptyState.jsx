import React from "react";

export default function EmptyState({ title, children, action, className = "" }) {
  return (
    <div className={`lf-empty-state${className ? ` ${className}` : ""}`} role="status">
      {title && <h2 className="lf-empty-state__title">{title}</h2>}
      {children && <p className="lf-empty-state__description">{children}</p>}
      {action && <div className="lf-empty-state__action">{action}</div>}
    </div>
  );
}
