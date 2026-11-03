async function getToken() {
  const response = await fetch("/api/v1/auth/token", {
    headers: { Accept: "application/json" },
    credentials: "same-origin",
  });
  if (!response.ok) {
    throw new Error(`Authentication failed (${response.status})`);
  }
  const { token } = await response.json();
  return token;
}

export async function fetchGet(path, serviceUrl) {
  const token = await getToken();
  const response = await fetch(`${serviceUrl}${path}`, {
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
    },
  });
  if (!response.ok) {
    throw new Error(`Request failed (${response.status})`);
  }
  return response.json();
}

export async function fetchRequest(path, method, payload, serviceUrl) {
  const token = await getToken();
  const response = await fetch(`${serviceUrl}${path}`, {
    method,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: payload === undefined ? undefined : JSON.stringify(payload),
  });
  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    throw new Error(data.errors?.join(", ") || `Request failed (${response.status})`);
  }
  return response.status === 204 ? null : response.json();
}
