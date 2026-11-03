import React, { useEffect, useRef, useState } from "react";

export default function SecurityLogsMicrofrontend({ securityLogsApiUrl, mfeUrl }) {
  const containerRef = useRef(null);
  const [loadError, setLoadError] = useState("");

  useEffect(() => {
    let cancelled = false;
    let mounted = false;
    let lifecycle;
    const childProps = {
      securityLogsApiUrl,
      domElement: containerRef.current,
    };

    async function mountChild() {
      if (!window.System?.import) {
        throw new Error("SystemJS is unavailable; the security logs MFE cannot be loaded.");
      }

      lifecycle = await window.System.import(mfeUrl);
      await lifecycle.bootstrap(childProps);
      if (cancelled) return;

      await lifecycle.mount(childProps);
      mounted = true;
      if (cancelled) {
        await lifecycle.unmount(childProps);
        mounted = false;
      }
    }

    mountChild().catch((error) => {
      console.error("Failed to mount the security logs microfrontend:", error);
      if (!cancelled) {
        setLoadError(error.message || "The security logs microfrontend could not be loaded.");
      }
    });

    return () => {
      cancelled = true;
      if (mounted) {
        lifecycle.unmount(childProps).catch((error) => {
          console.error("Failed to unmount the security logs microfrontend:", error);
        });
      }
    };
  }, [securityLogsApiUrl, mfeUrl]);

  return (
    <section className="lf-admin-panel" aria-label="Security logs microfrontend">
      {loadError && <p role="alert">{loadError}</p>}
      <div ref={containerRef} />
    </section>
  );
}
