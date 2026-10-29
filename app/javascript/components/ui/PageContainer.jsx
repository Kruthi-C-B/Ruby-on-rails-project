import React from "react";

export default function PageContainer({ as: Component = "main", size = "default", className = "", children, ...props }) {
  return (
    <Component className={`lf-page lf-page--${size}${className ? ` ${className}` : ""}`} {...props}>
      {children}
    </Component>
  );
}
