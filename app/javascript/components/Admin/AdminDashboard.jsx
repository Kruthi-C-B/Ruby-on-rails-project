import React, { useState, useEffect } from "react";
import { fetchGet, fetchRequest } from "../../lib/api";
import LoginAuditLog from "./LoginAuditLog";
import StoreAudit from "./StoreAudit";

export default function AdminDashboard() {
  const [activeTab, setActiveTab] = useState("categories");
  const [message, setMessage] = useState(null);
  const [categories, setCategories] = useState([]);

  useEffect(() => {
    if (activeTab === "products") {
      fetchGet("/api/v1/categories").then(setCategories).catch(console.error);
    }
  }, [activeTab]);

  const handleSubmit = async (e, endpoint, payload) => {
    e.preventDefault();
    setMessage(null);
    try {
      await fetchRequest(`/api/v1/admin/${endpoint}`, "POST", payload);
      setMessage({ type: "success", text: `Successfully created ${endpoint}!` });
      e.target.reset();
    } catch (err) {
      setMessage({ type: "error", text: err.message || `Failed to create ${endpoint}.` });
    }
  };

  return (
    <div style={{ padding: "20px", maxWidth: "900px", margin: "40px auto", fontFamily: "sans-serif" }}>
      <h1 style={{ borderBottom: "2px solid #000", paddingBottom: "10px" }}>Platform Admin Dashboard</h1>
      
      {/* Navigation Tabs */}
      <div style={{ display: "flex", gap: "10px", flexWrap: "wrap", marginBottom: "20px", marginTop: "20px" }}>
        <button onClick={() => setActiveTab("categories")} style={tabStyle(activeTab === "categories")}>Categories</button>
        <button onClick={() => setActiveTab("products")} style={tabStyle(activeTab === "products")}>Universal Products</button>
        <button onClick={() => setActiveTab("discounts")} style={tabStyle(activeTab === "discounts")}>Global Discounts</button>
        <button onClick={() => setActiveTab("security")} style={tabStyle(activeTab === "security")}>Security Logs</button>
        <button onClick={() => setActiveTab("audit")} style={tabStyle(activeTab === "audit")}>Store Audit </button>

        </div>

      {message && (
        <div style={{ padding: "15px", marginBottom: "20px", backgroundColor: message.type === "success" ? "#d4edda" : "#f8d7da", color: message.type === "success" ? "#155724" : "#721c24", borderRadius: "5px" }}>
          {message.text}
        </div>
      )}

      {/* CATEGORIES TAB */}
      {activeTab === "categories" && (
        <form onSubmit={(e) => handleSubmit(e, "categories", { category: { name: e.target.name.value } })}>
          <h2>Add New Category</h2>
          <div style={inputGroup}>
            <label>Category Name</label>
            <input name="name" required style={inputStyle} placeholder="e.g. Electronics, Home Goods" />
          </div>
          <button type="submit" style={btnStyle}>Create Category</button>
        </form>
      )}

      {/* PRODUCTS TAB */}
      {activeTab === "products" && (
        <form onSubmit={(e) => handleSubmit(e, "products", { 
          product: { name: e.target.name.value, description: e.target.desc.value, category_id: e.target.category_id.value } 
        })}>
          <h2>Add Universal Product Base</h2>
          <div style={inputGroup}>
            <label>Product Name</label>
            <input name="name" required style={inputStyle} placeholder="e.g. iPhone 15" />
          </div>
          <div style={inputGroup}>
            <label>Description</label>
            <textarea name="desc" required style={inputStyle} placeholder="Product description..." rows="3" />
          </div>
          <div style={inputGroup}>
            <label>Category</label>
            <select name="category_id" required style={inputStyle}>
              <option value="">Select a Category...</option>
              {categories.map(cat => <option key={cat.id} value={cat.id}>{cat.name}</option>)}
            </select>
          </div>
          <button type="submit" style={btnStyle}>Create Product Base</button>
        </form>
      )}

      {/* DISCOUNTS TAB */}
      {activeTab === "discounts" && (
        <form onSubmit={(e) => handleSubmit(e, "discounts", { 
          discount: { code: e.target.code.value, percentage: e.target.percentage.value } 
        })}>
          <h2>Create Global Discount Code</h2>
          <div style={inputGroup}>
            <label>Promo Code</label>
            <input name="code" required style={inputStyle} placeholder="e.g. BLACKFRIDAY20" />
          </div>
          <div style={inputGroup}>
            <label>Percentage Off</label>
            <input name="percentage" type="number" step="0.1" required style={inputStyle} placeholder="e.g. 20" />
          </div>
          <button type="submit" style={btnStyle}>Create Discount</button>
        </form>
      )}

      {/* SECURITY LOGS TAB */}
      {activeTab === "security" && <LoginAuditLog />}

      {activeTab === "audit" && <StoreAudit />}

    </div>
  );
}

// Styling helpers
const tabStyle = (isActive) => ({ padding: "10px 15px", cursor: "pointer", border: "none", backgroundColor: isActive ? "#000" : "#eee", color: isActive ? "#fff" : "#333", borderRadius: "5px", fontWeight: "bold" });
const inputGroup = { display: "flex", flexDirection: "column", marginBottom: "15px" };
const inputStyle = { padding: "10px", fontSize: "16px", borderRadius: "5px", border: "1px solid #ccc" };
const btnStyle = { padding: "12px 20px", backgroundColor: "#000", color: "#fff", border: "none", borderRadius: "5px", fontSize: "16px", cursor: "pointer", fontWeight: "bold" };