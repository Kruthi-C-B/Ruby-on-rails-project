import React from "react";

export default function Card({
  as: Component = "article",
  title,
  description,
  header,
  footer,
  image,
  variant = "default",
  padding = "default",
  onClick,
  className = "",
  children,
  ...props
}) {
  const interactiveProps = onClick
    ? {
        role: "button",
        tabIndex: 0,
        onClick,
        onKeyDown: (event) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            onClick(event);
          }
        },
      }
    : {};

  return (
    <Component
      className={`lf-card lf-card--${variant} lf-card--padding-${padding}${onClick ? " lf-card--interactive" : ""}${className ? ` ${className}` : ""}`}
      {...interactiveProps}
      {...props}
    >
      {image && <div className="lf-card__image">{image}</div>}
      {(header || title || description) && (
        <header className="lf-card__header">
          {header || (
            <>
              {title && <h2 className="lf-card__title">{title}</h2>}
              {description && <p className="lf-card__description">{description}</p>}
            </>
          )}
        </header>
      )}
      {children && <div className="lf-card__body">{children}</div>}
      {footer && <footer className="lf-card__footer">{footer}</footer>}
    </Component>
  );
}

Card.Header = function CardHeader({ children, className = "", ...props }) {
  return <header className={`lf-card__header${className ? ` ${className}` : ""}`} {...props}>{children}</header>;
};

Card.Body = function CardBody({ children, className = "", ...props }) {
  return <div className={`lf-card__body${className ? ` ${className}` : ""}`} {...props}>{children}</div>;
};

Card.Footer = function CardFooter({ children, className = "", ...props }) {
  return <footer className={`lf-card__footer${className ? ` ${className}` : ""}`} {...props}>{children}</footer>;
};
