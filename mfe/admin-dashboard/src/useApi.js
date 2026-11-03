import { useCallback, useEffect, useState } from "react";
import { fetchGet } from "./api";

export default function useApi(url, serviceUrl, { enabled = true, initialData = null, validate } = {}) {
  const [data, setData] = useState(initialData);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [requestNumber, setRequestNumber] = useState(0);
  const reload = useCallback(() => setRequestNumber((current) => current + 1), []);

  useEffect(() => {
    if (!enabled) return undefined;

    let active = true;
    setLoading(true);
    setError("");

    fetchGet(url, serviceUrl)
      .then((result) => {
        const validResult = validate ? validate(result) : result;
        if (active) setData(validResult);
      })
      .catch((requestError) => {
        console.error(requestError);
        if (active) setError(requestError.message || `Failed to load ${url}.`);
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [enabled, requestNumber, serviceUrl, url, validate]);

  return { data, loading, error, reload };
}
