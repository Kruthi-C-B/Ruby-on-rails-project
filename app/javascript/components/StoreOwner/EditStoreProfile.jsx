import React, { useState, useEffect } from "react";
import { Link, useHistory } from "react-router-dom";
import { fetchGet, fetchRequest } from "../../lib/api";

export default function EditStoreProfile() {
  const [formData, setFormData] = useState({ name: "", slug: "", address: "" });
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);
  const history = useHistory();

  useEffect(() => {
    // Fetch the current user's tenant (store profile) data on load
    fetchGet("/api/v1/me")
      .then((data) => {
        if (data.tenant) {
          setFormData({
            name: data.tenant.name || "",
            slug: data.tenant.slug || "",
            address: data.tenant.address || ""
          });
        }
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    try {
      // Send the update to the new JSON API endpoint
      await fetchRequest("/api/v1/users/store_owners/tenant", "PUT", { tenant: formData });
      history.push("/product_listings"); // Redirect back to dashboard on success
    } catch (err) {
      setError(err.message || "Failed to update store profile.");
    }
  };

  if (loading) return <p style={{ padding: "20px" }}>Loading profile...</p>;

  return (
    <div style={{ padding: "20px", maxWidth: "600px", margin: "40px auto", fontFamily: "sans-serif" }}>
      <h2 style={{ borderBottom: "2px solid #000", paddingBottom: "10px" }}>Edit Store Profile</h2>
      
      {error && (
        <div style={{ backgroundColor: "#f8d7da", color: "#721c24", padding: "12px", borderRadius: "4px", marginBottom: "20px" }}>
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
        <div>
          <label style={{ display: "block", fontWeight: "bold", marginBottom: "5px" }}>Store Name</label>
          <input 
            type="text" required 
            value={formData.name} 
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            style={{ padding: "8px", width: "100%", boxSizing: "border-box" }}
          />
        </div>

        <div>
          <label style={{ display: "block", fontWeight: "bold", marginBottom: "5px" }}>Store URL Slug</label>
          <input 
            type="text" required 
            value={formData.slug} 
            onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
            style={{ padding: "8px", width: "100%", boxSizing: "border-box" }}
          />
        </div>

        <div>
          <label style={{ display: "block", fontWeight: "bold", marginBottom: "5px" }}>Store Address</label>
          <textarea 
            required rows="3"
            value={formData.address} 
            onChange={(e) => setFormData({ ...formData, address: e.target.value })}
            style={{ padding: "8px", width: "100%", boxSizing: "border-box" }}
          />
        </div>

        <div style={{ display: "flex", gap: "10px", marginTop: "10px" }}>
          <button type="submit" style={{ padding: "10px 15px", background: "#000", color: "#fff", border: "none", borderRadius: "4px", cursor: "pointer" }}>
            Update Profile
          </button>
          <Link to="/product_listings" style={{ padding: "10px 15px", color: "#007bff", textDecoration: "none", display: "inline-block" }}>
            Cancel
          </Link>
        </div>
      </form>
    </div>
  );
}