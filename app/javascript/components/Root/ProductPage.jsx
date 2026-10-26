import React, { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { fetchGet, addToCart } from "../../lib/api";

function StockLabel({ stock }) {
  if (stock === 0) return <span className="stock stock-out">Out of Stock</span>;
  if (stock <= 10) return <span className="stock stock-low">Only a few left!</span>;
  return <span className="stock stock-ok">In Stock</span>;
}

export default function ProductPage() {
  const { id } = useParams();
  const [product, setProduct] = useState(null);
  const [error, setError] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);

  // Fetch the product, its listings, recommendations, and admin status on load
  useEffect(() => {
    // Check if user is admin
    fetchGet("/api/v1/me")
      .then((data) => setIsAdmin(data.is_admin))
      .catch(() => setIsAdmin(false));

    setProduct(null);
    setError(null);
    fetchGet(`/api/v1/products/${id}`)
      .then(setProduct)
      .catch((err) => setError(err.message));
  }, [id]);

  // Handle adding an item (or a recommended item) to the cart
  const handleAddToCart = async (listingId) => {
    try {
      await addToCart(listingId, 1);
      alert("Item added to cart!");
    } catch (err) {
      alert("Failed to add" + err.message);
    }
  };

  if (error) {
    return (
      <p role="alert" className="catalog-error">
        {error}
      </p>
    );
  }
  if (!product) return <p>Loading product…</p>;

  return (
    <div>
      <Link to="/">← All products</Link>
      <h1>{product.name}</h1>
      <p>
        <strong>Category:</strong> {product.category}
      </p>
      <p>{product.description}</p>

      <h2>Cross-Store Price &amp; Stock Comparison</h2>
      {product.listings.length === 0 ? (
        <p>No stores are currently selling this product.</p>
      ) : (
        <table className="compare-table" style={{ width: "100%", textAlign: "left", marginBottom: "40px" }}>
          <thead>
            <tr>
              <th>Store Name</th>
              <th>Store Address</th>
              <th>Price</th>
              <th>Stock</th>
              {/* Only show Action column header if not an admin */}
              {!isAdmin && <th>Action</th>}
            </tr>
          </thead>
          <tbody>
            {product.listings.map((listing) => (
              <tr key={listing.id}>
                <td>
                  <strong>{listing.storeName}</strong>
                </td>
                <td>{listing.storeAddress || "N/A"}</td>
                <td>${Number(listing.price).toFixed(2)}</td>
                <td>
                  <StockLabel stock={listing.stock} />
                </td>
                {/* Only show the Add to Cart cell if not an admin */}
                {!isAdmin && (
                  <td>
                    <button 
                      onClick={() => handleAddToCart(listing.id)}
                      disabled={listing.stock === 0}
                      style={{
                        padding: "6px 12px",
                        cursor: listing.stock === 0 ? "not-allowed" : "pointer",
                        opacity: listing.stock === 0 ? 0.5 : 1,
                        background: listing.stock === 0 ? "#ccc" : "#000",
                        color: "#fff",
                        border: "none",
                        borderRadius: "4px"
                      }}
                    >
                      Add to Cart
                    </button>
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {/* MySQL Clustering Recommendations Section */}
      {product.recommendations && product.recommendations.length > 0 && (
        <div style={{ marginTop: "40px", padding: "20px", background: "#f9f9f9", borderRadius: "8px" }}>
          <h3 style={{ marginTop: 0 }}>Frequently Bought Together</h3>
          <ul style={{ listStyleType: "none", padding: 0, margin: 0 }}>
            {product.recommendations.map((rec) => (
              <li key={rec.id} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "10px 0", borderBottom: "1px solid #ddd" }}>
                <div>
                  <strong>{rec.name}</strong> <br/>
                  <small style={{ color: "#666" }}>Sold by: {rec.storeName}</small>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: "15px" }}>
                  <span>${Number(rec.price).toFixed(2)}</span>
                  {/* Hide recommendation cart buttons from admins too */}
                  {!isAdmin && (
                    <button 
                      onClick={() => handleAddToCart(rec.id)}
                      style={{ padding: "6px 12px", cursor: "pointer", background: "#eee", border: "1px solid #ccc", borderRadius: "4px" }}
                    >
                      Add to Cart
                    </button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}