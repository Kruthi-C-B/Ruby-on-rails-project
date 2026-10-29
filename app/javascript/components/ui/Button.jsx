import React from "react";

export default function Button({
  as: Component = "button",
  variant = "primary",
  size = "medium",
  type = "button",
  loading = false,
  disabled = false,
  className = "",
  children,
  onClick,
  tabIndex,
  ...props
}) {
  const isDisabled = disabled || loading;
  const buttonProps = Component === "button" ? { type, disabled: isDisabled } : {};
  const customButtonProps = Component === "button"
    ? {}
    : {
        "aria-disabled": isDisabled || undefined,
        onClick: (event) => {
          if (isDisabled) {
            event.preventDefault();
            return;
          }
          onClick?.(event);
        },
        tabIndex: isDisabled ? -1 : tabIndex,
      };

  return (
    <Component
      className={`lf-button lf-button--${variant} lf-button--${size}${isDisabled ? " lf-button--disabled" : ""}${className ? ` ${className}` : ""}`}
      aria-busy={loading || undefined}
      {...buttonProps}
      {...customButtonProps}
      onClick={Component === "button" ? onClick : customButtonProps.onClick}
      {...props}
    >
      {loading && <span className="lf-button__spinner" aria-hidden="true" />}
      {children}
    </Component>
  );
}
