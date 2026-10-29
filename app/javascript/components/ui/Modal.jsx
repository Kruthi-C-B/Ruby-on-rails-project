import React, { useEffect, useRef } from "react";

export default function Modal({ open, onClose, title, children, className = "" }) {
  const dialogRef = useRef(null);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  useEffect(() => {
    if (!open) return undefined;

    const previousFocus = document.activeElement;
    const dialog = dialogRef.current;
    const focusable = dialog?.querySelector("button, [href], input, select, textarea, [tabindex]:not([tabindex='-1'])");
    focusable?.focus();

    const handleKeyDown = (event) => {
      if (event.key === "Escape") onCloseRef.current?.();
      if (event.key === "Tab" && dialog) {
        const elements = dialog.querySelectorAll("button, [href], input, select, textarea, [tabindex]:not([tabindex='-1'])");
        const first = elements[0];
        const last = elements[elements.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last?.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first?.focus();
        }
      }
    };
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      previousFocus?.focus?.();
    };
  }, [open]);

  if (!open) return null;

  return (
    <div className="lf-modal-backdrop" onMouseDown={(event) => {
      if (event.target === event.currentTarget) onClose?.();
    }}>
      <section
        aria-labelledby="lf-modal-title"
        aria-modal="true"
        className={`lf-modal${className ? ` ${className}` : ""}`}
        ref={dialogRef}
        role="dialog"
      >
        <header className="lf-modal__header">
          <h2 id="lf-modal-title" className="lf-modal__title">{title}</h2>
          <button type="button" className="lf-modal__close" aria-label="Close dialog" onClick={onClose}>×</button>
        </header>
        {children}
      </section>
    </div>
  );
}
