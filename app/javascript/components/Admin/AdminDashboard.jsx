import React, { useState, useEffect, useCallback } from "react";
import { fetchGet, fetchRequest } from "../../lib/api";
import LoginAuditLog from "./LoginAuditLog";
import StoreAudit from "./StoreAudit";

export default function AdminDashboard() {
  const [activeTab, setActiveTab] = useState("categories");
  const [message, setMessage] = useState(null);

  const [categories, setCategories] = useState([]);
  const [products, setProducts] = useState([]);
  const [discounts, setDiscounts] = useState([]);

  const [loading, setLoading] = useState(false);
  const [loadError, setLoadError] = useState("");

  const loadData = useCallback(async (tab) => {
    const endpoints = {
      categories: "/api/v1/categories",
      products: "/api/v1/admin/products",
      discounts: "/api/v1/admin/discounts",
    };

    if (!endpoints[tab]) return;

    setLoading(true);
    setLoadError("");

    try {
      const data = await fetchGet(endpoints[tab]);

      if (tab === "categories") setCategories(data);
      if (tab === "products") setProducts(data);
      if (tab === "discounts") setDiscounts(data);
    } catch (err) {
      console.error(err);
      setLoadError(err.message || `Failed to load ${tab}.`);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData(activeTab);
  }, [activeTab, loadData]);

  const handleSubmit = async (e, endpoint, payload, tab) => {
    e.preventDefault();
    setMessage(null);

    try {
      await fetchRequest(`/api/v1/admin/${endpoint}`, "POST", payload);

      setMessage({
        type: "success",
        text: `Successfully created ${endpoint}!`,
      });

      e.target.reset();
      await loadData(tab);
    } catch (err) {
      setMessage({
        type: "error",
        text: err.message || `Failed to create ${endpoint}.`,
      });
    }
  };

  const tabs = [
    ["categories", "Categories"],
    ["products", "Universal Products"],
    ["discounts", "Global Discounts"],
    ["security", "Security Logs"],
    ["audit", "Store Audit"],
  ];

  return (
    <div style={pageStyle}>
      <h1 style={headingStyle}>Platform Admin Dashboard</h1>

      <div style={tabsStyle}>
        {tabs.map(([key, label]) => (
          <button
            key={key}
            onClick={() => {
              setActiveTab(key);
              setMessage(null);
            }}
            style={tabStyle(activeTab === key)}
          >
            {label}
          </button>
        ))}
      </div>

      {message && (
        <div style={alertStyle(message.type)}>
          {message.text}
        </div>
      )}

      {loadError && (
        <div style={alertStyle("error")}>
          {loadError}
          <button
            onClick={() => loadData(activeTab)}
            style={{ marginLeft: 12 }}
          >
            Retry
          </button>
        </div>
      )}

      {loading && <p>Loading existing records...</p>}

      {/* CATEGORIES */}
      {activeTab === "categories" && (
        <>
          <section style={sectionStyle}>
            <h2>Existing Categories ({categories.length})</h2>

            {!loading && categories.length === 0 && (
              <p>No categories found yet.</p>
            )}

            {categories.length > 0 && (
              <ul style={listStyle}>
                {categories.map((cat) => (
                  <li key={cat.id} style={listItemStyle}>
                    <strong>{cat.name}</strong>
                    <span style={mutedStyle}>ID: {cat.id}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section style={sectionStyle}>
            <h2>Add New Category</h2>

            <form
              onSubmit={(e) =>
                handleSubmit(
                  e,
                  "categories",
                  { category: { name: e.currentTarget.name.value.trim() } },
                  "categories"
                )
              }
            >
              <div style={inputGroup}>
                <label>Category Name</label>
                <input
                  name="name"
                  required
                  style={inputStyle}
                  placeholder="e.g. Electronics, Home Goods"
                />
              </div>

              <button type="submit" style={btnStyle}>
                Create Category
              </button>
            </form>
          </section>
        </>
      )}

      {/* UNIVERSAL PRODUCTS */}
      {activeTab === "products" && (
        <>
          <section style={sectionStyle}>
            <h2>
              Existing Universal Products (
              {products.reduce((total, group) => total + group.products.length, 0)})
            </h2>

            {!loading && products.length === 0 && (
              <p>No products found yet.</p>
            )}

            {products.length > 0 && (
              products.map((group) => (
                <div key={group.category_id} style={{ marginTop: 24 }}>
                  <h3>{group.category_name}</h3>
                  <div style={tableWrapperStyle}>
                    <table style={tableStyle}>
                      <thead>
                        <tr>
                          <th style={cellStyle}>ID</th>
                          <th style={cellStyle}>Product</th>
                          <th style={cellStyle}>Description</th>
                        </tr>
                      </thead>
                      <tbody>
                        {group.products.map((product) => (
                          <tr key={product.id}>
                            <td style={cellStyle}>{product.id}</td>
                            <td style={cellStyle}>
                              <strong>{product.name}</strong>
                            </td>
                            <td style={cellStyle}>
                              {product.description || "—"}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              ))
            )}
          </section>

          <section style={sectionStyle}>
            <h2>Add Universal Product Base</h2>

            <form
              onSubmit={(e) =>
                handleSubmit(
                  e,
                  "products",
                  {
                    product: {
                      name: e.currentTarget.name.value.trim(),
                      description: e.currentTarget.desc.value.trim(),
                      category_id: e.currentTarget.category_id.value,
                    },
                  },
                  "products"
                )
              }
            >
              <div style={inputGroup}>
                <label>Product Name</label>
                <input
                  name="name"
                  required
                  style={inputStyle}
                  placeholder="e.g. iPhone 15"
                />
              </div>

              <div style={inputGroup}>
                <label>Description</label>
                <textarea
                  name="desc"
                  required
                  style={inputStyle}
                  rows="3"
                  placeholder="Product description..."
                />
              </div>

              <div style={inputGroup}>
                <label>Category</label>
                <select
                  name="category_id"
                  required
                  style={inputStyle}
                  defaultValue=""
                >
                  <option value="">Select a Category...</option>
                  {categories.map((cat) => (
                    <option key={cat.id} value={cat.id}>
                      {cat.name}
                    </option>
                  ))}
                </select>
              </div>

              <button type="submit" style={btnStyle}>
                Create Product Base
              </button>
            </form>
          </section>
        </>
      )}

      {/* GLOBAL DISCOUNTS */}
      {activeTab === "discounts" && (
        <>
          <section style={sectionStyle}>
            <h2>Existing Global Discounts ({discounts.length})</h2>

            {!loading && discounts.length === 0 && (
              <p>No discount codes found yet.</p>
            )}

            {discounts.length > 0 && (
              <div style={tableWrapperStyle}>
                <table style={tableStyle}>
                  <thead>
                    <tr>
                      <th style={cellStyle}>ID</th>
                      <th style={cellStyle}>Code</th>
                      <th style={cellStyle}>Percentage Off</th>
                    </tr>
                  </thead>
                  <tbody>
                    {discounts.map((discount) => (
                      <tr key={discount.id}>
                        <td style={cellStyle}>{discount.id}</td>
                        <td style={cellStyle}>
                          <strong>{discount.code}</strong>
                        </td>
                        <td style={cellStyle}>
                          {discount.percentage}%
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          <section style={sectionStyle}>
            <h2>Create Global Discount Code</h2>

            <form
              onSubmit={(e) =>
                handleSubmit(
                  e,
                  "discounts",
                  {
                    discount: {
                      code: e.currentTarget.code.value.trim(),
                      percentage: e.currentTarget.percentage.value,
                    },
                  },
                  "discounts"
                )
              }
            >
              <div style={inputGroup}>
                <label>Promo Code</label>
                <input
                  name="code"
                  required
                  style={inputStyle}
                  placeholder="e.g. BLACKFRIDAY20"
                />
              </div>

              <div style={inputGroup}>
                <label>Percentage Off</label>
                <input
                  name="percentage"
                  type="number"
                  min="0.1"
                  max="100"
                  step="0.1"
                  required
                  style={inputStyle}
                  placeholder="e.g. 20"
                />
              </div>

              <button type="submit" style={btnStyle}>
                Create Discount
              </button>
            </form>
          </section>
        </>
      )}

      {activeTab === "security" && <LoginAuditLog />}
      {activeTab === "audit" && <StoreAudit />}
    </div>
  );
}

const pageStyle = {
  padding: 20,
  maxWidth: 1100,
  margin: "40px auto",
  fontFamily: "sans-serif",
};

const headingStyle = {
  borderBottom: "2px solid #000",
  paddingBottom: 10,
};

const tabsStyle = {
  display: "flex",
  gap: 10,
  flexWrap: "wrap",
  margin: "20px 0",
};

const tabStyle = (active) => ({
  padding: "10px 15px",
  cursor: "pointer",
  border: "none",
  backgroundColor: active ? "#000" : "#eee",
  color: active ? "#fff" : "#333",
  borderRadius: 5,
  fontWeight: "bold",
});

const sectionStyle = {
  marginBottom: 30,
  padding: 20,
  border: "1px solid #ddd",
  borderRadius: 8,
};

const inputGroup = {
  display: "flex",
  flexDirection: "column",
  gap: 6,
  marginBottom: 15,
};

const inputStyle = {
  padding: 10,
  fontSize: 16,
  borderRadius: 5,
  border: "1px solid #ccc",
  width: "100%",
  boxSizing: "border-box",
};

const btnStyle = {
  padding: "12px 20px",
  backgroundColor: "#000",
  color: "#fff",
  border: "none",
  borderRadius: 5,
  fontSize: 16,
  cursor: "pointer",
  fontWeight: "bold",
};

const listStyle = {
  listStyle: "none",
  padding: 0,
  margin: 0,
};

const listItemStyle = {
  display: "flex",
  justifyContent: "space-between",
  gap: 12,
  padding: "12px 0",
  borderBottom: "1px solid #eee",
};

const mutedStyle = {
  color: "#777",
  fontSize: 13,
};

const tableWrapperStyle = {
  overflowX: "auto",
};

const tableStyle = {
  width: "100%",
  borderCollapse: "collapse",
  textAlign: "left",
};

const cellStyle = {
  padding: 12,
  borderBottom: "1px solid #ddd",
  verticalAlign: "top",
};

const alertStyle = (type) => ({
  padding: 15,
  marginBottom: 20,
  backgroundColor: type === "success" ? "#d4edda" : "#f8d7da",
  color: type === "success" ? "#155724" : "#721c24",
  borderRadius: 5,
});
