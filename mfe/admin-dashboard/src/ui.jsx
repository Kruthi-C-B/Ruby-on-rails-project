import React from "react";

export function Alert({ variant = "error", children, ...props }) {
  return <div className={`lf-alert lf-alert--${variant}`} role="alert" {...props}>{children}</div>;
}

export function Button({
  as: Component = "button",
  variant = "primary",
  size = "medium",
  type = "button",
  children,
  className = "",
  ...props
}) {
  return <Component className={`lf-button lf-button--${variant} lf-button--${size} ${className}`.trim()} type={Component === "button" ? type : undefined} {...props}>{children}</Component>;
}

export function Card({ as: Component = "article", title, children, className = "", ...props }) {
  return (
    <Component className={`lf-card ${className}`.trim()} {...props}>
      {title && <h2 className="lf-card__title">{title}</h2>}
      {children}
    </Component>
  );
}

export function EmptyState({ title, children }) {
  return <div className="lf-empty-state" role="status"><h2>{title}</h2>{children && <p>{children}</p>}</div>;
}

export function Input({ as: Component = "input", label, ...props }) {
  return <label className="lf-field">{label && <span className="lf-field__label">{label}</span>}<Component className="lf-input" {...props} /></label>;
}

export function PageContainer({ as: Component = "main", children, className = "", ...props }) {
  return <Component className={`lf-page ${className}`.trim()} {...props}>{children}</Component>;
}

export function PageHeader({ title, description }) {
  return <header className="lf-page-header"><div><h1>{title}</h1>{description && <p>{description}</p>}</div></header>;
}

export function Select({ label, children, ...props }) {
  return <label className="lf-field">{label && <span className="lf-field__label">{label}</span>}<select className="lf-input" {...props}>{children}</select></label>;
}

export function Spinner({ label = "Loading" }) {
  return <div className="lf-spinner-wrap" role="status"><span className="lf-spinner" />{label}</div>;
}
