import React from "react";

export default function PageHeader({ title, description, action, children, className = "" }) {
  return (
    <header className={`lf-page-header${className ? ` ${className}` : ""}`}>
      <div>
        <h1 className="lf-page-header__title">{title}</h1>
        {description && <p className="lf-page-header__description">{description}</p>}
        {children}
      </div>
      {action && <div className="lf-page-header__action">{action}</div>}
    </header>
  );
}
