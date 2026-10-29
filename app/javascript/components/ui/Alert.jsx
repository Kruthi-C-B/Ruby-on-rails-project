import React from "react";

export default function Alert({ variant = "error", title, children, className = "", ...props }) {
  return (
    <div
      className={`lf-alert lf-alert--${variant}${className ? ` ${className}` : ""}`}
      role={variant === "error" ? "alert" : "status"}
      {...props}
    >
      {title && <strong className="lf-alert__title">{title}</strong>}
      {children}
    </div>
  );
}
