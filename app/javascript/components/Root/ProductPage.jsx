import React, { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { fetchGet, addToCart } from "../../lib/api";
import { Alert, Badge, Button, Card, EmptyState, PageContainer, PageHeader, Section, Spinner } from "../ui";

function StockLabel({ stock }) {
  if (stock === 0) return <Badge variant="danger">Out of Stock</Badge>;
  if (stock <= 10) return <Badge variant="warning">Only a few left!</Badge>;
  return <Badge variant="success">In Stock</Badge>;
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
  const handleAddToCart = async (listingReferenceId) => {
    try {
      await addToCart(listingReferenceId, 1);
      alert("Item added to cart!");
    } catch (err) {
      alert("Failed to add" + err.message);
    }
  };

  if (error) {
    return <PageContainer><Alert>{error}</Alert></PageContainer>;
  }
  if (!product) return <PageContainer><Spinner label="Loading product…" /></PageContainer>;

  return (
    <PageContainer>
      <PageHeader
        title={product.name}
        description={product.description}
        action={<Button as={Link} to="/" variant="outline">← All products</Button>}
      />
      <p><strong>Category:</strong> {product.category}</p>

      <Section title="Cross-Store Price &amp; Stock Comparison">
      {product.listings.length === 0 ? (
        <EmptyState title="No stores are selling this product yet." />
      ) : (
        <div className="lf-table-scroll">
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
                    <Button
                      size="small"
                      onClick={() => handleAddToCart(listing.listingReferenceId)}
                      disabled={listing.stock === 0}
                    >
                      Add to Cart
                    </Button>
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
        </div>
      )}
      </Section>

      {/* MySQL Clustering Recommendations Section */}
      {product.recommendations && product.recommendations.length > 0 && (
        <Card title="Frequently Bought Together" variant="muted" className="lf-recommendations">
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
                    <Button
                      variant="secondary"
                      size="small"
                      onClick={() => handleAddToCart(rec.listingReferenceId)}
                    >
                      Add to Cart
                    </Button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </Card>
      )}
    </PageContainer>
  );
}