import React, { useState, useEffect} from "react";
import { fetchGet, fetchRequest } from "../../lib/api";

export default function StoreOwnerDashboard() {
  // --- Core State ---
  const [tenant, setTenant] = useState(null);
  const [listings, setListings] = useState([]);
  const [auditData, setAuditData] = useState(null);
  const [loading, setLoading] = useState(true);

  // --- Dynamic Dropdown State (For 'New' Form) ---
  const [categories, setCategories] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState("");
  const [availableProducts, setAvailableProducts] = useState([]);

  // --- Form View State ('none', 'add', or 'edit') ---
  const [formMode, setFormMode] = useState("none"); 
  const [editingListing, setEditingListing] = useState(null); // Stores the full listing being edited
  const [formData, setFormData] = useState({ product_id: "", price: "", stock_quantity: "" });
  const [formError, setFormError] = useState(null);

  // 1. Initial Data Load
  useEffect(() => {
    Promise.all([
      fetchGet("/api/v1/me"),
      fetchGet("/api/v1/users/store_owners/product_listings"),
      fetchGet("/api/v1/categories"),
      
      fetchGet("/api/v1/users/store_owners/analytics")
    ])
      .then(([userData, inventory, fetchedCategories,audit]) => {
        setTenant(userData.tenant);
        setAuditData(audit);
        setListings(inventory);
        setCategories(fetchedCategories);
        setLoading(false);
      })
      .catch((err) => {
        console.error("Failed to load dashboard data", err);
        setLoading(false);
      });
  }, []);

  // 2. Fetch Products only when Category changes (Matches old new.html.erb logic)
  useEffect(() => {
    if (selectedCategory) {
      fetchGet(`/api/v1/products?category_id=${selectedCategory}`)
        .then(setAvailableProducts)
        .catch(console.error);
    } else {
      setAvailableProducts([]);
    }
  }, [selectedCategory]);

  // --- Handlers ---
  const handleOpenAdd = () => {
    setFormMode("add");
    setEditingListing(null);
    setSelectedCategory(""); 
    setFormData({ product_id: "", price: "", stock_quantity: "" });
    setFormError(null);
  };

  const handleOpenEdit = (listing) => {
    setFormMode("edit");
    setEditingListing(listing);
    // Edit form only needs price and stock
    setFormData({ price: listing.price, stock_quantity: listing.stock_quantity });
    setFormError(null);
  };

  const handleCloseForm = () => {
    setFormMode("none");
    setEditingListing(null);
    setFormError(null);
  };

  const handleSaveListing = async (e) => {
    e.preventDefault();
    setFormError(null);

    const payload = { product_listing: formData };
    const method = formMode === "edit" ? "PUT" : "POST";
    const endpoint = formMode === "edit" 
      ? `/api/v1/users/store_owners/product_listings/${editingListing.id}`
      : `/api/v1/users/store_owners/product_listings`;

    try {
      const savedListing = await fetchRequest(endpoint, method, payload);
      
      if (formMode === "edit") {
        setListings(listings.map(l => (l.id === editingListing.id ? savedListing : l)));
      } else {
        setListings([...listings, savedListing]);
      }
      handleCloseForm();
    } catch (err) {
      setFormError(err.message || "Failed to save product listing.");
    }
  };

  const handleDeleteListing = async (id) => {
    if (!window.confirm("Are you sure?")) return;
    
    try {
      await fetchRequest(`/api/v1/users/store_owners/product_listings/${id}`, "DELETE");
      setListings(listings.filter(listing => listing.id !== id));
    } catch (error) {
      alert("Failed to delete product listing.");
    }
  };

  if (loading) return <p style={{ padding: "20px" }}>Loading your dashboard...</p>;

  return (

    <div style={{ padding: "20px", maxWidth: "900px", margin: "40px auto", fontFamily: "sans-serif" }}>

      {/* --- HEADER (Matches index.html.erb) --- */}
      <h1 style={{ borderBottom: "2px solid #000", paddingBottom: "10px" }}>
        {tenant?.name || "Your Store"} — Admin Dashboard
      </h1>
      <p><strong>Address:</strong> {tenant?.address || "No address provided"}</p>
      <p>
        <a href="/tenant/edit" style={{ color: "#007bff", textDecoration: "none" }}>Edit Store Profile</a>
      </p>

      <hr style={{ margin: "30px 0", border: "none", borderTop: "2px solid #eee" }} />

      {/* --- ADD / EDIT FORMS --- */}
      {formMode === "add" && (
        <div style={{ padding: "20px", background: "#f9f9f9", border: "1px solid #ddd", borderRadius: "5px", marginBottom: "20px" }}>
          <h2 style={{ marginTop: 0 }}>Add Product to Store Listing</h2>
          
          {formError && (
            <div style={{ backgroundColor: "#f8d7da", color: "#721c24", padding: "12px", borderRadius: "4px", marginBottom: "20px" }}>
              <strong>Unable to add product:</strong> {formError}
            </div>
          )}
          
          <form onSubmit={handleSaveListing} style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
            <div>
              <label style={{ display: "block", fontWeight: "bold", marginBottom: "5px" }}>Select Category</label>
              <select 
                value={selectedCategory} 
                onChange={(e) => {
                  setSelectedCategory(e.target.value);
                  setFormData({ ...formData, product_id: "" });
                }}
                required
                style={{ padding: "8px", width: "100%", maxWidth: "400px" }}
              >
                <option value="">Choose a Category...</option>
                {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </div>

            <div>
              <label style={{ display: "block", fontWeight: "bold", marginBottom: "5px" }}>2. Select Product from Catalog</label>
              {availableProducts.length > 0 ? (
                <select 
                  value={formData.product_id} 
                  onChange={(e) => setFormData({ ...formData, product_id: e.target.value })}
                  required
                  style={{ padding: "8px", width: "100%", maxWidth: "400px" }}
                >
                  <option value="">Select a product</option>
                  {availableProducts.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
                </select>
              ) : (
                <select disabled style={{ padding: "8px", width: "100%", maxWidth: "400px", backgroundColor: "#eee" }}>
                  <option>Please select a category first...</option>
                </select>
              )}
            </div>

            <div>
              <label style={{ display: "block", fontWeight: "bold", marginBottom: "5px" }}>Store Price ($)</label>
              <input 
                type="number" step="0.01" min="0" required
                value={formData.price} 
                onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                style={{ padding: "8px", width: "150px" }}
              />
            </div>

            <div>
              <label style={{ display: "block", fontWeight: "bold", marginBottom: "5px" }}>Stock Quantity</label>
              <input 
                type="number" min="0" required
                value={formData.stock_quantity} 
                onChange={(e) => setFormData({ ...formData, stock_quantity: e.target.value })}
                style={{ padding: "8px", width: "150px" }}
              />
            </div>

            <div style={{ display: "flex", gap: "10px", marginTop: "10px" }}>
              <button type="submit" style={{ padding: "9px 15px", background: "#000", color: "#fff", cursor: "pointer", border: "none", borderRadius: "3px" }}>
                Add to Store
              </button>
              <button type="button" onClick={handleCloseForm} style={{ padding: "9px 15px", cursor: "pointer", color: "#007bff", textDecoration: "underline", background: "none", border: "none" }}>
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {formMode === "edit" && editingListing && (
        <div style={{ padding: "20px", background: "#f9f9f9", border: "1px solid #ddd", borderRadius: "5px", marginBottom: "20px" }}>
          <h2 style={{ marginTop: 0 }}>Edit Listing for {editingListing.product?.name}</h2>
          
          {formError && <p style={{ color: "red" }}>{formError}</p>}
          
          <form onSubmit={handleSaveListing} style={{ display: "flex", flexDirection: "column", gap: "15px" }}>
            <div>
              <label style={{ display: "block", fontWeight: "bold", marginBottom: "5px" }}>Store Price ($)</label>
              <input 
                type="number" step="0.01" min="0" required
                value={formData.price} 
                onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                style={{ padding: "8px", width: "150px" }}
              />
            </div>

            <div>
              <label style={{ display: "block", fontWeight: "bold", marginBottom: "5px" }}>Stock Quantity</label>
              <input 
                type="number" min="0" required
                value={formData.stock_quantity} 
                onChange={(e) => setFormData({ ...formData, stock_quantity: e.target.value })}
                style={{ padding: "8px", width: "150px" }}
              />
            </div>

            <div style={{ display: "flex", gap: "10px", marginTop: "10px" }}>
              <button type="submit" style={{ padding: "9px 15px", background: "#000", color: "#fff", cursor: "pointer", border: "none", borderRadius: "3px" }}>
                Update Listing
              </button>
              <button type="button" onClick={handleCloseForm} style={{ padding: "9px 15px", cursor: "pointer", color: "#007bff", textDecoration: "underline", background: "none", border: "none" }}>
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {/* --- STORE INVENTORY TABLE --- */}
      {formMode === "none" && (
        <>
          <h2 style={{ marginBottom: "15px" }}>Store Product Inventory</h2>
          
          <button 
            onClick={handleOpenAdd} 
            style={{ background: "green", color: "white", padding: "8px 12px", border: "none", borderRadius: "4px", cursor: "pointer", textDecoration: "none", marginBottom: "20px", display: "inline-block" }}>
            + Add Product from Catalog
          </button>

          <table style={{ width: "100%", borderCollapse: "collapse", textAlign: "left", marginBottom: "40px" }} border="1" cellPadding="10" cellSpacing="0">
            <thead style={{ backgroundColor: "#f9f9f9" }}>
              <tr>
                <th>Product Name</th>
                <th>Category</th>
                <th>Price</th>
                <th>Stock Quantity</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {listings.length > 0 ? (
                listings.map(listing => (
                  <tr key={listing.id}>
                    <td>{listing.product?.name}</td>
                    <td>{listing.product?.category?.name || listing.product?.category}</td>
                    <td>${parseFloat(listing.price).toFixed(2)}</td>
                    <td>{listing.stock_quantity}</td>
                    <td>
                      <button 
                        onClick={() => handleOpenEdit(listing)} 
                        style={{ color: "#007bff", background: "none", border: "none", cursor: "pointer", textDecoration: "underline", padding: 0, marginRight: "5px" }}
                      >
                        Edit Price/Stock
                      </button> | 
                      <button 
                        onClick={() => handleDeleteListing(listing.id)} 
                        style={{ color: "red", background: "none", border: "none", cursor: "pointer", padding: 0, marginLeft: "5px" }}
                      >
                        Remove
                      </button>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan="5" style={{ padding: "15px", color: "#666", textAlign: "left" }}>
                    No products listed in your store yet. Click "+ Add Product from Catalog" above.
                  </td>
                </tr>
              )}
            </tbody>
          </table>

          <hr style={{ margin: "40px 0", border: "none", borderTop: "2px solid #eee" }} />

          
{/* --- STORE PURCHASE ANALYTICS --- */}
<h2>Store Purchase History</h2>

{auditData && auditData.metrics ? (
  <>
    <div
      style={{
        display: "flex",
        gap: "20px",
        marginBottom: "20px",
        flexWrap: "wrap",
      }}
    >
      <div
        style={{
          padding: "20px",
          background: "#f0f8ff",
          borderRadius: "8px",
          flex: 1,
          border: "1px solid #b6d4fe",
        }}
      >
        <h4 style={{ margin: 0, color: "#004085" }}>
          Orders Containing Your Products
        </h4>
        <p style={{ fontSize: "2em", fontWeight: "bold", color: "#004085" }}>
          {auditData.metrics.total_ordered}
        </p>
      </div>

      <div
        style={{
          padding: "20px",
          background: "#f0f8ff",
          borderRadius: "8px",
          flex: 1,
          border: "1px solid #b6d4fe",
        }}
      >
        <h4 style={{ margin: 0, color: "#004085" }}>
          Items Purchased From Your Store
        </h4>
        <p style={{ fontSize: "2em", fontWeight: "bold", color: "#004085" }}>
          {auditData.metrics.total_items || 0}
        </p>
      </div>
    </div>

    <h3>Product Purchase History</h3>

    <div style={{ overflowX: "auto" }}>
      <table
        style={{
          width: "100%",
          textAlign: "left",
          borderCollapse: "collapse",
          fontSize: "0.95em",
          border: "1px solid #ddd",
        }}
        cellPadding="10"
      >
        <thead style={{ backgroundColor: "#f9f9f9" }}>
          <tr>
            <th>Purchaser Email</th>
            <th>Date / Time</th>
            <th>Order ID</th>
            <th>Product</th>
            <th>Quantity</th>
            <th>Unit Price</th>
            <th>Line Total</th>
          </tr>
        </thead>

        <tbody>
          {auditData.purchase_history?.length > 0 ? (
            auditData.purchase_history.map((purchase) => (
              <tr key={purchase.id} style={{ borderBottom: "1px solid #eee" }}>
                <td>{purchase.purchaser_email}</td>
                
                <td>
                  {purchase.date
                    ? new Date(purchase.date).toLocaleString()
                    : "—"}
                </td>
                <td>#{purchase.cart_id}</td>
                <td>{purchase.product_name}</td>
                <td>{purchase.quantity}</td>
                <td>
                  {purchase.unit_price != null
                    ? Number(purchase.unit_price).toFixed(2)
                    : "—"}
                </td>
                <td>
                  {purchase.total != null
                    ? Number(purchase.total).toFixed(2)
                    : "—"}
                </td>
              </tr>
            ))
          ) : (
            <tr>
              <td
                colSpan="6"
                style={{
                  padding: "15px",
                  color: "#666",
                  textAlign: "center",
                }}
              >
                No completed purchases for your store yet.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  </>
) : (
  <p>Loading purchase history...</p>
)}

        </>
      )}
    </div>
  );
}