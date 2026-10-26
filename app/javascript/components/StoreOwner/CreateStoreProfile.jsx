
import React, { useState } from "react";
import { useHistory } from "react-router-dom";
import { fetchRequest } from "../../lib/api";

export default function CreateStoreProfile() {
  const [formData, setFormData] = useState({
    name: "",
    slug: "",
    address: "",
  });

  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const history = useHistory();

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      await fetchRequest("/api/v1/users/store_owners/tenant", "POST", {
        tenant: formData,
      });

      history.push("/product_listings");
    } catch (err) {
      setError(err.message || "Failed to create store profile.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        maxWidth: "600px",
        margin: "40px auto",
        padding: "25px",
        fontFamily: "sans-serif",
        border: "1px solid #ddd",
        borderRadius: "8px",
      }}
    >
      <h2 style={{ borderBottom: "2px solid #000", paddingBottom: "10px" }}>
        Create Store Profile
      </h2>

      {error && (
        <div
          role="alert"
          style={{
            color: "#721c24",
            backgroundColor: "#f8d7da",
            padding: "12px",
            borderRadius: "4px",
            marginBottom: "20px",
          }}
        >
          {error}
        </div>
      )}

      <form
        onSubmit={handleSubmit}
        style={{ display: "flex", flexDirection: "column", gap: "15px" }}
      >
        <div>
          <label htmlFor="name" style={{ fontWeight: "bold" }}>
            Store Name
          </label>
          <input
            id="name"
            name="name"
            type="text"
            value={formData.name}
            onChange={handleChange}
            placeholder="Enter store name"
            required
            style={inputStyle}
          />
        </div>

        <div>
          <label htmlFor="slug" style={{ fontWeight: "bold" }}>
            URL Slug (e.g. techhub-downtown)
          </label>
          <input
            id="slug"
            name="slug"
            type="text"
            value={formData.slug}
            onChange={handleChange}
            placeholder="techhub-downtown"
            required
            pattern="[a-zA-Z0-9-]+"
            title="Use letters, numbers, and hyphens only."
            style={inputStyle}
          />
        </div>

        <div>
          <label htmlFor="address" style={{ fontWeight: "bold" }}>
            Store Address
          </label>
          <textarea
            id="address"
            name="address"
            rows="3"
            value={formData.address}
            onChange={handleChange}
            placeholder="Enter store address"
            style={inputStyle}
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          style={{
            padding: "12px",
            background: "#000",
            color: "#fff",
            border: "none",
            borderRadius: "4px",
            cursor: loading ? "not-allowed" : "pointer",
          }}
        >
          {loading ? "Saving..." : "Save Store Profile"}
        </button>
      </form>
    </div>
  );
}

const inputStyle = {
  display: "block",
  width: "100%",
  boxSizing: "border-box",
  padding: "10px",
  marginTop: "6px",
  border: "1px solid #ccc",
  borderRadius: "4px",
  fontSize: "14px",
};