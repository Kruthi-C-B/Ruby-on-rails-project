import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { fetchGet } from "../../lib/api";
import { Alert, Button, EmptyState, Input, PageContainer, PageHeader, Select, Spinner } from "../ui";
import ProductGrid from "../product/ProductGrid";

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

  return (
    <PageContainer>
      <PageHeader
        title="Product Catalog"
        action={
          isAdmin ? (
            <Button as={Link} to="/admin/dashboard">Admin Dashboard</Button>
          ) : (
            <Button as={Link} to="/cart">View Cart</Button>
          )
        }
      />

      {storeName && <p className="catalog-note">You run {storeName}. Manage it from My Store Dashboard.</p>}

      <form className="catalog-filters" onSubmit={applyFilters}>
        <Input
          id="catalog-query"
          label="Search Product"
          value={query}
          placeholder="e.g. Headphones"
          onChange={(e) => setQuery(e.target.value)}
        />
        <Select id="catalog-category" label="Category" value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
          <option value="">All Categories</option>
          {categories.map((category) => (
            <option key={category.id} value={category.id}>
              {category.name}
            </option>
          ))}
        </Select>
        <Button type="submit">Filter</Button>
      </form>

      <hr />
      {error && <Alert>{error}</Alert>}
      {loading ? (
        <Spinner label="Loading products…" />
      ) : products.length === 0 ? (
        <EmptyState title="No products found">Try changing your search or category filters.</EmptyState>
      ) : (
        <ProductGrid products={products} />
      )}
    </PageContainer>
  );
}