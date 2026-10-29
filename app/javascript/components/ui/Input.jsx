import React from "react";

export default function Input({
  as: Component = "input",
  id: providedId,
  label,
  hint,
  error,
  "aria-describedby": externalDescribedBy,
  className = "",
  ...props
}) {
  const generatedId = React.useId();
  const id = providedId || generatedId;
  const hintId = hint ? `${id}-hint` : undefined;
  const errorId = error ? `${id}-error` : undefined;
  const describedBy = [externalDescribedBy, hintId, errorId].filter(Boolean).join(" ") || undefined;

  return (
    <div className="lf-field">
      {label && <label className="lf-field__label" htmlFor={id}>{label}</label>}
      <Component
        id={id}
        className={`lf-input${error ? " lf-input--invalid" : ""}${className ? ` ${className}` : ""}`}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        {...props}
      />
      {hint && <div className="lf-field__hint" id={hintId}>{hint}</div>}
      {error && <div className="lf-field__error" id={errorId}>{error}</div>}
    </div>
  );
}
