function csrfToken() {
  const meta = document.querySelector("meta[name='csrf-token']");
  return meta ? meta.content : "";
}

async function handle(response) {
  const data = await response.json().catch(() => null);
  if (!response.ok) {
    const message = data && data.errors ? data.errors.join(", ") : `Request failed (${response.status})`;
    throw new Error(message);
  }
  return data;
}

export function fetchGet(url) {
  return fetch(url, { headers: { Accept: "application/json" } }).then(handle);
}

export function fetchRequest(url, method, body) {
  return fetch(url, {
    method,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": csrfToken()
    },
    body: JSON.stringify(body)
  }).then(handle);
}

// Fetch the current user's active cart
export const fetchCart = () => {
  return fetchGet("/api/v1/users/cart");
};

// Add an item to the cart
export const addToCart = (productListingId, quantity) => {
  return fetchRequest("/api/v1/users/cart/items", "POST", { 
    product_listing_id: productListingId, 
    quantity: quantity 
  });
};

// Apply a discount code
export const applyDiscount = (code) => {
  return fetchRequest("/api/v1/users/cart/apply_discount", "POST", { 
    code: code 
  });
};

export const fetchCartAudit = () => {
  return fetchGet("/api/v1/users/cart/audit");
};