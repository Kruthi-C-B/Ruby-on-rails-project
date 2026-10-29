import React, { useState, useEffect} from "react";
import { fetchGet, fetchRequest } from "../../lib/api";
import { Alert, Button, Card, EmptyState, Input, Modal, PageContainer, PageHeader, Section, Select, Spinner } from "../ui";

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

  if (loading) return <PageContainer><Spinner label="Loading your dashboard…" /></PageContainer>;

  return (
    <PageContainer className="lf-store-owner-page">
      <PageHeader
        title={`${tenant?.name || "Your Store"} — Admin Dashboard`}
        description={`Address: ${tenant?.address || "No address provided"}`}
        action={<Button as="a" href="/tenant/edit" variant="outline">Edit Store Profile</Button>}
      />

      <hr style={{ margin: "30px 0", border: "none", borderTop: "2px solid #eee" }} />

      {/* --- ADD / EDIT FORMS --- */}
      {formMode === "add" && (
        <Modal open onClose={handleCloseForm} title="Add Product to Store Listing">
          {formError && <Alert title="Unable to add product">{formError}</Alert>}
          
          <form onSubmit={handleSaveListing} className="lf-form-stack">
            <Select
                label="Select Category"
                value={selectedCategory}
                onChange={(e) => {
                  setSelectedCategory(e.target.value);
                  setFormData({ ...formData, product_id: "" });
                }}
                required
              >
                <option value="">Choose a Category...</option>
                {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
            </Select>

            <Select
              label="2. Select Product from Catalog"
              value={formData.product_id}
              onChange={(e) => setFormData({ ...formData, product_id: e.target.value })}
              required={availableProducts.length > 0}
              disabled={availableProducts.length === 0}
            >
              {availableProducts.length > 0 ? (
                <>
                  <option value="">Select a product</option>
                  {availableProducts.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
                </>
              ) : (
                <option value="">Please select a category first...</option>
              )}
            </Select>

            <Input
                label="Store Price ($)"
                type="number" step="0.01" min="0" required
                value={formData.price}
                onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                style={{ maxWidth: "220px" }}
              />

            <Input
                label="Stock Quantity"
                type="number" min="0" required
                value={formData.stock_quantity}
                onChange={(e) => setFormData({ ...formData, stock_quantity: e.target.value })}
                style={{ maxWidth: "220px" }}
              />

            <div className="lf-form-actions">
              <Button type="submit">Add to Store</Button>
              <Button type="button" variant="outline" onClick={handleCloseForm}>Cancel</Button>
            </div>
          </form>
        </Modal>
      )}

      {formMode === "edit" && editingListing && (
        <Modal
          open
          onClose={handleCloseForm}
          title={`Edit Listing for ${editingListing.product?.name}`}
        >
          {formError && <Alert>{formError}</Alert>}

          <form onSubmit={handleSaveListing} className="lf-form-stack">
            <Input
                label="Store Price ($)"
                type="number" step="0.01" min="0" required
                value={formData.price}
                onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                style={{ maxWidth: "220px" }}
              />

            <Input
                label="Stock Quantity"
                type="number" min="0" required
                value={formData.stock_quantity}
                onChange={(e) => setFormData({ ...formData, stock_quantity: e.target.value })}
                style={{ maxWidth: "220px" }}
              />

            <div className="lf-form-actions">
              <Button type="submit">Update Listing</Button>
              <Button type="button" variant="outline" onClick={handleCloseForm}>Cancel</Button>
            </div>
          </form>
        </Modal>
      )}

      {/* --- STORE INVENTORY TABLE --- */}
      {formMode === "none" && (
        <>
          <Section
            title="Store Product Inventory"
            actions={
              <Button onClick={handleOpenAdd} variant="success">
                + Add Product from Catalog
              </Button>
            }
          >

          <div className="lf-table-scroll">
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
                      <Button
                        variant="outline"
                        size="small"
                        onClick={() => handleOpenEdit(listing)}
                      >
                        Edit Price/Stock
                      </Button>
                      {" "}
                      <Button
                        variant="danger"
                        size="small"
                        onClick={() => handleDeleteListing(listing.id)}
                      >
                        Remove
                      </Button>
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan="5">
                    <EmptyState title="No products listed yet">
                      Add a product from the catalog to begin.
                    </EmptyState>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
          </div>
          </Section>

          <hr style={{ margin: "40px 0", border: "none", borderTop: "2px solid #eee" }} />

          
{/* --- STORE PURCHASE ANALYTICS --- */}
<h2>Store Purchase History</h2>

{auditData && auditData.metrics ? (
  <>
    <div className="lf-metric-grid">
      <Card variant="muted" className="lf-metric-card">
        <h4 style={{ margin: 0, color: "#004085" }}>
          Orders Containing Your Products
        </h4>
        <p className="lf-metric-card__value">
          {auditData.metrics.total_ordered}
        </p>
      </Card>

      <Card variant="muted" className="lf-metric-card">
        <h4 style={{ margin: 0, color: "#004085" }}>
          Items Purchased From Your Store
        </h4>
        <p className="lf-metric-card__value">
          {auditData.metrics.total_items || 0}
        </p>
      </Card>
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
              <td colSpan="7">
                <EmptyState title="No completed purchases for your store yet." />
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  </>
) : (
  <Spinner label="Loading purchase history…" />
)}

        </>
      )}
    </PageContainer>
  );
}