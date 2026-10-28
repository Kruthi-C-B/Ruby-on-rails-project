import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { fetchGet } from "../../lib/api";

export default function CatalogPage({ storeName }) {
  const [categories, setCategories] = useState([]);
  const [products, setProducts] = useState([]);
  const [query, setQuery] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [filters, setFilters] = useState({ query: "", categoryId: "" });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  // New state to track if user is admin
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    // Check if the logged-in user is an admin
    fetchGet("/api/v1/me")
      .then((data) => setIsAdmin(data.is_admin))
      .catch(() => setIsAdmin(false));

    fetchGet("/api/v1/categories")
      .then(setCategories)
      .catch((err) => setError(err.message));
  }, []);

  useEffect(() => {
    const params = new URLSearchParams();
    if (filters.query) params.set("query", filters.query);
    if (filters.categoryId) params.set("category_id", filters.categoryId);

    setLoading(true);
    setError(null);
    fetchGet(`/api/v1/products?${params}`)
      .then(setProducts)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [filters]);

  function applyFilters(event) {
    event.preventDefault();
    setFilters({ query, categoryId });
  }

  function renderProducts() {
    if (loading) return <p>Loading products…</p>;
    if (products.length === 0) return <p>No products found in the catalog.</p>;

    return (
      <div className="catalog-grid">
        {products.map((product) => (
          <div key={product.id} className="catalog-card">
            <h3>
              <Link to={`/products/${product.id}`}>{product.name}</Link>
            </h3>
            <p>
              <strong>Category:</strong> {product.category}
            </p>
            <p>{product.description}</p>
            <Link className="catalog-button" to={`/products/${product.id}`}>
              Compare Prices
            </Link>
          </div>
        ))}
      </div>
    );
  }

  return (
    <div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h1>Product Catalog</h1>
        
        {/* Conditionally render the button based on admin status */}
        {isAdmin ? (
          <a
            href="/admin/dashboard"
            className="catalog-button" 
            style={{ padding: "10px 15px", background: "#0056b3", color: "#fff", textDecoration: "none", borderRadius: "5px", fontWeight: "bold" }}
          >
            ⚙️ Admin Dashboard
          </a>
        ) : (
          <Link 
            to="/cart" 
            className="catalog-button" 
            style={{ padding: "10px 15px", background: "#000", color: "#fff", textDecoration: "none", borderRadius: "5px", fontWeight: "bold" }}
          >
            🛒 View Cart
          </Link>
        )}
      </div>
      
      {storeName && <p className="catalog-note">You run {storeName}. Manage it from My Store Dashboard.</p>}

      <form className="catalog-filters" onSubmit={applyFilters}>
        <label htmlFor="catalog-query">Search Product:</label>
        <input id="catalog-query" value={query} placeholder="e.g. Headphones" onChange={(e) => setQuery(e.target.value)} />
        <label htmlFor="catalog-category">Category:</label>
        <select id="catalog-category" value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
          <option value="">All Categories</option>
          {categories.map((category) => (
            <option key={category.id} value={category.id}>
              {category.name}
            </option>
          ))}
        </select>
        <button type="submit">Filter</button>
      </form>

      <hr />
      {error && (
        <p role="alert" className="catalog-error">
          {error}
        </p>
      )}
      {renderProducts()}
    </div>
  );
}