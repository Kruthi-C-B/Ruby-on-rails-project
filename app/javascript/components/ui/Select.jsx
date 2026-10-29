import React from "react";

export default function Select({ id, label, hint, error, "aria-describedby": externalDescribedBy, className = "", children, ...props }) {
  const generatedId = React.useId();
  const fieldId = id || generatedId;
  const hintId = hint ? `${fieldId}-hint` : undefined;
  const errorId = error ? `${fieldId}-error` : undefined;
  const describedBy = [externalDescribedBy, hintId, errorId].filter(Boolean).join(" ") || undefined;

  return (
    <div className="lf-field">
      {label && <label className="lf-field__label" htmlFor={fieldId}>{label}</label>}
      <select
        id={fieldId}
        className={`lf-input lf-select${error ? " lf-input--invalid" : ""}${className ? ` ${className}` : ""}`}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        {...props}
      >
        {children}
      </select>
      {hint && <div className="lf-field__hint" id={hintId}>{hint}</div>}
      {error && <div className="lf-field__error" id={errorId}>{error}</div>}
    </div>
  );
}
