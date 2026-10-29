import React from "react";

export default function Section({ title, description, actions, children, className = "", ...props }) {
  return (
    <section className={`lf-section${className ? ` ${className}` : ""}`} {...props}>
      {(title || description || actions) && (
        <header className="lf-section__header">
          <div>
            {title && <h2 className="lf-section__title">{title}</h2>}
            {description && <p className="lf-section__description">{description}</p>}
          </div>
          {actions}
        </header>
      )}
      {children}
    </section>
  );
}
